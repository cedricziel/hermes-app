import 'package:html_unescape/html_unescape.dart';

final _unescape = HtmlUnescape();

/// Fenced code blocks (closed or still streaming) and inline code spans.
final _code = RegExp(r'(```|~~~)[\s\S]*?(?:\1|$)|`[^`\n]*`');

/// Decodes the HTML entities a model writes into markdown (`&lt;`, `&amp;`),
/// which `gpt_markdown` would show as typed. Code keeps them, as in CommonMark.
String decodeMarkdownEntities(String markdown) => markdown.contains('&')
    ? markdown.splitMapJoin(
        _code,
        onMatch: (m) => m[0]!,
        onNonMatch: _unescape.convert,
      )
    : markdown;
