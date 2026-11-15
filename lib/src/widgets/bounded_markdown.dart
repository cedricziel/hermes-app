import 'package:flutter/widgets.dart';
import 'package:gpt_markdown/custom_widgets/code_field.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:material_ui/material_ui.dart' as mui;

/// The longest line of a code block that still gets syntax colours.
const kHighlightMaxLine = 500;

/// The most characters of one code block that get syntax colours.
const kHighlightMaxBlock = 8000;

/// The most characters that get syntax colours in one markdown document, summed
/// over its code blocks (later blocks are plain).
const kHighlightMaxDocument = 10000;

/// Decides which code blocks of one markdown document are coloured.
///
/// The highlighter (`val_highlight`) is quadratic on some inputs and gives
/// every token its own text run, and a run costs about 20 us of layout and
/// paint: one block of 20 000 spaces took ~6 s, 100 000 characters of `1+` ~16 s
/// and 50 blocks of a few thousand runs each ~17 s, all on the UI isolate. So a
/// block is coloured only when no line is over [maxLine], the block is at most
/// [maxBlock] characters, and the blocks coloured so far in the document stay
/// within [maxDocument]. The decision is made on the parsed code string, so it
/// holds for every fence form the renderer accepts (quotes, lists, indentation,
/// `<pre><code>`, CRLF).
///
/// A block is asked about again whenever it is rebuilt or, while a reply
/// streams, once per delta with the code grown by a few characters; the answer
/// is kept per block and a grown block replaces its shorter self, so a stream
/// never uses up the budget by itself. Only lengths and the decision are kept
/// beside the code string, which the widget already holds.
class CodeHighlightBudget {
  CodeHighlightBudget({
    this.maxLine = kHighlightMaxLine,
    this.maxBlock = kHighlightMaxBlock,
    this.maxDocument = kHighlightMaxDocument,
  });

  final int maxLine;
  final int maxBlock;
  final int maxDocument;

  final List<({String code, bool granted})> _blocks = [];
  int _used = 0;

  /// Characters granted so far.
  int get used => _used;

  /// Forgets every decision, for a document that was replaced.
  void clear() {
    _blocks.clear();
    _used = 0;
  }

  /// Whether [code] may be coloured.
  bool admit(String code) {
    for (var i = 0; i < _blocks.length; i++) {
      final seen = _blocks[i];
      if (seen.code.startsWith(code)) return seen.granted;
      if (code.startsWith(seen.code)) {
        // The same block, grown: judge it again in place of its old self.
        if (seen.granted) _used -= seen.code.length;
        final granted = _fits(code);
        if (granted) _used += code.length;
        _blocks[i] = (code: code, granted: granted);
        return granted;
      }
    }
    final granted = _fits(code);
    if (granted) _used += code.length;
    _blocks.add((code: code, granted: granted));
    return granted;
  }

  bool _fits(String code) {
    if (code.length > maxBlock || _used + code.length > maxDocument) {
      return false;
    }
    var line = 0;
    for (var i = 0; i < code.length; i++) {
      final unit = code.codeUnitAt(i);
      if (unit == 0x0A || unit == 0x0D) {
        line = 0;
      } else if (++line > maxLine) {
        return false;
      }
    }
    return true;
  }
}

/// `GptMarkdown` whose fenced code blocks stay within a render budget (see
/// [CodeHighlightBudget]): a block over it is drawn as plain monospace text in
/// the same block, with its language label.
///
/// Use it for every markdown a server, a model or another person can write.
/// Other parameters are those of [GptMarkdown] that the app uses.
class BoundedMarkdown extends StatefulWidget {
  const BoundedMarkdown(
    this.data, {
    super.key,
    this.style,
    this.onLinkTap,
    this.linkBuilder,
  });

  final String data;
  final TextStyle? style;
  final void Function(String url, String title)? onLinkTap;
  // ignore: deprecated_member_use
  final LinkBuilder? linkBuilder;

  @override
  State<BoundedMarkdown> createState() => _BoundedMarkdownState();
}

class _BoundedMarkdownState extends State<BoundedMarkdown> {
  final _budget = CodeHighlightBudget();

  @override
  void didUpdateWidget(BoundedMarkdown old) {
    super.didUpdateWidget(old);
    // A reply that streams only grows; anything else is another document.
    if (!widget.data.startsWith(old.data)) _budget.clear();
  }

  Widget _code(BuildContext context, String name, String code, bool closed) {
    const config = GptMarkdownConfig();
    final style =
        (resolvedStyleSheet(context, config).codeBlock ??
                const CodeBlockStyle())
            .resolve(mui.Theme.of(context).colorScheme);
    return CodeField(
      // A block drawn inside a paragraph is scaled by it; one of its own
      // scales itself, as in the renderer's default block.
      scalesItsOwnText:
          context.findAncestorWidgetOfExactType<RichText>() == null,
      name: name,
      codes: code,
      highlightCode:
          _budget.admit(code) &&
          (closed || (style.highlightWhileStreaming ?? true)),
      style: style,
    );
  }

  @override
  Widget build(BuildContext context) => GptMarkdown(
    widget.data,
    style: widget.style,
    onLinkTap: widget.onLinkTap,
    // ignore: deprecated_member_use
    linkBuilder: widget.linkBuilder,
    codeBuilder: _code,
  );
}
