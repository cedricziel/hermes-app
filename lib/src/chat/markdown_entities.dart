import 'package:html_unescape/html_unescape.dart';

final _unescape = HtmlUnescape();

/// Fenced code blocks (closed or still streaming) and inline code spans.
final _code = RegExp(r'(```|~~~)[\s\S]*?(?:\1|$)|`[^`\n]*`');

final _tableDelimiter = RegExp(
  r'^\s*\|?\s*:?-+:?\s*(?:\|\s*:?-+:?\s*)*\|?\s*$',
);
final _fence = RegExp(r'^ {0,3}(`{3,}|~{3,})(.*)$');

int _pipeCellCount(String line) {
  if (!line.contains('|')) return 0;
  final cells = line.trim().split('|');
  if (cells.first.trim().isEmpty) cells.removeAt(0);
  if (cells.last.trim().isEmpty) cells.removeLast();
  return cells.length;
}

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
  final out = <String>[];
  var inTable = false;
  String? fenceMarker;

  for (final line in markdown.split('\n')) {
    final marker = _fence.firstMatch(line)?.group(1);
    if (fenceMarker != null) {
      if (marker != null &&
          marker[0] == fenceMarker[0] &&
          marker.length >= fenceMarker.length &&
          line.substring(line.indexOf(marker) + marker.length).trim().isEmpty) {
        fenceMarker = null;
      }
      out.add(line);
      inTable = false;
      continue;
    }
    if (marker != null) {
      fenceMarker = marker;
      out.add(line);
      inTable = false;
      continue;
    }
    if (_tableDelimiter.hasMatch(line) && line.contains('|')) {
      final header = out.isEmpty ? '' : out.last;
      final isTable =
          _pipeCellCount(header) > 0 &&
          _pipeCellCount(header) == _pipeCellCount(line);
      final insert =
          isTable &&
          out.length >= 2 &&
          out[out.length - 2].trim().isNotEmpty &&
          !(inTable && header.contains('|'));
      if (insert) out.insert(out.length - 1, '');
      inTable = isTable;
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
