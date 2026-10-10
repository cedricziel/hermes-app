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

  private func snapshot(_ state: String, _ titles: [String] = []) -> [String: Any] {
    [
      "state": state,
      "chats": titles.enumerated().map { ["id": "id\($0.offset)", "profile": "work", "title": $0.element] },
    ]
  }

  private func titles(of menu: NSMenu) -> [String] {
    menu.items.map { $0.isSeparatorItem ? "-" : $0.title }
  }

  func testDockMenuHoldsOnlyShowMainWindowUntilDartPushes() {
    XCTAssertEqual(titles(of: DockMenu().menu()), ["Show Main Window"])
  }

  func testDockMenuListsNewChatAndChatsWhenReady() {
    let dock = DockMenu()
    dock.update(snapshot("ready", ["One", "Two"]))

    XCTAssertEqual(titles(of: dock.menu()), ["New Chat", "One", "Two", "-", "Show Main Window"])
  }

  func testDockMenuCapsTheChatsAtFive() {
    let dock = DockMenu()
    dock.update(snapshot("ready", (0..<8).map { "Chat \($0)" }))

    XCTAssertEqual(dock.menu().items.filter { $0.representedObject != nil }.count, 5)
  }

  func testDockMenuLockedOffersNewChatWithoutTitles() {
    let dock = DockMenu()
    dock.update(snapshot("ready", ["Secret"]))
    dock.update(snapshot("locked", ["Secret"]))

    XCTAssertEqual(titles(of: dock.menu()), ["New Chat", "-", "Show Main Window"])
    XCTAssertTrue(dock.chats.isEmpty)
  }

  func testDockMenuClearsOnOffAndOnAMalformedArgument() {
    let dock = DockMenu()
    dock.update(snapshot("ready", ["Secret"]))
    dock.update(snapshot("off"))
    XCTAssertEqual(titles(of: dock.menu()), ["Show Main Window"])

    dock.update(snapshot("ready", ["Secret"]))
    dock.update("nonsense")
    XCTAssertEqual(titles(of: dock.menu()), ["Show Main Window"])
    XCTAssertTrue(dock.chats.isEmpty)
  }

  func testDockMenuSkipsChatsThatDoNotParse() {
    let dock = DockMenu()
    dock.update(["state": "ready", "chats": [["id": "a", "title": "No profile"], ["id": "b", "profile": "p", "title": "Fine"]]])

    XCTAssertEqual(dock.chats.map { $0.title }, ["Fine"])
  }

  func testDockMenuTitlesAreNotFormatStringsOrShortcuts() {
    let dock = DockMenu()
    dock.update(snapshot("ready", ["100%@ done"]))

    let entry = dock.menu().items[1]
    XCTAssertEqual(entry.title, "100%@ done")
    XCTAssertEqual(entry.keyEquivalent, "")
  }

  func testDockMenuChoicesReachDart() {
    let dock = DockMenu()
    var shown = 0
    var sent: [(String, Any?)] = []
    dock.showWindow = { shown += 1 }
    dock.send = { sent.append(($0, $1)) }
    dock.update(snapshot("ready", ["One"]))
    let items = dock.menu().items

    _ = items[0].target?.perform(items[0].action, with: items[0])
    XCTAssertEqual(shown, 1)
    XCTAssertEqual(sent.map { $0.0 }, ["dockNewChat"])

    _ = items[1].target?.perform(items[1].action, with: items[1])
    XCTAssertEqual(shown, 1, "a chat is raised by Dart, which knows its window")
    XCTAssertEqual(sent.last?.0, "dockOpenChat")
    XCTAssertEqual((sent.last?.1 as? [String: String])?["id"], "id0")
    XCTAssertEqual((sent.last?.1 as? [String: String])?["profile"], "work")

    let last = items[items.count - 1]
    _ = last.target?.perform(last.action, with: last)
    XCTAssertEqual(shown, 2)
  }
}
