import 'package:flutter/widgets.dart';
import 'package:gpt_markdown/custom_widgets/code_field.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:material_ui/material_ui.dart' as mui;

import '../files/widgets/safe_path_text.dart';

/// The longest line of a code block that still gets syntax colours.
const kHighlightMaxLine = 500;

/// The most characters of one code block that get syntax colours.
const kHighlightMaxBlock = 8000;

/// The most characters that get syntax colours in one markdown document, summed
/// over its code blocks (later blocks are plain).
const kHighlightMaxDocument = 10000;

/// The most code blocks of one markdown document that are built as a
/// [CodeField]; every later one is a [PlainCodeBlock].
const kCodeFieldMaxCount = 50;

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
/// starts with [begin] and asks about its blocks in document order. A block
/// asked about again at the same place (a rebuild, or a reply that streams and
/// grows by a few characters) is judged again in place of its old self, since
/// a block's decision only reads the blocks before it. Only the length granted
/// to each block is kept.
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

  /// Moves to the block at [index] of the document, which the next [admit]
  /// judges.
  void seek(int index) => _next = index;

  /// Forgets every decision, for a document that was replaced.
  void clear() {
    _granted.clear();
    _next = 0;
  }

  /// Whether the next block of the document, with body [code], may be coloured.
  bool admit(String code) {
    final index = _next++;
    final ok = _fits(code, _usedBefore(index));
    final length = ok ? code.length : 0;
    if (index < _granted.length) {
      _granted[index] = length;
    } else {
      _granted.add(length);
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

/// A code block past [kCodeFieldMaxCount]: the panel, language label, header
/// height, padding and monospace text of a `CodeField`, without highlighting,
/// the copy button (its state, tooltip and ink) or the horizontal scroll view:
/// a long line wraps. The text goes through
/// [safeContentText], so bidi and control characters show as `<U+XXXX>`.
class PlainCodeBlock extends StatelessWidget {
  const PlainCodeBlock({
    super.key,
    required this.name,
    required this.codes,
    required this.style,
    required this.scalesItsOwnText,
  });

  final String name;
  final String codes;
  final CodeBlockStyle style;
  final bool scalesItsOwnText;

  /// The height of a `CodeField` header, set by its 32 point copy button.
  static const _headerHeight = 32.0;

  @override
  Widget build(BuildContext context) {
    final theme = mui.Theme.of(context);
    final scheme = theme.colorScheme;
    final family = style.fontFamily;
    final radius = BorderRadius.all(
      style.borderRadius ?? const Radius.circular(12),
    );
    final borderColor = style.borderColor;
    final displayName = name.trim().isEmpty ? 'Code' : name;
    const icon = mui.Icons.terminal_rounded;
    final body = DecoratedBox(
      decoration: BoxDecoration(
        color: style.backgroundColor ?? scheme.surfaceContainer,
        borderRadius: radius,
        border: borderColor == null
            ? null
            : Border.all(color: borderColor, width: style.borderWidth ?? 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (style.showLanguageLabel ?? true)
            Padding(
              padding:
                  style.headerPadding ?? const EdgeInsets.fromLTRB(10, 8, 8, 2),
              child: SizedBox(
                height: _headerHeight,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: String.fromCharCode(icon.codePoint),
                              semanticsLabel: '',
                              style: TextStyle(
                                fontFamily: icon.fontFamily,
                                package: icon.fontPackage,
                                fontSize: 13,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            TextSpan(text: ' $displayName'),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: style.languageStyle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: style.padding ?? const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Text(
              safeContentText(codes),
              textDirection: TextDirection.ltr,
              style: TextStyle(
                fontFamily: family ?? 'JetBrainsMono',
                package: family == null
                    ? 'gpt_markdown'
                    : style.fontFamilyPackage,
                fontSize: style.fontSize,
                color: style.textColor,
              ),
            ),
          ),
        ],
      ),
    );
    return MarkdownTextScaling.wrap(body, enabled: scalesItsOwnText);
  }
}

/// `GptMarkdown` whose fenced code blocks stay within a render budget (see
/// [CodeHighlightBudget] and [kCodeFieldMaxCount]): a block over it is drawn as
/// plain monospace text in the same panel, with its language label.
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

/// An upper bound of the code blocks in [markdown], from one scan of the text:
/// a closed fence has two markers (` ``` ` or `~~~`), an open one has one, and
/// a `<pre` block counts as two. A marker inside a code block or a sentence
/// only raises it.
int codeFenceBound(String markdown) {
  var markers = 0;
  for (final marker in const ['```', '~~~', '<pre']) {
    final weight = marker == '<pre' ? 2 : 1;
    var at = markdown.indexOf(marker);
    while (at >= 0) {
      markers += weight;
      at = markdown.indexOf(marker, at + marker.length);
    }
  }
  return (markers + 1) ~/ 2;
}

class _BoundedMarkdownState extends State<BoundedMarkdown> {
  final _budget = CodeHighlightBudget();

  /// [codeFenceBound] of the current data.
  int _bound = 0;

  /// Blocks asked about since this widget last built. In a document over the
  /// cap every render is a whole one (see [build]), so the place of a block is
  /// this count modulo [_bound]: a whole render that the renderer starts on its
  /// own, without a build here, comes out the same.
  int _asked = 0;

  @override
  void initState() {
    super.initState();
    _bound = codeFenceBound(widget.data);
  }

  @override
  void didUpdateWidget(BoundedMarkdown old) {
    super.didUpdateWidget(old);
    if (widget.data != old.data) _bound = codeFenceBound(widget.data);
    // A reply that streams only grows; anything else is another document.
    if (!widget.data.startsWith(old.data)) _budget.clear();
  }

  Widget _code(BuildContext context, String name, String code, bool closed) {
    const config = GptMarkdownConfig();
    final style =
        (resolvedStyleSheet(context, config).codeBlock ??
                const CodeBlockStyle())
            .resolve(mui.Theme.of(context).colorScheme);
    // A block drawn inside a paragraph is scaled by it; one of its own
    // scales itself, as in the renderer's default block.
    final scalesItsOwnText =
        context.findAncestorWidgetOfExactType<RichText>() == null;
    if (_bound > kCodeFieldMaxCount) {
      final place = _asked++ % _bound;
      if (place >= kCodeFieldMaxCount) {
        return PlainCodeBlock(
          name: name,
          codes: code,
          style: style,
          scalesItsOwnText: scalesItsOwnText,
        );
      }
      _budget.seek(place);
    }
    return CodeField(
      scalesItsOwnText: scalesItsOwnText,
      name: name,
      codes: code,
      highlightCode:
          _budget.admit(code) &&
          (closed || (style.highlightWhileStreaming ?? true)),
      style: style,
    );
  }

  @override
  Widget build(BuildContext context) {
    _budget.begin();
    _asked = 0;
    return GptMarkdown(
      // `GptMarkdown` keeps the blocks it built and asks only about the new or
      // changed ones, from which a block's place in the document cannot be
      // known. A document that may hold more fences than the cap is therefore
      // built whole each time its text changes (a new state, no kept blocks),
      // so that the places are counted from its first block; one within the cap
      // never needs a place and keeps the incremental render.
      key: _bound > kCodeFieldMaxCount ? ValueKey(widget.data) : null,
      widget.data,
      style: widget.style,
      onLinkTap: widget.onLinkTap,
      // ignore: deprecated_member_use
      linkBuilder: widget.linkBuilder,
      codeBuilder: _code,
    );
  }
}
