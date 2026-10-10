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
    try? FileManager.default.removeItem(at: folder)
  }

  func testAFileThatIsGoneCannotBePreviewed() {
    let missing = folder.appendingPathComponent("gone.pdf").path
    XCTAssertFalse(QuickLookPanel.shared.preview(path: missing))
    XCTAssertEqual(QuickLookPanel.shared.toggle(path: missing) as? Bool, false)
    XCTAssertNil(QuickLookPanel.shared.item)
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
    XCTAssertTrue(QuickLookPanel.shared.preview(path: file.path))
    let panel = try XCTUnwrap(QLPreviewPanel.shared())
    XCTAssertTrue(panel.isVisible)
    XCTAssertEqual(QuickLookPanel.shared.item, file)
    XCTAssertEqual(QuickLookPanel.shared.toggle(path: file.path) as? String, "closed")
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 1))
    XCTAssertFalse(panel.isVisible)
    XCTAssertEqual(QuickLookPanel.shared.toggle(path: file.path) as? String, "shown")
    XCTAssertTrue(panel.isVisible)
    QuickLookPanel.shared.close()
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 1))
    XCTAssertFalse(panel.isVisible)
  }

  func testClosingWithNothingOpenIsSafe() {
    QuickLookPanel.shared.close()
    XCTAssertNil(QuickLookPanel.shared.item)
  }
}
