import Cocoa
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

  func testClosingWithNothingOpenIsSafe() {
    QuickLookPanel.shared.close()
    XCTAssertNil(QuickLookPanel.shared.item)
  }
}
