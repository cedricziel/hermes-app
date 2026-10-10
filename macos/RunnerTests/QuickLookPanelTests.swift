import Cocoa
import Quartz
import XCTest

@testable import Hermes

class QuickLookPanelTests: XCTestCase {
  private var folder: URL!

  override func setUpWithError() throws {
    folder = FileManager.default.temporaryDirectory
      .appendingPathComponent("quick-look-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
    QuickLookPanel.shared.close()
    if QLPreviewPanel.sharedPreviewPanelExists() { QLPreviewPanel.shared().orderOut(nil) }
    try? FileManager.default.removeItem(at: folder)
  }

  func testAFileThatIsGoneCannotBePreviewed() {
    let missing = folder.appendingPathComponent("gone.pdf").path
    XCTAssertFalse(QuickLookPanel.shared.preview(path: missing))
    XCTAssertEqual(QuickLookPanel.shared.toggle(path: missing) as? Bool, false)
    XCTAssertNil(QuickLookPanel.shared.item, "no item")
  }

  func testNoPathCannotBePreviewed() {
    XCTAssertFalse(QuickLookPanel.shared.preview(path: nil))
    XCTAssertFalse(QuickLookPanel.shared.preview(path: ""))
  }

  func testAFolderIsNotAFile() {
    XCTAssertNil(QuickLookPanel.readableFile(at: folder.path))
  }

  func testAReadableFileIsFound() throws {
    let file = folder.appendingPathComponent("notes.txt")
    try Data([1]).write(to: file)
    XCTAssertEqual(QuickLookPanel.readableFile(at: file.path), file)
  }

  func testLiveShowsTogglesAndCloses() throws {
    let file = folder.appendingPathComponent("live.txt")
    try Data("hello".utf8).write(to: file)
    // A key window whose view controller has the responder, as each engine's has.
    let controller = NSViewController()
    controller.view = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 100))
    QuickLookResponder.install(after: controller)
    let window = NSWindow(contentViewController: controller)
    window.isReleasedWhenClosed = false
    NSApp.activate(ignoringOtherApps: true)
    window.makeKeyAndOrderFront(nil)
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.3))
    defer { window.close() }
    try XCTSkipUnless(window.isKeyWindow, "Needs a key window; none in a background test session.")
    XCTAssertTrue(QuickLookPanel.shared.preview(path: file.path), "preview")
    let panel = try XCTUnwrap(QLPreviewPanel.shared())
    XCTAssertTrue(panel.isVisible, "visible")
    XCTAssertEqual(QuickLookPanel.shared.item, file)
    XCTAssertEqual(QuickLookPanel.shared.toggle(path: file.path) as? String, "closed")
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 1))
    XCTAssertFalse(panel.isVisible)
    XCTAssertEqual(QuickLookPanel.shared.toggle(path: file.path) as? String, "shown")
    XCTAssertTrue(panel.isVisible, "visible")
    QuickLookPanel.shared.close()
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 1))
    XCTAssertFalse(panel.isVisible)
  }

  func testSpaceAndEscapeCloseThePanelOnTheFirstPressOnly() {
    XCTAssertTrue(QuickLookPanel.closesPanel(keyCode: 49, modifiers: [], isRepeat: false))
    XCTAssertTrue(QuickLookPanel.closesPanel(keyCode: 53, modifiers: [], isRepeat: false))
    XCTAssertFalse(QuickLookPanel.closesPanel(keyCode: 49, modifiers: [], isRepeat: true))
    XCTAssertFalse(QuickLookPanel.closesPanel(keyCode: 49, modifiers: [.command], isRepeat: false))
    XCTAssertFalse(QuickLookPanel.closesPanel(keyCode: 123, modifiers: [], isRepeat: false))
  }

  func testTheDelegateHandlesSpaceAndLeavesOtherKeys() throws {
    let panel = try XCTUnwrap(QLPreviewPanel.shared())
    func press(_ code: UInt16, repeating: Bool = false) throws -> NSEvent {
      try XCTUnwrap(
        NSEvent.keyEvent(
          with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0,
          context: nil, characters: " ", charactersIgnoringModifiers: " ", isARepeat: repeating,
          keyCode: code))
    }
    XCTAssertTrue(QuickLookPanel.shared.previewPanel(panel, handle: try press(49)))
    XCTAssertTrue(QuickLookPanel.shared.previewPanel(panel, handle: try press(49, repeating: true)))
    XCTAssertFalse(QuickLookPanel.shared.previewPanel(panel, handle: try press(123)))
  }

  func testTheResponderTakesControlOfThePanel() throws {
    let panel = try XCTUnwrap(QLPreviewPanel.shared())
    let responder = QuickLookResponder()
    XCTAssertTrue(responder.acceptsPreviewPanelControl(panel))
    responder.beginPreviewPanelControl(panel)
    XCTAssertTrue(panel.dataSource === QuickLookPanel.shared)
    XCTAssertTrue(panel.delegate === QuickLookPanel.shared)
    responder.endPreviewPanelControl(panel)
    XCTAssertNil(panel.dataSource)
  }

  func testTheResponderJoinsTheChainOnce() {
    let controller = NSViewController()
    QuickLookResponder.install(after: controller)
    let first = controller.nextResponder
    QuickLookResponder.install(after: controller)
    XCTAssertTrue(first is QuickLookResponder)
    XCTAssertTrue(controller.nextResponder === first)
  }

  func testWithoutAWindowThatTakesControlThereIsNothingToShowItFor() throws {
    let file = folder.appendingPathComponent("lonely.txt")
    try Data("hello".utf8).write(to: file)
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 100, height: 100), styleMask: [.titled],
      backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    NSApp.activate(ignoringOtherApps: true)
    window.makeKeyAndOrderFront(nil)
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.3))
    defer { window.close() }
    XCTAssertFalse(QuickLookPanel.shared.preview(path: file.path), "no preview")
    XCTAssertNil(QuickLookPanel.shared.item, "no item")
  }

  func testClosingWithNothingOpenIsSafe() {
    QuickLookPanel.shared.close()
    XCTAssertNil(QuickLookPanel.shared.item, "no item")
  }
}
