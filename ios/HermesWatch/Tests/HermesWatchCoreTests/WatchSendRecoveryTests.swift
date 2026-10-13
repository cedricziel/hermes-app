import XCTest
@testable import HermesWatchCore

@MainActor
private final class RecoveryClient: HermesClient {
  let session = recoveryFixtureSession()
  var sessionState: WatchSessionState? { session }
  let store = MemoryPendingSendStore()
  var recoveryStore: PendingSendStore { store }
  var supported = true
  var answer: Result<SendResult, Error> = .failure(HermesClientError.phoneUnreachable)
  var history: [ChatMessage] = []
  var requests: [(id: String, retry: Bool, createdAt: Date, text: String)] = []
  var forgotten: [String] = []
  var persistedBeforeRequest = false
  var suspended: CheckedContinuation<SendResult, Error>?
  var suspend = false
  var requested: (() -> Void)?
  func prepareRecovery() async throws { if !supported { throw HermesClientError.updateRequired } }
  func threads() async throws -> [ThreadSummary] { [] }
  func messages(threadId: String) async throws -> [ChatMessage] { history }
  func transcribe(audio: Data, mimeType: String) async throws -> String { "" }
  func forgetSend(sendId: String) async throws { forgotten.append(sendId) }
  func send(threadId: String?, text: String, sendId: String, retry: Bool) async throws -> SendResult { throw HermesClientError.updateRequired }
  func send(threadId: String?, text: String, sendId: String, retry: Bool, createdAt: Date) async throws -> SendResult {
    persistedBeforeRequest = store.values.contains { $0.sendId == sendId && $0.createdAt == createdAt && $0.text == text }
    requests.append((sendId, retry, createdAt, text))
    if suspend { return try await withCheckedThrowingContinuation { suspended = $0; requested?() } }
    return try answer.get()
  }
}

@MainActor
final class WatchSendRecoveryTests: XCTestCase {
  func testPendingIsPersistedBeforeTransportAndWriteFailurePreventsSubmission() async {
    let client = RecoveryClient()
    client.store.writeFailure = true
    let model = ConversationModel(client: client, threadId: nil)
    await model.send("Do it")
    XCTAssertTrue(client.requests.isEmpty)
    XCTAssertTrue(model.messages.isEmpty)
    XCTAssertEqual(model.phase, .failed(.recoveryStorage))
  }

  func testLostReplyRestoresOutgoingIdentityAndChecksOnlyOriginalTimestamp() async throws {
    let client = RecoveryClient()
    let first = ConversationModel(client: client, threadId: nil)
    await first.send("Do it")
    XCTAssertTrue(client.persistedBeforeRequest)
    let original = try XCTUnwrap(first.recovery)
    let restored = ConversationModel(client: client, threadId: nil)
    await restored.load()
    XCTAssertEqual(client.requests.count, 1)
    XCTAssertEqual(restored.messages.map(\.content), ["Do it"])
    client.answer = .success(SendResult(threadId: nil, text: "", failed: false, recoveryState: .pending))
    await restored.checkResult()
    XCTAssertEqual(client.requests.last?.id, original.sendId)
    XCTAssertEqual(client.requests.last?.createdAt, original.createdAt)
    XCTAssertEqual(client.requests.last?.retry, true)
    XCTAssertEqual(restored.messages.map(\.role), [.user])
  }

