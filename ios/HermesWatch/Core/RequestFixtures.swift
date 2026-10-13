import Foundation

#if DEBUG
  enum RequestFixtures {
    static func approval(long: Bool = false) -> WatchRequestDetails {
      try! WatchRequestDetails(row: ["kind": "approval", "requestId": "demo-approval", "command": long ? String(repeating: "echo 'preview command'; ", count: 200) : "echo 'preview command'", "description": "Preview approval", "choices": ["once", "session", "always", "deny"]])
    }
    static func questions() -> WatchRequestDetails {
      try! WatchRequestDetails(row: ["kind": "question", "requestId": "demo-question", "batch": true, "questions": [
        ["qid": "first", "prompt": "Which preview color?", "choices": ["Red", "Blue"], "multiSelect": false],
        ["qid": "second", "prompt": "Which preview tasks?", "choices": ["Backups", "Reports", "Alerts"], "multiSelect": true],
        ["qid": "third", "prompt": "Describe the preview schedule", "choices": [], "multiSelect": false],
      ]])
    }
  }
#endif
