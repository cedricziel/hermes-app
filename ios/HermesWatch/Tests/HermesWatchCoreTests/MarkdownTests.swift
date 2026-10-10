import XCTest

@testable import HermesWatchCore

final class MarkdownTests: XCTestCase {
  private func plain(_ markdown: String) -> String {
    String(WatchMarkdown.attributed(markdown).characters)
  }

  func testInlineMarkupIsRenderedNotShown() {
    XCTAssertEqual(plain("Use **bold**, *italic* and `code`."), "Use bold, italic and code.")
  }

  func testStrongTextIsMarkedStrong() {
    let text = WatchMarkdown.attributed("A **big** deal")
    let strong = text.runs.filter { $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true }
    XCTAssertEqual(strong.map { String(text[$0.range].characters) }, ["big"])
  }

  func testHeadingsBecomeStrongLines() {
    XCTAssertEqual(plain("## Plan\nFirst step"), "Plan\nFirst step")
  }

  func testBulletsBecomeDots() {
    XCTAssertEqual(plain("- one\n* two\n  + three"), "• one\n• two\n  • three")
  }

  func testCodeFencesAreDroppedAndTheirLinesKept() {
    XCTAssertEqual(plain("Run:\n```sh\nls -la\n```\nDone"), "Run:\nls -la\nDone")
  }

  func testLineBreaksSurvive() {
    XCTAssertEqual(plain("one\n\ntwo"), "one\n\ntwo")
  }

  func testTextThatIsNotMarkdownStaysAsItIs() {
    XCTAssertEqual(plain("2 * 3 = 6 and [not a link"), "2 * 3 = 6 and [not a link")
  }
}
