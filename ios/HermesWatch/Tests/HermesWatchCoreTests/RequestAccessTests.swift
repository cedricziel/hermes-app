import XCTest
@testable import HermesWatchCore

@MainActor
final class RequestAccessTests: XCTestCase {
  func testLockPublicationClearsDetailsWithoutChangingRecoveryContext() {
    let session = WatchSessionState()
    session.acceptContext("demo", revision: 2)
    let access = WatchRequestAccess()
    access.acceptOwner("demo", revision: 2)
    access.receive(["watchRequests": ["contextId": "demo", "revision": 2, "epoch": 1, "allowed": true]])
    var cleared = false
    _ = access.register { cleared = true }
    access.receive(["watchRequests": ["contextId": "demo", "revision": 2, "epoch": 2, "allowed": false]])
    XCTAssertTrue(cleared)
    XCTAssertFalse(access.allowed)
    XCTAssertEqual(session.contextId, "demo")
    XCTAssertEqual(session.revision, 2)
    access.receive(["watchRequests": ["contextId": "demo", "revision": 2, "epoch": 1, "allowed": true]])
    XCTAssertFalse(access.allowed)
  }
}
