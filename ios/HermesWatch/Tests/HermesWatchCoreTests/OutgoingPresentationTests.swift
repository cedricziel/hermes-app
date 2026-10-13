import XCTest
@testable import HermesWatchCore

@MainActor
private final class AwaitingForgetClient: HermesClient {
  let session = recoveryFixtureSession()
  var sessionState: WatchSessionState? { session }
  let recoveryStore: PendingSendStore = MemoryPendingSendStore()
  var forgetting: (() -> Void)?
  var forgetResult: CheckedContinuation<Void, Never>?
  func prepareRecovery() async throws {}
  func threads() async throws -> [ThreadSummary] { [] }
  func messages(threadId: String) async throws -> [ChatMessage] { [] }
  func transcribe(audio: Data, mimeType: String) async throws -> String { "" }
  func send(threadId: String?, text: String, sendId: String, retry: Bool) async throws -> SendResult {
    SendResult(threadId: threadId, text: "", failed: false, recoveryState: .notSent)
  }
  func forgetSend(sendId: String) async throws {
    await withCheckedContinuation { forgetResult = $0; forgetting?() }
  }
}

@MainActor
final class OutgoingPresentationTests: XCTestCase {
  func testExplicitPendingRetainsAcceptanceWhenPersistenceFails() async throws {
    let client = FakeClient()
    let store = try XCTUnwrap(client.recoveryStore as? MemoryPendingSendStore)
    try store.save(PendingSendRecord(sendId: "restored-intent", contextId: "test-context", revision: 1,
      profile: nil, threadId: nil, text: "Original", localMessageId: "intent", createdAt: .distantPast, recoveryState: .pending))
    let model = ConversationModel(client: client, threadId: nil)
    await model.load()
    client.sendResult = .success(SendResult(threadId: nil, text: "", failed: false, recoveryState: .pending))
    client.onSend = { store.writeFailure = true }
    await model.checkResult()
    XCTAssertEqual(model.recovery?.recoveryState, .pending)
    XCTAssertEqual(model.deliveryLabel(messageId: "intent"), "Accepted, awaiting reply")
    XCTAssertFalse(model.canSendAgain)
    await model.requestSendAgain()
    await model.confirmSendAgain()
    XCTAssertFalse(model.resendConfirmation)
    XCTAssertEqual(client.sends.count, 1)
  }
  func testSignOutDuringUnsentEditDoesNotReturnPrivateText() async {
    let client = AwaitingForgetClient()
    let model = ConversationModel(client: client, threadId: nil)
    await model.send("Private draft")
    let waiting = expectation(description: "Forget suspended")
    client.forgetting = { waiting.fulfill() }
    let edit = Task { await model.editUnsent() }
    await fulfillment(of: [waiting], timeout: 1)
    client.session.invalidate()
    client.forgetResult?.resume()
    let draft = await edit.value
    XCTAssertNil(draft)
    XCTAssertTrue(model.messages.isEmpty)
    XCTAssertNil(model.recovery)
  }

  func testLeavingConversationDuringUnsentEditDoesNotReturnCapturedText() async {
    let client = AwaitingForgetClient()
    let model = ConversationModel(client: client, threadId: nil)
    await model.send("Private draft")
    let waiting = expectation(description: "Forget suspended")
    client.forgetting = { waiting.fulfill() }
    let edit = Task { await model.editUnsent() }
    await fulfillment(of: [waiting], timeout: 1)
    model.leaveConversation()
    client.forgetResult?.resume()
    let draft = await edit.value
    XCTAssertNil(draft)
  }
  func testWorkingResponseKeepsAcceptanceEvidenceDuringNextPoll() async {
    let client = FakeClient()
    client.sendResults = [.success(SendResult(threadId: nil, text: "", failed: false, waiting: .working)),
      .failure(HermesClientError.phoneUnreachable)]
    let model = ConversationModel(client: client, threadId: nil)
    var statusAtPoll: String?
    client.onSend = {
      if client.sends.count == 2, let id = model.messages.last?.id {
        statusAtPoll = model.deliveryLabel(messageId: id)
      }
    }
    await model.send("Accepted work")
    XCTAssertEqual(statusAtPoll, "Accepted, awaiting reply")
  }

