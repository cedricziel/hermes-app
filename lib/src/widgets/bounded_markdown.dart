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
/// document that repeats one block is charged for every copy. A block is asked
/// about with its place ([admitAt]), or, for a pass that asks about every block
/// in document order, by [begin] and [admit] counting the places. A block asked
/// about again at the same place (a rebuild, or a reply that streams and grows
/// by a few characters) is judged again in place of its old self, since a
/// block's decision only reads the blocks before it. [plan] judges a whole
/// document from a place on, so a block that is not asked about again (a
/// finished one the renderer kept) still has its decision. Only the length
/// granted to each block is kept.
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

  /// Forgets every decision, for a document that was replaced.
  void clear() {
    _granted.clear();
    _next = 0;
  }

  /// Whether the next block of the document, with body [code], may be coloured.
  bool admit(String code) => admitAt(_next++, code);

  /// Whether the block at place [index] of the document, with body [code], may
  /// be coloured. A place past the ones known is judged as the next one.
  bool admitAt(int index, String code) {
    if (index > _granted.length) index = _granted.length;
    _next = index + 1;
    final ok = _fits(code, _usedBefore(index));
    final length = ok ? code.length : 0;
    if (index < _granted.length) {
      _granted[index] = length;
    } else {
      _granted.add(length);
    }
    return ok;
  }

  /// Judges every block of a document whose bodies are [codes], in order, from
  /// place [from] on; the places before it keep their decisions (they are the
  /// same blocks after the same blocks).
  void plan(List<String> codes, {int from = 0}) {
    from = from.clamp(0, _granted.length);
    if (from < _granted.length) {
      _granted.length = from;
    }
    var used = _usedBefore(from);
    for (var i = from; i < codes.length; i++) {
      final ok = _fits(codes[i], used);
      final length = ok ? codes[i].length : 0;
      _granted.add(length);
      used += length;
    }
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
  final _fences = _DocumentFences();

  // `GptMarkdown` keeps what it rendered per segment and builds a code block
  // again only when its segment changed, so a pass asks about some blocks only,
  // usually the last ones. A block's place is therefore read from the document
  // (`_DocumentFences`), not counted from the first question of a pass: a pass
  // is expected to start at the first block that changed, or at the first block
  // when the renderer dropped what it kept.
  int _start = 0;
  int? _cursor;
  int _firstOfPass = 0;
  bool _dropped = true;
  bool _repeat = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The renderer drops every segment it kept when an inherited value changes
    // (a theme, the text scale) and builds every block again.
    _dropped = true;
  }

  @override
  void didUpdateWidget(BoundedMarkdown old) {
    super.didUpdateWidget(old);
    // A reply that streams only grows; anything else is another document.
    if (!widget.data.startsWith(old.data)) _budget.clear();
    if (widget.style != old.style) _dropped = true;
  }

  /// Where the block with body [code], asked about now, sits in the document.
  int _placeOf(String code) {
    final codes = _fences.codes;
    final from = _cursor ?? (_repeat ? _firstOfPass : _start);
    if (_cursor == null) {
      // A pass ends with its frame; a question with no build before it (the
      // renderer rebuilt on its own) repeats the last pass.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _cursor = null;
        _repeat = true;
      });
    }
    var place = -1;
    for (var i = from; i < codes.length && place < 0; i++) {
      if (codes[i] == code) place = i;
    }
    if (place < 0) {
      // Not after the expected place: another form of the same body (the last
      // block while its closing fence arrives) or misjudged places. Take the
      // expected place, unless the body is found before it.
      place = from;
      for (var i = 0; i < from && i < codes.length; i++) {
        if (codes[i] == code) {
          place = i;
          break;
        }
      }
    }
    if (_cursor == null) _firstOfPass = place;
    _cursor = place + 1;
    return place;
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
          _budget.admitAt(_placeOf(code), code) &&
          (closed || (style.highlightWhileStreaming ?? true)),
      style: style,
    );
  }

  @override
  Widget build(BuildContext context) {
    // What the renderer reads, so that a change of it rebuilds this widget too
    // and reaches didChangeDependencies.
    mui.Theme.of(context);
    GptMarkdownTheme.of(context);
    DefaultTextStyle.of(context);
    MediaQuery.maybeTextScalerOf(context);
    Directionality.maybeOf(context);
    _fences.update(widget.data);
    _start = _dropped ? 0 : _fences.firstChanged;
    _budget.plan(_fences.codes, from: _start);
    _dropped = false;
    _repeat = false;
    _cursor = null;
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

/// The bodies of the fenced code blocks of a markdown document, in document
/// order, read the way `GptMarkdown` reads it: split into the segments it
/// renders one by one, each parsed once.
class _DocumentFences {
  final _segments = MarkdownSegmentCache();
  Map<String, List<String>> _parsed = {};

  /// The code of every block, in document order.
  List<String> codes = const [];

  List<String> _before = const [];

  /// The place of the first block in a segment that changed since the last
  /// [update], the first one `GptMarkdown` builds again; the count of blocks
  /// when no segment changed.
  int firstChanged = 0;

  void update(String data) {
    const config = GptMarkdownConfig();
    final html = config.markdownHtml;
    final registry = config.blockRegistry;
    var source = data.trim();
    if (source.contains('\r')) {
      source = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    }
    final segments = _segments.update(
      source,
      blockRegistry: registry,
      html: html,
    );
    // The renderer keeps a segment's output by its index and text.
    var same = 0;
    while (same < _before.length &&
        same < segments.length &&
        _before[same] == segments[same]) {
      same++;
    }
    final parsed = <String, List<String>>{};
    final next = <String>[];
    var changed = -1;
    for (var i = 0; i < segments.length; i++) {
      if (i == same) changed = next.length;
      final segment = segments[i];
      next.addAll(
        parsed[segment] ??=
            _parsed[segment] ?? _fencesIn(segment, registry, html),
      );
    }
    _parsed = parsed;
    _before = segments;
    firstChanged = changed < 0 ? next.length : changed;
    codes = next;
  }

  static List<String> _fencesIn(
    String segment,
    MarkdownBlockRegistry? registry,
    MarkdownHtml html,
  ) {
    final out = <String>[];
    try {
      _collect(
        Plusparse.parse(segment, blockRegistry: registry, html: html).children,
        out,
      );
    } on Object {
      // A segment the parser rejects has no places; its blocks are judged in
      // the order they are asked about.
    }
    return out;
  }

  static void _collect(List<MdNode> nodes, List<String> out) {
    for (final node in nodes) {
      switch (node) {
        case MdCodeBlock(:final code):
          out.add(code);
        case MdBlockQuote(:final children, :final alert):
          _collect(children, out);
          if (alert != null) _collect(alert.children, out);
        case MdUnorderedList(:final items):
          for (final item in items) {
            _collect(item.children, out);
          }
        case MdOrderedList(:final items):
          for (final item in items) {
            _collect(item.children, out);
          }
        case MdCheckbox(:final children):
          _collect(children, out);
        case MdRadio(:final children):
          _collect(children, out);
        case MdFootnoteDefinitions(:final footnotes):
          for (final note in footnotes) {
            _collect(note.children, out);
          }
        default:
      }
    }
  }
}
