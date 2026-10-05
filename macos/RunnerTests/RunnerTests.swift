import Cocoa
import FlutterMacOS
import XCTest
@testable import Hermes

class RunnerTests: XCTestCase {
  func testHandoffReceivesBeforeFlutterAndKeepsLatestActivity() {
    let handoff = ChatHandoff()
    let first = NSUserActivity(activityType: ChatHandoff.activityType)
    first.userInfo = ["threadId": "first"]
    let second = NSUserActivity(activityType: ChatHandoff.activityType)
    second.userInfo = ["threadId": "second"]
    XCTAssertTrue(handoff.receive(first))
    XCTAssertTrue(handoff.receive(second))
    XCTAssertEqual(handoff.take()?["threadId"] as? String, "second")
    XCTAssertNil(handoff.take())
  }

  func testHandoffDoesNotClaimUnrelatedActivities() {
    let handoff = ChatHandoff()
    XCTAssertFalse(handoff.receive(NSUserActivity(activityType: "unrelated")))
    XCTAssertNil(handoff.take())
  }

  func testHandoffFailureSurvivesStartup() {
    let handoff = ChatHandoff()
    handoff.failed(ChatHandoff.activityType)
    XCTAssertEqual(handoff.take()?["error"] as? Bool, true)
  }


  func testClipboardFilePathsExcludeWebURLsWithExistingFilePaths() throws {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try Data("test".utf8).write(to: file)
    defer { try? FileManager.default.removeItem(at: file) }

    let pasteboard = NSPasteboard.withUniqueName()
    defer { pasteboard.releaseGlobally() }
    XCTAssertTrue(pasteboard.writeObjects([
      URL(string: "https://example.com\(file.path)")! as NSURL,
      file as NSURL,
    ]))

    XCTAssertEqual(MainFlutterWindow.clipboardFilePaths(from: pasteboard), [file.path])
  }

}
