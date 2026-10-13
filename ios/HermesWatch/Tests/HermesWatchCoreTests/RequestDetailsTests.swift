import XCTest
@testable import HermesWatchCore

final class RequestDetailsTests: XCTestCase {
  func testApprovalRequiresFullCommandAndOfferedScopeConfirmation() throws {
    let details = try WatchRequestDetails(row: ["kind": "approval", "requestId": "r", "command": "echo demo", "choices": ["once", "deny"]])
    var draft = WatchRequestDraft(details: details)
    XCTAssertNil(draft.activateApproval("once"))
    XCTAssertEqual(draft.confirmationChoice, "once")
    XCTAssertEqual(draft.confirmApproval(), .approval(choice: "once", command: "echo demo"))
    XCTAssertNil(draft.confirmApproval())
  }

  func testDenyIsImmediateAndDuplicateActivationDoesNotSend() throws {
    var draft = WatchRequestDraft(details: try WatchRequestDetails(row: ["kind": "approval", "requestId": "r", "command": "echo demo", "choices": ["deny"]]))
    XCTAssertEqual(draft.activateApproval("deny"), .approval(choice: "deny", command: "echo demo"))
    XCTAssertNil(draft.activateApproval("deny"))
  }

  func testUnsupportedAndIncompletePayloadsFailClosed() {
    XCTAssertThrowsError(try WatchRequestDetails(row: ["kind": "secret", "requestId": "r"]))
    XCTAssertThrowsError(try WatchRequestDetails(row: ["kind": "approval", "requestId": "r", "command": "echo demo", "choices": ["invented"]]))
    XCTAssertThrowsError(try WatchRequestDetails(row: ["kind": "approval", "requestId": "r", "command": String(repeating: "é", count: 40000), "choices": ["once"]]))
  }

  func testQuestionSelectionTextAndProgress() throws {
    let details = try WatchRequestDetails(row: ["kind": "question", "requestId": "r", "batch": true, "accepted": ["q1"], "questions": [["qid": "q1", "prompt": "First?", "choices": ["a"], "multiSelect": false], ["qid": "q2", "prompt": "Second?", "choices": ["red", "blue"], "multiSelect": true], ["qid": "q3", "prompt": "Explain?", "choices": [], "multiSelect": false]]])
    var draft = WatchRequestDraft(details: details)
    XCTAssertEqual(draft.questionIndex, 1)
    draft.toggle("red")
    draft.toggle("blue")
    XCTAssertEqual(draft.submitQuestion(), .question(qid: "q2", values: ["red", "blue"]))
    XCTAssertNil(draft.submitQuestion())
    draft.accepted()
    XCTAssertEqual(draft.questionIndex, 2)
    draft.text = "  "
    XCTAssertNil(draft.submitQuestion())
    draft.text = "Keep backups"
    XCTAssertEqual(draft.submitQuestion(), .question(qid: "q3", values: ["Keep backups"]))
    draft.clear()
    XCTAssertNil(draft.details)
    XCTAssertEqual(draft.text, "")
    XCTAssertTrue(draft.selection.isEmpty)
  }

  func testUnknownAcknowledgementOnlyAllowsStatusChecking() throws {
    var draft = WatchRequestDraft(details: try WatchRequestDetails(row: ["kind": "approval", "requestId": "r", "command": "echo demo", "choices": ["deny"]]))
    _ = draft.activateApproval("deny")
    draft.uncertain()
    XCTAssertTrue(draft.needsStatusCheck)
    XCTAssertNil(draft.activateApproval("deny"))
  }
}
