import 'package:html_unescape/html_unescape.dart';

final _unescape = HtmlUnescape();

/// Fenced code blocks (closed or still streaming) and inline code spans.
final _code = RegExp(r'(```|~~~)[\s\S]*?(?:\1|$)|`[^`\n]*`');

/// A GFM table delimiter row: cells of dashes/colons separated by pipes
/// (`|---|:---:|` — outer pipes optional). Needs at least two columns, so a
/// plain `---` rule never matches. An inline code span can never produce a
/// full-line match: the backticks around it fail the pattern.
final _tableDelimiter = RegExp(r'^\s*\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)+\|?\s*$');

/// Decodes the HTML entities a model writes into markdown (`&lt;`, `&amp;`),
/// which `gpt_markdown` would show as typed. Code keeps them, as in CommonMark.
String decodeMarkdownEntities(String markdown) => markdown.contains('&')
    ? markdown.splitMapJoin(
        _code,
        onMatch: (m) => m[0]!,
        onNonMatch: _unescape.convert,
      )
    : markdown;

/// Makes GFM pipe tables render in `gpt_markdown`: the renderer only starts a
/// table block after a blank line, while GFM lets a table interrupt a
/// paragraph — so a blank line is inserted before a table's delimiter row
/// when a non-blank line sits directly above its header row. Lines that start
/// inside a fenced code block (closed or still streaming) are never touched,
/// and a fence interrupts an open table.
String insertTableBlankLines(String markdown) {
  if (!markdown.contains('|')) return markdown;
  // Start offsets of the regions the [_code] pattern protects: a line whose
  // first character falls inside one is a code line, byte for byte.
  final codeStarts = <int>[];
  final codeEnds = <int>[];
  for (final match in _code.allMatches(markdown)) {
    codeStarts.add(match.start);
    codeEnds.add(match.end);
  }

  final out = <String>[];
  // Inside a table body: set by a delimiter row, cleared by a blank line, a
  // line without a pipe (a table row always contains one) or a code fence.
  var inTable = false;
  var cursor = 0;
  var nextRegion = 0;

  for (final line in markdown.split('\n')) {
    final lineStart = cursor;
    cursor += line.length + 1;
    while (nextRegion < codeStarts.length &&
        codeEnds[nextRegion] <= lineStart) {
      nextRegion++;
    }
    final isCodeLine =
        nextRegion < codeStarts.length && codeStarts[nextRegion] <= lineStart;
    if (isCodeLine) {
      out.add(line);
      inTable = false;
      continue;
    }
    if (_tableDelimiter.hasMatch(line)) {
      final header = out.isEmpty ? '' : out.last;
      // Only insert when a real line sits directly above the header row: not
      // at the very start of the message and not when a blank line already
      // separates the block. A pipe-bearing header of a table an earlier
      // delimiter row opened is a body row and must not split the table.
      final insert =
          out.length >= 2 &&
          out[out.length - 2].trim().isNotEmpty &&
          !(inTable && header.contains('|'));
      // The blank line goes between the header row and the line above it.
      if (insert) out.insert(out.length - 1, '');
      inTable = true;
    } else if (line.trim().isEmpty || !line.contains('|')) {
      inTable = false;
    }
    out.add(line);
  }
  return out.join('\n');
}

/// Full preprocessing for chat markdown before it reaches the renderer.
String normalizeMarkdown(String markdown) =>
    insertTableBlankLines(decodeMarkdownEntities(markdown));
