import XCTest
@testable import HermesWatchCore

@MainActor
final class RequestActionsModelTests: XCTestCase {
  func testLateDetailsCannotRestoreAfterLock() async {
    let session = WatchSessionState()
    session.acceptContext("demo", revision: 1)
    let access = WatchRequestAccess()
    access.acceptOwner("demo", revision: 1)
    access.receive(["watchRequests": ["contextId": "demo", "revision": 1, "epoch": 1, "allowed": true]])
    let client = DelayedRequestClient()
    let model = RequestActionsModel(client: client, session: session, access: access)
    let thread = WatchThreadId(contextId: "demo", profile: nil, sessionId: "thread").encode()
    let task = Task { await model.load(threadId: thread, requestId: "r") }
    while client.resume == nil { await Task.yield() }
    access.receive(["watchRequests": ["contextId": "demo", "revision": 1, "epoch": 2, "allowed": false]])
    client.resume?.resume(returning: try! WatchRequestDetails(row: ["kind": "approval", "requestId": "r", "fingerprint": "fixture", "command": "echo demo", "choices": ["once"]]))
    await task.value
    XCTAssertNil(model.draft)
    XCTAssertFalse(model.loading)
    XCTAssertTrue(session.usable)
  }

  func testUnknownAnswerChecksStatusWithoutSendingAgain() async throws {
    let session = WatchSessionState()
    session.acceptContext("demo", revision: 1)
    let access = WatchRequestAccess()
    access.acceptOwner("demo", revision: 1)
    access.receive(["watchRequests": ["contextId": "demo", "revision": 1, "epoch": 1, "allowed": true]])
    let client = UncertainRequestClient()
    let model = RequestActionsModel(client: client, session: session, access: access)
    let thread = WatchThreadId(contextId: "demo", profile: nil, sessionId: "thread").encode()
    await model.load(threadId: thread, requestId: "r")
    let answer = model.draft!.activateApproval("deny")!
    await model.submit(answer)
    await model.checkStatus()
    XCTAssertTrue(model.draft!.needsStatusCheck)
    XCTAssertNil(model.draft!.activateApproval("deny"))
    await model.submit(answer)
    XCTAssertEqual(client.answerCount, 1)
  }

  func testLostBatchAcknowledgementRequiresExactAcceptedFingerprintBeforeContinuing() async throws {
    let session = WatchSessionState()
    session.acceptContext("demo", revision: 1)
    let access = WatchRequestAccess()
    access.acceptOwner("demo", revision: 1)
    access.receive(["watchRequests": ["contextId": "demo", "revision": 1, "epoch": 1, "allowed": true]])
    let client = BatchRequestClient()
    let model = RequestActionsModel(client: client, session: session, access: access)
    let thread = WatchThreadId(contextId: "demo", profile: nil, sessionId: "thread").encode()
    await model.load(threadId: thread, requestId: "r")
    model.draft!.toggle("First")
    let original = model.draft!.submitQuestion()!
    await model.submit(original)
    client.acceptedFingerprint = "different-answer"
    await model.checkStatus()
    XCTAssertTrue(model.draft!.needsStatusCheck)
    await model.submit(original)
    XCTAssertEqual(client.answerCount, 1)
    client.acceptedFingerprint = "original-fingerprint"
    await model.checkStatus()
    XCTAssertFalse(model.draft!.needsStatusCheck)
    XCTAssertEqual(model.draft!.question?.qid, "q2")
    XCTAssertEqual(client.answerCount, 1)
    model.draft!.toggle("Second")
    let next = model.draft!.submitQuestion()!
    await model.submit(next)
    XCTAssertEqual(client.answerCount, 2)
    XCTAssertEqual(client.answeredQuestions, ["q1", "q2"])
  }

}

@MainActor
private final class DelayedRequestClient: WatchRequestServing {
  var resume: CheckedContinuation<WatchRequestDetails?, Error>?
  func requestDetails(threadId: String, requestId: String) async throws -> WatchRequestDetails? {
    try await withCheckedThrowingContinuation { resume = $0 }
  }
}

@MainActor
private final class UncertainRequestClient: WatchRequestServing {
  var answerCount = 0
  func requestDetails(threadId: String, requestId: String) async throws -> WatchRequestDetails? {
    try WatchRequestDetails(row: ["kind": "approval", "requestId": requestId, "fingerprint": "fixture", "command": "echo demo", "choices": ["deny"]])
  }
  func answerRequest(threadId: String, requestId: String, fingerprint: String, answer: WatchRequestAnswer) async throws -> String {
    answerCount += 1
    return "uncertain"
  }
}

@MainActor
private final class BatchRequestClient: WatchRequestServing {
  var answerCount = 0
  var answeredQuestions: [String] = []
  var acceptedFingerprint: String?
  func requestDetails(threadId: String, requestId: String) async throws -> WatchRequestDetails? {
    try WatchRequestDetails(row: [
      "kind": "question", "requestId": requestId, "batch": true,
      "fingerprint": acceptedFingerprint == nil ? "original-fingerprint" : "updated-fingerprint",
      "accepted": acceptedFingerprint == nil ? [] : ["q1"],
      "acceptedFingerprints": acceptedFingerprint.map { ["q1": $0] } ?? [:],
      "questions": [
        ["qid": "q1", "prompt": "First?", "choices": ["First"], "multiSelect": false],
        ["qid": "q2", "prompt": "Second?", "choices": ["Second"], "multiSelect": false],
      ],
    ])
  }
  func answerRequest(threadId: String, requestId: String, fingerprint: String, answer: WatchRequestAnswer) async throws -> String {
    answerCount += 1
    if case .question(let qid, _) = answer { answeredQuestions.append(qid) }
    return "uncertain"
  }
}
