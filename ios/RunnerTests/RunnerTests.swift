import Flutter
import UIKit
import WatchConnectivity
import XCTest
@testable import Runner

final class RunnerTests: XCTestCase {
  func testComplicationContextDropsKeysTheNewPayloadOmits() {
    let session: [String: Any] = ["contextId": "c", "revision": 2, "usable": true]
    let old: [String: Any] = [
      "watchSession": session, "watchRequests": ["unavailable": true],
      "v": 1, "state": "working", "updatedAt": 10, "seq": 5,
      "title": "Backup", "threadId": "p/s1", "contextId": "c", "revision": 2,
    ]
    let new: [String: Any] = ["v": 1, "state": "working", "updatedAt": 11, "seq": 6, "contextId": "c", "revision": 2]
    let merged = WatchRelay.complicationContext(merging: new, into: old)
    XCTAssertNil(merged["title"])
    XCTAssertNil(merged["threadId"])
    XCTAssertEqual(merged["seq"] as? Int, 6)
    XCTAssertEqual(merged["updatedAt"] as? Int, 11)
    XCTAssertEqual((merged["watchSession"] as? [String: Any])?["contextId"] as? String, "c")
    XCTAssertNotNil(merged["watchRequests"])
  }

  func testComplicationContextTakesContextIdAndRevisionFromTheNewPayload() {
    let old: [String: Any] = ["contextId": "old", "revision": 2, "state": "working", "watchSession": ["usable": true]]
    let renewed = WatchRelay.complicationContext(
      merging: ["v": 1, "state": "ready", "contextId": "new", "revision": 3], into: old)
    XCTAssertEqual(renewed["contextId"] as? String, "new")
    XCTAssertEqual(renewed["revision"] as? Int, 3)
    // A sign-out clear carries no context: nothing is inherited.
    let cleared = WatchRelay.complicationContext(merging: ["v": 1, "state": "none", "seq": 9], into: old)
    XCTAssertNil(cleared["contextId"])
    XCTAssertNil(cleared["revision"])
    XCTAssertNotNil(cleared["watchSession"])
  }

  private func exercise(expiryFirst: Bool, result: Any?, expectedError: String?) async {
    let completed = expectation(description: "Dart invocation installed")
    var dartReply: ((Any?) -> Void)?
    var expire: (() -> Void)?
    var replies: [[String: Any]] = []
    var ended: [UIBackgroundTaskIdentifier] = []
    let task = UIBackgroundTaskIdentifier(rawValue: 42)
    let relay = WatchRelay(
      invokeRequest: { _, completion in dartReply = completion; completed.fulfill() },
      beginTask: { expiry in expire = expiry; return task },
      endTask: { ended.append($0) }
    )
    relay.session(WCSession.default, didReceiveMessage: ["op": "threads"]) {
      replies.append($0)
    }
    await fulfillment(of: [completed], timeout: 1)
    await MainActor.run {
      if expiryFirst { expire?() }
      dartReply?(result)
      if !expiryFirst { expire?() }
      XCTAssertEqual(replies.count, 1)
      XCTAssertEqual(replies.first?["error"] as? String, expectedError)
      XCTAssertEqual(ended, [task])
    }
  }

  func testReplyBeforeExpiryCompletesOnceAndEndsBackgroundTask() async {
    await exercise(expiryFirst: false, result: ["ok": true], expectedError: nil)
  }

  func testExpiryBeforeLateReplyCompletesOnceAndEndsBackgroundTask() async {
    await exercise(expiryFirst: true, result: ["ok": true], expectedError: "unavailable")
  }

  func testMissingDartHandlerReturnsUnavailable() async {
    await exercise(expiryFirst: false, result: FlutterMethodNotImplemented, expectedError: "unavailable")
  }

  func testMalformedDartReplyReturnsFailed() async {
    await exercise(expiryFirst: false, result: "invalid", expectedError: "failed")
  }
}
