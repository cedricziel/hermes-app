import Cocoa
import FlutterMacOS
import XCTest
@testable import Hermes

class RunnerTests: XCTestCase {

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
