import XCTest
@testable import HermesWatchCore

final class ActivationWaitTests: XCTestCase {
  func testInactiveSessionExhaustsBudgetAndReturnsNotActivated() async {
    var checks = 0
    var sleeps = 0
    do {
      try await waitForRelayActivation(
        activated: { checks += 1; return false },
        sleep: { sleeps += 1 }
      )
      XCTFail("Inactive session should fail")
    } catch {
      XCTAssertEqual(error as? RelayFailure, .notActivated)
      XCTAssertEqual(checks, 15)
      XCTAssertEqual(sleeps, 15)
    }
  }

  func testActivatedSessionReturnsWithoutWaiting() async throws {
    var sleeps = 0
    try await waitForRelayActivation(activated: { true }, sleep: { sleeps += 1 })
    XCTAssertEqual(sleeps, 0)
  }

  func testCancellationPropagatesWithoutContinuingActivationChecks() async {
    var checks = 0
    do {
      try await waitForRelayActivation(
        activated: { checks += 1; return false },
        sleep: { throw CancellationError() }
      )
      XCTFail("Cancelled wait should fail")
    } catch {
      XCTAssertTrue(error is CancellationError)
      XCTAssertEqual(checks, 1)
    }
  }
}
