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

/// The most characters of one fenced block that get syntax colours.
///
/// The highlighter (`val_highlight`) is quadratic on some inputs and colours
/// every token as its own text run: a 20 000 character line of spaces took
/// about 6 s and 100 000 characters of `1+` about 16 s on the UI isolate, which
/// is a frozen app for one crafted or unlucky reply. A block over this size or
/// with a line over [kMaxHighlightedLine] is shown as plain text.
const kMaxHighlightedChars = 20000;

/// The longest single line of a fenced block that still gets syntax colours.
const kMaxHighlightedLine = 1000;

/// Drops the language tag of every fenced code block that is too big to
/// colour, so `gpt_markdown` shows it as plain text (a fence with no grammar
/// has none). Everything else, including the block's body, is returned as it
/// was; text that holds no fence is returned as the same string. A block that
/// is still streaming is judged on what has arrived, so one that grows past a
/// limit loses its colours at that point and keeps them off.
String boundCodeFences(String markdown) {
  if (!markdown.contains('```') && !markdown.contains('~~~')) return markdown;
  final lines = markdown.split('\n');
  String? marker;
  var openAt = -1;
  var chars = 0;
  var tooBig = false;
  var changed = false;

  void close() {
    if (tooBig) {
      final open = lines[openAt];
      final match = _fence.firstMatch(open)!;
      final info = match.group(2)!;
      if (info.trim().isNotEmpty) {
        lines[openAt] = open.substring(0, match.end - info.length);
        changed = true;
      }
    }
    marker = null;
  }

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final found = _fence.firstMatch(line)?.group(1);
    final open = marker;
    if (open == null) {
      if (found != null) {
        marker = found;
        openAt = i;
        chars = 0;
        tooBig = false;
      }
      continue;
    }
    if (found != null &&
        found[0] == open[0] &&
        found.length >= open.length &&
        line.substring(line.indexOf(found) + found.length).trim().isEmpty) {
      close();
      continue;
    }
    chars += line.length + 1;
    if (chars > kMaxHighlightedChars || line.length > kMaxHighlightedLine) {
      tooBig = true;
    }
  }
  if (marker != null) close();
  return changed ? lines.join('\n') : markdown;
}

/// Full preprocessing for chat markdown before it reaches the renderer.
String normalizeMarkdown(String markdown) =>
    insertTableBlankLines(decodeMarkdownEntities(markdown));
