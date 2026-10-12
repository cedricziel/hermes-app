import XCTest

@testable import HermesWatchCore

private final class SuspendedSendClient: HermesClient {
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
    client.replies[0].resume(returning: SendResult(threadId: "current", text: "", failed: false, waiting: .approval, handoff: target))
    await fulfillment(of: [poll], timeout: 1)
    model.stopWaiting()

    let newer = expectation(description: "New request")
    client.onRequest = { newer.fulfill() }
    let newSend = Task { await model.send("New request") }
    await fulfillment(of: [newer], timeout: 1)
    client.onRequest = nil
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
