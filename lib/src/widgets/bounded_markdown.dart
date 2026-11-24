import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:material_ui/material_ui.dart' as mui;

import 'hermes_code_block.dart';

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
/// [maxBlock] characters, and the coloured blocks before it plus this one stay
/// within [maxDocument]. The decision is made on the parsed code string, so it
/// holds for every fence form the renderer accepts (quotes, lists,
/// indentation, `<pre><code>`, CRLF).
///
/// Blocks are told apart by their place in the document, not by their text: a
/// document that repeats one block is charged for every copy. A render pass
/// starts with [begin] and asks about its blocks in document order with
/// [admit]. A block asked about again at the same place (a rebuild, or a reply
/// that streams and grows by a few characters) is judged again in place of its
/// old self, since a block's decision only reads the blocks before it. The
/// length granted to each block and its code are kept.
///
/// `GptMarkdown` also draws some blocks again outside such a pass, and only
/// the blocks of the segments it redraws (the end of a held reply is released
/// by a timer). Those go to [admitRedrawn], which finds the place of the block
/// by its code and charges it for every other place's grant.
class CodeHighlightBudget {
  CodeHighlightBudget({
    this.maxLine = kHighlightMaxLine,
    this.maxBlock = kHighlightMaxBlock,
    this.maxDocument = kHighlightMaxDocument,
  });

  final int maxLine;
  final int maxBlock;
  final int maxDocument;

  /// The characters each block was granted (0 when it is plain).
  final List<int> _granted = [];

  /// The code each block was asked about with, by place.
  final List<String> _codes = [];

  /// The places [admitRedrawn] gave out since [beginRedrawn].
  final Set<int> _taken = {};
  int _next = 0;

  /// Characters granted to the blocks asked about so far in this pass.
  int get used => _usedBefore(_next);

  int _usedBefore(int index) {
    var sum = 0;
    for (var i = 0; i < index && i < _granted.length; i++) {
      sum += _granted[i];
    }
    return sum;
  }

  /// Starts a pass over the document, from its first block.
  void begin() => _next = 0;

  /// Starts a series of [admitRedrawn] calls: a place is given out once in it,
  /// so a document that repeats a block gets each copy its own place.
  void beginRedrawn() => _taken.clear();

  /// Forgets every decision, for a document that was replaced.
  void clear() {
    _granted.clear();
    _codes.clear();
    _taken.clear();
    _next = 0;
  }

  /// Whether the next block of the document, with body [code], may be coloured.
  bool admit(String code) {
    final index = _next++;
    return _judge(index, code, _usedBefore(index));
  }

  /// Whether a block drawn again outside a pass, with body [code], may be
  /// coloured. Its place is the one that was asked about with the same code, or
  /// with a start of it (a block that is still growing); a block with no place
  /// takes a new one at the end. It is charged for every other place's grant,
  /// so the document limit holds whichever blocks are drawn again.
  bool admitRedrawn(String code) {
    bool free(int i) => !_taken.contains(i);
    var place = -1;
    for (var i = 0; i < _codes.length && place < 0; i++) {
      if (free(i) && _codes[i] == code) place = i;
    }
    for (var i = 0; i < _codes.length && place < 0; i++) {
      if (free(i) && _codes[i].isNotEmpty && code.startsWith(_codes[i])) {
        place = i;
      }
    }
    if (place < 0) place = _codes.length;
    _taken.add(place);
    final own = place < _granted.length ? _granted[place] : 0;
    return _judge(place, code, _usedBefore(_granted.length) - own);
  }

  bool _judge(int index, String code, int usedBefore) {
    final ok = _fits(code, usedBefore);
    final length = ok ? code.length : 0;
    if (index < _granted.length) {
      _granted[index] = length;
      _codes[index] = code;
    } else {
      _granted.add(length);
      _codes.add(code);
    }
    return ok;
  }

  bool _fits(String code, int usedBefore) {
    if (code.length > maxBlock || usedBefore + code.length > maxDocument) {
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
    this.checkboxBuilder,
    this.radioOptionBuilder,
  });

  final String data;
  final TextStyle? style;
  final void Function(String url, String title)? onLinkTap;
  // ignore: deprecated_member_use
  final LinkBuilder? linkBuilder;
  final CheckboxBuilder? checkboxBuilder;
  final RadioOptionBuilder? radioOptionBuilder;

  @override
  State<BoundedMarkdown> createState() => _BoundedMarkdownState();
}

class _BoundedMarkdownState extends State<BoundedMarkdown> {
  final _budget = CodeHighlightBudget();

  /// Whether `build` started the pass of the frame in progress, and whether a
  /// series of redrawn blocks has started in it.
  bool _passOpen = false;
  bool _redrawOpen = false;

  void _endOfFrame() {
    if (_passOpen || _redrawOpen) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _passOpen = false;
      _redrawOpen = false;
    });
  }

  /// Starts a pass over the document. Only `build` does: a block asked about
  /// in a frame where it did not (`GptMarkdown` draws its blocks again by
  /// itself, from its own rebuild or a timer) goes to
  /// [CodeHighlightBudget.admitRedrawn], since it may be the only block drawn
  /// and has no place in a pass that begins at the first block.
  void _beginPass() {
    _budget.begin();
    _endOfFrame();
    _passOpen = true;
  }

  bool _admit(String code) {
    if (_passOpen) return _budget.admit(code);
    if (!_redrawOpen) {
      _budget.beginRedrawn();
      _endOfFrame();
      _redrawOpen = true;
    }
    return _budget.admitRedrawn(code);
  }

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
    return HermesCodeBlock(
      // A block drawn inside a paragraph is scaled by it; one of its own
      // scales itself, as in the renderer's default block.
      scalesItsOwnText:
          context.findAncestorWidgetOfExactType<RichText>() == null,
      name: name,
      codes: code,
      highlightCode:
          _admit(code) && (closed || (style.highlightWhileStreaming ?? true)),
      style: style,
    );
  }

  @override
  Widget build(BuildContext context) {
    _beginPass();
    return GptMarkdown(
      widget.data,
      style: widget.style,
      onLinkTap: widget.onLinkTap,
      // ignore: deprecated_member_use
      linkBuilder: widget.linkBuilder,
      checkboxBuilder: widget.checkboxBuilder,
      radioOptionBuilder: widget.radioOptionBuilder,
      codeBuilder: _code,
    );
  }
}
