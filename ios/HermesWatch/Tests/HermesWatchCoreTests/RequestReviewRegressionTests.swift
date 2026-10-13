import XCTest
@testable import HermesWatchCore

@MainActor
final class RequestReviewRegressionTests: XCTestCase {
  func testLeavingConversationClearsConfirmationAndKeepsAcceptedSendRecovery() async {
    let client = FakeClient()
    let model = ConversationModel(client: client, threadId: nil)
    model.requests.draft = WatchRequestDraft(details: RequestFixtures.approval())
    _ = model.requests.draft?.activateApproval("once")
    client.onSend = { model.leaveConversation() }
    await model.send("Preview command")
    XCTAssertNil(model.requests.draft)
    XCTAssertEqual(client.sends.count, 1)
    XCTAssertEqual(try? client.recoveryStore.records(contextId: "test-context", revision: 1).count, 1)
    XCTAssertFalse(model.messages.contains(where: { $0.role == .assistant }))
  }

  func testExpiredDetailsReturnGoneUnderCapturedAccessEpoch() async throws {
    let transport = FakeTransport()
    let client = RelayClient(transport: transport)
    transport.reply = .success(["ok": true, "threads": []])
    _ = try await client.threads()
    let access = WatchRequestAccess.shared
    let epoch = access.epoch + 1
    access.receive(["watchRequests": ["contextId": "test-context", "revision": 1, "epoch": epoch, "allowed": true]])
    transport.reply = .success(["ok": true, "status": "expired", "requestEpoch": epoch])
    let result = try await client.requestDetails(threadId: watchFixtureId("s1"), requestId: "gone")
    XCTAssertNil(result)
  }

  func testUnversionedDenialClearsAndRequiresHigherAllowedEpoch() {
    let access = WatchRequestAccess()
    access.acceptOwner("demo", revision: 1)
    access.receive(["watchRequests": ["contextId": "demo", "revision": 1, "epoch": 4, "allowed": true]])
    var cleared = false
    _ = access.register { cleared = true }
    access.receive(["watchRequests": ["unavailable": true]])
    XCTAssertTrue(cleared)
    XCTAssertFalse(access.allowed)
    XCTAssertEqual(access.epoch, 4)
    access.receive(["watchRequests": ["contextId": "demo", "revision": 1, "epoch": 4, "allowed": true]])
    XCTAssertFalse(access.allowed)
    access.receive(["watchRequests": ["contextId": "demo", "revision": 1, "epoch": 5, "allowed": true]])
    XCTAssertTrue(access.allowed)
  }

  func testDelayedPreviousOwnerGrantCannotUnlockReplacementOwner() {
    let access = WatchRequestAccess()
    access.acceptOwner("first", revision: 1)
    access.receive(["watchRequests": ["contextId": "first", "revision": 1, "epoch": 100, "allowed": true]])
    access.acceptOwner("replacement", revision: 2)
    access.receive(["watchRequests": ["contextId": "first", "revision": 1, "epoch": 101, "allowed": true]])
    XCTAssertFalse(access.allowed)
    XCTAssertEqual(access.epoch, 0)
    access.receive(["watchRequests": ["contextId": "replacement", "revision": 1, "epoch": 102, "allowed": true]])
    XCTAssertFalse(access.allowed)
    access.receive(["watchRequests": ["contextId": "replacement", "revision": 2, "epoch": 1, "allowed": true]])
    XCTAssertTrue(access.allowed)
  }

  func testLeavingDuringPreparationNeverSubmitsOrCreatesRecoveryRecord() async {
    let client = PreparingRequestClient()
    let model = ConversationModel(client: client, threadId: nil)
    let task = Task { await model.send("Preview command") }
    while client.resume == nil { await Task.yield() }
    model.leaveConversation()
    client.resume?.resume()
    await task.value
    XCTAssertEqual(client.sendCount, 0)
    XCTAssertTrue(try! client.recoveryStore.records(contextId: "test-context", revision: 1).isEmpty)
    XCTAssertNil(model.requests.draft)
    XCTAssertEqual(model.phase, .idle)
  }

  func testAcceptedOwnerChangesResetOnlyRequestAccessEpoch() {
    let access = WatchRequestAccess()
    access.acceptOwner("first", revision: 1)
    access.receive(["watchRequests": ["contextId": "first", "revision": 1, "epoch": 100, "allowed": true]])
    access.acceptOwner("replacement", revision: 2)
    XCTAssertFalse(access.allowed)
    access.receive(["watchRequests": ["contextId": "replacement", "revision": 2, "epoch": 1, "allowed": true]])
    XCTAssertTrue(access.allowed)
    XCTAssertEqual(access.epoch, 1)
    access.acceptOwner("replacement", revision: 2)
    XCTAssertTrue(access.allowed)
  }
}

@MainActor
private final class PreparingRequestClient: HermesClient {
  let sessionState: WatchSessionState? = recoveryFixtureSession()
  let recoveryStore: PendingSendStore = MemoryPendingSendStore()
  var resume: CheckedContinuation<Void, Never>?
  var sendCount = 0
  func prepareRecovery() async throws { await withCheckedContinuation { resume = $0 } }
  func threads() async throws -> [ThreadSummary] { [] }
  func messages(threadId: String) async throws -> [ChatMessage] { [] }
  func send(threadId: String?, text: String, sendId: String, retry: Bool) async throws -> SendResult {
    sendCount += 1
    return SendResult(threadId: threadId, text: "Preview", failed: false)
  }
  func transcribe(audio: Data, mimeType: String) async throws -> String { "" }
}