  func testRestoredPendingIntentHasNoAcceptanceEvidence() async throws {
    let client = FakeClient()
    try client.recoveryStore.save(PendingSendRecord(sendId: "crashed-before-send", contextId: "test-context", revision: 1,
      profile: nil, threadId: nil, text: "Local intent", localMessageId: "intent", createdAt: .distantPast, recoveryState: .pending))
    let model = ConversationModel(client: client, threadId: nil)
    await model.load()
    XCTAssertEqual(model.deliveryLabel(messageId: "intent"), "Delivery unconfirmed")
    client.sendResult = .failure(HermesClientError.phoneUnreachable)
    await model.checkResult()
    XCTAssertEqual(model.recovery?.recoveryState, .uncertain)
    XCTAssertEqual(model.deliveryLabel(messageId: "intent"), "Delivery unconfirmed")
  }
  func testLoadingHistoryDoesNotCreateCurrentTurnCompletion() async {
    let client = FakeClient()
    client.messagesResult = .success([ChatMessage(id: "history", role: .assistant, content: "Old reply", at: .distantPast)])
    let model = ConversationModel(client: client, threadId: "thread")
    await model.load()
    XCTAssertNil(model.completedReplyId)
    await model.send("New request")
    let completion = model.completedReplyId
    XCTAssertEqual(completion, model.messages.last?.id)
    await model.load()
    XCTAssertEqual(model.completedReplyId, completion)
  }
  func testLeavingRequestWaitRetainsAcceptedTextAndCannotComposeAnotherAnswer() async {
    let client = FakeClient()
    client.sendResult = .success(SendResult(threadId: nil, text: "", failed: false, waiting: .question))
    let model = ConversationModel(client: client, threadId: nil)
    client.onSend = { if client.sends.count == 2 { model.stopWaiting() } }
    await model.send("Ask me")
    XCTAssertEqual(model.messages.map(\.content), ["Ask me"])
    XCTAssertTrue(model.pendingRequestWaiting)
    XCTAssertFalse(model.canCompose)
    XCTAssertFalse(model.canEditUnsent)
    await model.send("Yes")
    XCTAssertEqual(client.sends.count, 2)
  }

  func testFailureBeforeDispatchIsEditableButLostDeliveryIsUncertain() async {
    let client = FakeClient()
    client.sendResult = .failure(HermesClientError.notDelivered)
    let model = ConversationModel(client: client, threadId: nil)
    await model.send("Not delivered")
    XCTAssertEqual(model.recovery?.recoveryState, .notSent)
    XCTAssertTrue(model.canEditUnsent)
  }

  func testAcceptedWaitingFailureNeverBecomesEditable() async {
    let client = FakeClient()
    client.sendResults = [.success(SendResult(threadId: nil, text: "", failed: false, waiting: .approval)),
      .failure(HermesClientError.notDelivered)]
    let model = ConversationModel(client: client, threadId: nil)
    await model.send("Accepted")
    XCTAssertEqual(model.recovery?.recoveryState, .pending)
    XCTAssertFalse(model.canEditUnsent)
  }

  func testDefinitelyUnsentEditReturnsDraftWithoutSendingAndDiscardRemovesOnlyLocalText() async {
    let client = FakeClient()
    client.sendResult = .success(SendResult(threadId: nil, text: "", failed: false, recoveryState: .notSent))
    let model = ConversationModel(client: client, threadId: nil)
    await model.send("My draft")
    XCTAssertTrue(model.canEditUnsent)
    let draft = await model.editUnsent()
    XCTAssertEqual(draft, "My draft")
    XCTAssertEqual(client.sends.count, 1)
    XCTAssertTrue(model.messages.isEmpty)
    XCTAssertNil(model.recovery)
  }

  func testUncertainEditCannotReplaceOriginalAndConfirmedResendKeepsOriginalIdentity() async throws {
    let client = FakeClient()
    client.sendResult = .success(SendResult(threadId: nil, text: "", failed: false, recoveryState: .uncertain))
    let model = ConversationModel(client: client, threadId: nil)
    await model.send("Original")
    let original = try XCTUnwrap(model.recovery)
    XCTAssertFalse(model.canEditUnsent)
    let edited = await model.editUnsent()
    XCTAssertNil(edited)
    await model.checkResult()
    await model.requestSendAgain()
    await model.confirmSendAgain()
    XCTAssertNotEqual(model.recovery?.sendId, original.sendId)
    XCTAssertEqual(model.messages.filter { $0.content == "Original" }.count, 2)
    XCTAssertEqual(model.deliveryStates[original.localMessageId], .uncertain)
    let stored = try client.recoveryStore.records(contextId: original.contextId, revision: original.revision)
    XCTAssertTrue(stored.contains { $0.sendId == original.sendId && $0.recoveryState == .uncertain })
  }

  func testFailedAcceptedTurnRetainsOutgoingAndFailureReplyWithoutEdit() async {
    let client = FakeClient()
    client.sendResult = .success(SendResult(threadId: nil, text: "Model unavailable", failed: true))
    let model = ConversationModel(client: client, threadId: nil)
    await model.send("Original")
    XCTAssertEqual(model.messages.map(\.content), ["Original", "Model unavailable"])
    XCTAssertNil(model.unsent)
    XCTAssertFalse(model.canEditUnsent)
    XCTAssertNil(model.recovery)
    XCTAssertFalse(model.successfulReply)
  }

  func testDiscardDefinitelyUnsentDoesNotSubmit() async {
    let client = FakeClient()
    client.sendResult = .success(SendResult(threadId: nil, text: "", failed: false, recoveryState: .notSent))
    let model = ConversationModel(client: client, threadId: nil)
    await model.send("Original")
    await model.discardUnsent()
    XCTAssertTrue(model.messages.isEmpty)
    XCTAssertEqual(client.sends.count, 1)
    XCTAssertNil(model.recovery)
  }
}