  func testUncertainResendRequiresCheckAndConfirmationAndCancelledResendDoesNothing() async throws {
    let client = RecoveryClient()
    let model = ConversationModel(client: client, threadId: nil)
    await model.send("Do it")
    let original = try XCTUnwrap(model.recovery)
    await model.requestSendAgain()
    XCTAssertFalse(model.resendConfirmation)
    client.answer = .success(SendResult(threadId: nil, text: "", failed: false, recoveryState: .uncertain))
    await model.checkResult()
    await model.send("Edited request")
    XCTAssertEqual(model.recovery?.text, "Do it")
    XCTAssertTrue(model.resendConfirmation)
    model.cancelSendAgain()
    await model.confirmSendAgain()
    XCTAssertEqual(client.requests.count, 2)
    await model.requestSendAgain()
    await model.confirmSendAgain()
    XCTAssertEqual(client.requests.count, 3)
    XCTAssertNotEqual(client.requests.last?.id, original.sendId)
    XCTAssertEqual(client.requests.last?.retry, false)
    XCTAssertEqual(model.messages.filter { $0.content == "Do it" && $0.role == .user }.count, 2)
  }

  func testNotSentManualRetryGetsFreshIdentity() async throws {
    let client = RecoveryClient()
    client.answer = .success(SendResult(threadId: nil, text: "", failed: false, recoveryState: .notSent))
    let model = ConversationModel(client: client, threadId: nil)
    await model.send("Do it")
    let first = try XCTUnwrap(model.recovery)
    await model.requestSendAgain()
    XCTAssertNotEqual(client.requests.last?.id, first.sendId)
    XCTAssertEqual(client.requests.last?.retry, false)
    XCTAssertFalse(model.resendConfirmation)
  }

  func testForgetRemovesLocalRecoveryAndRequestsPhoneRelease() async throws {
    let client = RecoveryClient()
    let model = ConversationModel(client: client, threadId: nil)
    await model.send("Do it")
    let id = try XCTUnwrap(model.recovery?.sendId)
    await model.forgetRecovery()
    XCTAssertNil(model.recovery)
    XCTAssertTrue(client.store.values.isEmpty)
    XCTAssertEqual(client.forgotten, [id])
  }

  func testHistoryIsNotProofOfCompletionAndSavedCompletionAppearsOnce() async {
    let client = RecoveryClient()
    client.answer = .success(SendResult(threadId: watchFixtureId("chat"), text: "", failed: false, recoveryState: .uncertain))
    let model = ConversationModel(client: client, threadId: nil)
    await model.send("Do it")
    client.history = [ChatMessage(id: "unrelated", role: .assistant, content: "Other answer", at: .distantPast)]
    await model.openRecoveryChat()
    XCTAssertNotNil(model.recovery)
    client.answer = .success(SendResult(threadId: watchFixtureId("chat"), text: "Original answer", failed: false))
    await model.checkResult()
    await model.checkResult()
    XCTAssertEqual(model.messages.filter { $0.content == "Original answer" }.count, 1)
    XCTAssertNil(model.recovery)
    XCTAssertTrue(client.store.values.isEmpty)
  }

  func testUnsupportedPhoneRetainsRecordAndDisablesResend() async {
    let client = RecoveryClient()
    let model = ConversationModel(client: client, threadId: nil)
    await model.send("Do it")
    client.supported = false
    await model.load()
    XCTAssertNotNil(model.recovery)
    XCTAssertFalse(model.canSendAgain)
    XCTAssertEqual(model.phase, .failed(.updateRequired))
    XCTAssertEqual(client.requests.count, 1)
  }

  func testRevisionDeparturePurgesRecordAndRejectsLateCompletion() async {
    let client = RecoveryClient()
    client.suspend = true
    let model = ConversationModel(client: client, threadId: nil)
    let sent = expectation(description: "Submitted original")
    client.requested = { sent.fulfill() }
    let work = Task { await model.send("Do it") }
    await fulfillment(of: [sent], timeout: 1)
    client.session.acceptContext("test-context", revision: 2)
    client.suspended?.resume(returning: SendResult(threadId: watchFixtureId("chat"), text: "Late answer", failed: false))
    await work.value
    XCTAssertTrue(client.store.values.isEmpty)
    XCTAssertTrue(model.messages.isEmpty)
    XCTAssertNil(model.recovery)
    XCTAssertEqual(model.phase, .failed(.contextChanged))
  }
}
