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


  func testAWindowClosedBeforeItShowsClosesWhenItDoes() {
    var pending = PendingCloses()
    pending.remember("w1")
    XCTAssertFalse(pending.take("w2"))
    XCTAssertTrue(pending.take("w1"))
    XCTAssertFalse(pending.take("w1"))
  }

  private func pasteboard(_ text: String?) -> NSPasteboard {
    let pasteboard = NSPasteboard.withUniqueName()
    pasteboard.clearContents()
    if let text { pasteboard.setString(text, forType: .string) }
    addTeardownBlock { pasteboard.releaseGlobally() }
    return pasteboard
  }

  func testAskHermesQueuesSelectedTextOnce() {
    let service = AskHermesService()
    var notified = 0
    service.notify = { notified += 1 }

    XCTAssertNil(service.enqueue(from: pasteboard("\n  \n    indented()\n  more\n \n\n")))

    XCTAssertEqual(notified, 1)
    let entries = service.takeQueued()
    XCTAssertEqual(entries.count, 1)
    XCTAssertEqual(entries[0]["type"] as? String, "text")
    XCTAssertEqual(entries[0]["intent"] as? String, "ask")
    // Only blank lines around the selection go; its indentation stays.
    XCTAssertEqual(entries[0]["text"] as? String, "    indented()\n  more")
    XCTAssertEqual(entries[0]["truncated"] as? Bool, false)
    XCTAssertTrue(service.takeQueued().isEmpty)
  }

  func testAskHermesShowsTheWindowOnlyForUsableText() {
    let service = AskHermesService()
    var shown = 0
    service.showWindow = { shown += 1 }

    _ = service.enqueue(from: pasteboard("   \n"))
    XCTAssertEqual(shown, 0)

    _ = service.enqueue(from: pasteboard("text"))
    XCTAssertEqual(shown, 1)
  }

  func testAskHermesDropsWhitespaceAndNonText() {
    let service = AskHermesService()

    XCTAssertNotNil(service.enqueue(from: pasteboard(" \n\t ")))
    XCTAssertNotNil(service.enqueue(from: pasteboard(nil)))

    let entries = service.takeQueued()
    XCTAssertEqual(entries.compactMap { $0["type"] as? String }, ["dropped", "dropped"])
    XCTAssertEqual(entries.compactMap { $0["reason"] as? String }, ["empty", "no_text"])
    XCTAssertNil(entries[0]["text"])
  }

  func testAskHermesCutsLongTextOnACharacterBoundary() {
    let service = AskHermesService()
    // "e" plus a combining accent is one character but two scalars.
    let text = String(repeating: "e\u{301}", count: AskHermesService.characterLimit + 5)

    XCTAssertNil(service.enqueue(from: pasteboard(text)))

    let entry = service.takeQueued()[0]
    let kept = entry["text"] as? String ?? ""
    XCTAssertEqual(kept.count, AskHermesService.characterLimit)
    XCTAssertEqual(entry["truncated"] as? Bool, true)
  }

  func testAskHermesKeepsEverythingFromTextAtTheLimit() {
    let service = AskHermesService()
    let text = String(repeating: "a", count: AskHermesService.characterLimit)

    XCTAssertNil(service.enqueue(from: pasteboard(text)))

    let entry = service.takeQueued()[0]
    XCTAssertEqual((entry["text"] as? String)?.count, AskHermesService.characterLimit)
    XCTAssertEqual(entry["truncated"] as? Bool, false)
  }
}
