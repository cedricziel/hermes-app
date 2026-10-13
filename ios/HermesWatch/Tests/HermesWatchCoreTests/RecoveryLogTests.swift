import XCTest
@testable import HermesWatchCore

final class RecoveryLogTests: XCTestCase {
  func testRecoveryDiagnosticsContainOnlyFixedActionAndOutcomeValues() {
    var entries: [[String: String]] = []
    let log = RecoveryActionLog { entries.append($0) }
    log.record(.checkResult, .uncertain)
    log.record(.resendConfirmed, .completed)
    XCTAssertEqual(entries, [
      ["action": "check_result", "outcome": "uncertain"],
      ["action": "resend_confirmed", "outcome": "completed"],
    ])
  }
}
