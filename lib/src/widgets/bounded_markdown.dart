import 'package:flutter/foundation.dart' show listEquals, visibleForTesting;
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
    _unplaced.clear();
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

  /// The characters of blocks that have no place in the document, by body.
  final Map<String, int> _unplaced = {};

  /// Whether a block with body [code] that the document parse did not find may
  /// be coloured: it is judged against everything planned for the document and
  /// every other such block, so it can only take what is left. Asked again with
  /// the same body, it keeps its decision.
  bool admitUnplaced(String code) {
    final known = _unplaced[code];
    if (known != null) return known > 0;
    var other = 0;
    for (final v in _unplaced.values) {
      other += v;
    }
    final ok = _fits(code, _usedBefore(_granted.length) + other);
    _unplaced[code] = ok ? code.length : 0;
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
    _unplaced.clear();
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
  // again only when its segment changed, or looked up a link or footnote
  // definition that changed, so a pass asks about some blocks only. A block's
  // place is therefore read from the document (`_DocumentFences`), not counted
  // from the first question of a pass: a pass is expected to ask about the
  // blocks of those segments in order (`_expected`), or about every block when
  // the renderer dropped what it kept. The renderer also builds its tail again
  // on its own (a held-back construct is released after a quiet moment), with
  // no build of ours before it: that pass asks about the tail's blocks.
  List<int> _expected = const [];
  List<int> _pass = const [];
  int? _cursor;
  bool _dropped = true;
  bool _repeat = false;

  // Bumped with every `_budget.clear()`: the renderer keeps the segments that
  // did not change with their old decisions, so a document that was replaced
  // (not appended to) is built again from its first block.
  int _generation = 0;

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
    if (!widget.data.startsWith(old.data)) {
      _budget.clear();
      _generation++;
      _dropped = true;
    }
    if (widget.style != old.style) _dropped = true;
  }

  /// Where the block with body [code], asked about now, sits in the document.
  int _placeOf(String code) {
    final codes = _fences.codes;
    if (_cursor == null) {
      _pass = _repeat ? _fences.tailPlaces : _expected;
      _endPassWithFrame();
    }
    var at = _cursor ?? 0;
    var place = -1;
    for (var j = at; j < _pass.length && place < 0; j++) {
      if (codes[_pass[j]] == code) {
        place = _pass[j];
        at = j;
      }
    }
    // Not among the places still expected: another form of the same body (the
    // last block while its closing fence arrives). Take the next expected
    // place, never an earlier copy's; with none left, the block is judged
    // against what the whole document is planned to use.
    if (place < 0) {
      if (at >= _pass.length) return -1;
      place = _pass[at];
    }
    _cursor = at + 1;
    return place;
  }

  /// A pass ends with its frame; a question with no build before it (the
  /// renderer rebuilt on its own) is about the tail.
  void _endPassWithFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cursor = null;
      _repeat = true;
    });
  }

  bool _admit(String code) {
    final place = _placeOf(code);
    return place < 0
        ? _budget.admitUnplaced(code)
        : _budget.admitAt(place, code);
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
    // What the renderer reads, so that a change of it rebuilds this widget too
    // and reaches didChangeDependencies.
    mui.Theme.of(context);
    GptMarkdownTheme.of(context);
    DefaultTextStyle.of(context);
    MediaQuery.maybeTextScalerOf(context);
    // The renderer reads this while a reply arrives (it labels the revealing
    // text for screen readers) and drops everything it kept when it changes.
    // A dependency it does not have must not be added: that would drop here
    // what the renderer keeps (see the canary test).
    MediaQuery.maybeAccessibleNavigationOf(context);
    Directionality.maybeOf(context);
    _fences.update(widget.data);
    if (_fences.shifted) {
      // A definition that arrived changed the fences of an earlier segment (a
      // footnote shows its own once referenced), which moves the places of the
      // blocks after it. The renderer keeps those with decisions made for their
      // old places, so a new key builds every block again.
      _budget.clear();
      _generation++;
      _dropped = true;
    }
    _expected = _dropped
        ? List.generate(_fences.codes.length, (i) => i)
        : _fences.askedPlaces;
    _budget.plan(
      _fences.codes,
      from: _expected.isEmpty ? _fences.codes.length : _expected.first,
    );
    _dropped = false;
    _repeat = false;
    _cursor = null;
    _endPassWithFrame();
    return GptMarkdown(
      widget.data,
      key: ValueKey(_generation),
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

/// The bodies of the fenced code blocks of [data], as `BoundedMarkdown` reads
/// them to place the questions of the renderer.
@visibleForTesting
List<String> boundedMarkdownFences(String data) =>
    (_DocumentFences()..update(data)).codes;

/// For each of [texts], shown one after the other by one widget, the bodies of
/// the blocks `BoundedMarkdown` expects the renderer to ask about, in order.
@visibleForTesting
List<List<String>> boundedMarkdownExpectedQuestions(List<String> texts) {
  final fences = _DocumentFences();
  return [
    for (final text in texts)
      [
        for (final place in (fences..update(text)).askedPlaces)
          fences.codes[place],
      ],
  ];
}

/// The fences of one segment and the definition labels its parse looked up.
class _Parsed {
  const _Parsed(this.codes, this.lookups);

  final List<String> codes;
  final Set<String> lookups;
}

/// The bodies of the fenced code blocks of a markdown document, in document
/// order, read the way `GptMarkdown` reads it: split into the segments it
/// renders one by one, each parsed once.
class _DocumentFences {
  final _segments = MarkdownSegmentCache();
  Map<String, _Parsed> _parsed = {};

  /// The code of every block, in document order.
  List<String> codes = const [];

  List<String> _before = const [];
  MarkdownDefinitions _definitions = MarkdownDefinitions.empty;

  /// The places of the blocks the renderer builds again after the last
  /// [update], in order: those of the segments that changed (by index and
  /// text) and of the ones that looked up a link or footnote definition that
  /// changed (a footnote is shown, and its fences exist, only once referenced,
  /// from any segment).
  List<int> askedPlaces = const [];

  /// Whether a definition changed the fences of a segment that is followed by
  /// blocks the renderer does not build again.
  bool shifted = false;

  /// The places of the blocks of the last segment, the ones the renderer builds
  /// again on its own while it holds the end of a stream back.
  List<int> tailPlaces = const [];

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
    // The renderer parses every segment against the definitions of the whole
    // document, and builds again the ones that looked up a changed one.
    final definitions = MarkdownDefinitions.collect(
      source,
      blockRegistry: registry,
      html: html,
    );
    final changedKeys = definitions.changedKeys(_definitions);
    _definitions = definitions;
    final stale = {
      for (final MapEntry(:key, :value) in _parsed.entries)
        if (value.lookups.any(changedKeys.contains)) key,
    };
    final parsed = <String, _Parsed>{};
    final next = <String>[];
    final asked = <int>[];
    var tail = const <int>[];
    var moved = false;
    var wasShifted = false;
    for (var i = 0; i < segments.length; i++) {
      final segment = segments[i];
      final isStale = stale.contains(segment);
      final entry =
          parsed[segment] ??
          (isStale ? null : _parsed[segment]) ??
          _fencesIn(segment, registry, html, definitions);
      parsed[segment] = entry;
      if (moved && i < same && !isStale && entry.codes.isNotEmpty) {
        wasShifted = true;
      }
      if (isStale &&
          i < same &&
          !listEquals(_parsed[segment]?.codes, entry.codes)) {
        moved = true;
      }
      final first = next.length;
      next.addAll(entry.codes);
      final places = [for (var k = first; k < next.length; k++) k];
      if (i >= same || isStale) asked.addAll(places);
      if (i == segments.length - 1) tail = places;
    }
    _parsed = parsed;
    _before = segments;
    shifted = wasShifted;
    askedPlaces = asked;
    tailPlaces = tail;
    codes = next;
  }

  static _Parsed _fencesIn(
    String segment,
    MarkdownBlockRegistry? registry,
    MarkdownHtml html,
    MarkdownDefinitions definitions,
  ) {
    final out = <String>[];
    final lookups = <String>{};
    try {
      _collect(
        Plusparse.parse(
          segment,
          blockRegistry: registry,
          html: html,
          definitions: definitions.recording(lookups),
        ).children,
        out,
      );
    } on Object {
      // A segment the parser rejects has no places; its blocks are judged in
      // the order they are asked about.
    }
    return _Parsed(out, lookups);
  }

  static void _collect(List<MdNode> nodes, List<String> out) {
    for (final node in nodes) {
      switch (node) {
        case MdCodeBlock(:final code):
          out.add(code);
        case MdBlockQuote(:final children, :final alert):
          // An alert's body is in `children` too: collect it once.
          _collect(alert?.children ?? children, out);
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
