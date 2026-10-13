import XCTest

@testable import HermesWatchCore

private final class SuspendedSendClient: HermesClient {
  let fixtureSession = recoveryFixtureSession()
  var sessionState: WatchSessionState? { fixtureSession }
  let recoveryStore: PendingSendStore = MemoryPendingSendStore()
  func prepareRecovery() async throws {}
  func forgetSend(sendId: String) async throws {}
  var replies: [CheckedContinuation<SendResult, Error>] = []
  var onRequest: (() -> Void)?

  func threads() async throws -> [ThreadSummary] { [] }
  func messages(threadId: String) async throws -> [ChatMessage] { [] }
  func transcribe(audio: Data, mimeType: String) async throws -> String { "" }
  func send(threadId: String?, text: String, sendId: String, retry: Bool) async throws -> SendResult {
    try await withCheckedThrowingContinuation { continuation in
      replies.append(continuation)
      onRequest?()
    }
  }
}

@MainActor
final class SendAttemptIsolationTests: XCTestCase {
  func testStoppedCompletionCannotReplaceNewSendState() async {
    await assertStoppedReplyIgnored(.success(SendResult(threadId: "stale", text: "Old answer", failed: false, handoff: staleHandoff)))
  }

  func testStoppedFailedCompletionCannotReplaceNewSendState() async {
    await assertStoppedReplyIgnored(.success(SendResult(threadId: "stale", text: "Old failure", failed: true, handoff: staleHandoff)))
  }

  func testStoppedWaitingReplyCannotPollOrReplaceNewSendState() async {
    await assertStoppedReplyIgnored(.success(SendResult(threadId: "stale", text: "", failed: false, waiting: .question, handoff: staleHandoff)))
  }

  func testStoppedTransportErrorCannotRestoreRetryContent() async {
    await assertStoppedReplyIgnored(.failure(HermesClientError.phoneUnreachable))
  }

  func testDetachedApprovalStillBlocksComposition() async {
    await assertDetachedRequestBlocksComposition(.approval)
  }

  func testDetachedQuestionStillBlocksComposition() async {
    await assertDetachedRequestBlocksComposition(.question)
  }

  private func assertDetachedRequestBlocksComposition(_ waiting: SendResult.Waiting) async {
    let client = SuspendedSendClient()
    let model = ConversationModel(client: client, threadId: nil)
    let initial = expectation(description: "Initial request")
    client.onRequest = { initial.fulfill() }
    let work = Task { await model.send("Original request") }
    defer { work.cancel() }
    await fulfillment(of: [initial], timeout: 1)
    guard let first = client.replies.first else { XCTFail("Missing initial request"); return }
    let poll = expectation(description: "Waiting poll")
    client.onRequest = { poll.fulfill() }
    first.resume(returning: SendResult(threadId: "current", text: "", failed: false, waiting: waiting))
    await fulfillment(of: [poll], timeout: 1)
    guard client.replies.count == 2 else { XCTFail("Missing waiting poll"); return }
    client.onRequest = nil
    model.stopWaiting()

    XCTAssertFalse(model.canCompose)
    await model.send("Blocked request")
    XCTAssertEqual(client.replies.count, 2)
    XCTAssertEqual(model.messages.map(\.content), ["Original request"])
    client.replies[1].resume(returning: SendResult(threadId: "current", text: "Late answer", failed: false))
    await work.value
  }

  private var staleHandoff: HandoffTarget {
    HandoffTarget(serverUrl: "https://stale.example", profile: "stale", sessionId: "stale")
  }

  private func assertStoppedReplyIgnored(_ reply: Result<SendResult, Error>) async {
    let client = SuspendedSendClient()
    let model = ConversationModel(client: client, threadId: nil)
    let initial = expectation(description: "Initial request")
    client.onRequest = { initial.fulfill() }
    let oldSend = Task { await model.send("Old request") }
    await fulfillment(of: [initial], timeout: 1)

    let poll = expectation(description: "Waiting poll")
    client.onRequest = { poll.fulfill() }
    let target = HandoffTarget(serverUrl: "https://current.example", profile: "current", sessionId: "current")
    client.replies[0].resume(returning: SendResult(threadId: "current", text: "", failed: false, waiting: .working, handoff: target))
    await fulfillment(of: [poll], timeout: 1)
    model.leaveConversation()
    XCTAssertTrue(model.canCompose)

    let newer = expectation(description: "New request")
    client.onRequest = { newer.fulfill() }
    let newSend = Task { await model.send("New request") }
    await fulfillment(of: [newer], timeout: 1)
    client.onRequest = nil
    guard client.replies.count == 3 else {
      XCTFail("Expected a new send after leaving a working turn")
      oldSend.cancel()
      newSend.cancel()
      client.replies.last?.resume(with: reply)
      return
    }
    client.replies[1].resume(with: reply)
    await oldSend.value

    XCTAssertEqual(model.messages.map(\.content), ["Old request", "New request"])
    XCTAssertEqual(model.threadId, "current")
    XCTAssertEqual(model.handoff, target)
    XCTAssertEqual(model.phase, .sending)
    XCTAssertNil(model.unsent)
    XCTAssertNil(model.unsentVoice)
    XCTAssertEqual(client.replies.count, 3)

    client.replies[2].resume(returning: SendResult(threadId: "current", text: "New answer", failed: false))
    await newSend.value
    XCTAssertEqual(model.messages.map(\.content), ["Old request", "New request", "New answer"])
    XCTAssertEqual(model.phase, .idle)
  }
}
