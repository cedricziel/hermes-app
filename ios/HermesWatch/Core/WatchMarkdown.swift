import Foundation

/// Hermes writes Markdown. The watch renders its inline markup (bold, italic,
/// code, links) and flattens the block markup a small screen has no room for:
/// headings become bold lines, bullets become dots and code fences go.
enum WatchMarkdown {
  static func attributed(_ markdown: String) -> AttributedString {
    let source = flattenBlocks(markdown)
    let options = AttributedString.MarkdownParsingOptions(
      interpretedSyntax: .inlineOnlyPreservingWhitespace,
      failurePolicy: .returnPartiallyParsedIfPossible
    )
    return (try? AttributedString(markdown: source, options: options)) ?? AttributedString(markdown)
  }

  private static func flattenBlocks(_ markdown: String) -> String {
    var inFence = false
    var lines: [String] = []
    for line in markdown.split(separator: "\n", omittingEmptySubsequences: false) {
      let trimmed = line.drop { $0 == " " }
      if trimmed.hasPrefix("```") {
        inFence.toggle()
        continue
      }
      if inFence {
        lines.append(String(line))
        continue
      }
      let indent = String(line.prefix(line.count - trimmed.count))
      if let heading = heading(trimmed) {
        lines.append("\(indent)**\(heading)**")
      } else if let first = trimmed.first, "-*+".contains(first), trimmed.dropFirst().first == " " {
        lines.append("\(indent)• \(trimmed.dropFirst(2))")
      } else {
        lines.append(String(line))
      }
    }
    return lines.joined(separator: "\n")
  }

  private static func heading(_ line: Substring) -> Substring? {
    let marks = line.prefix { $0 == "#" }
    guard (1...6).contains(marks.count), line.dropFirst(marks.count).first == " " else { return nil }
    let text = line.dropFirst(marks.count + 1)
    return text.isEmpty ? nil : text
  }
}
