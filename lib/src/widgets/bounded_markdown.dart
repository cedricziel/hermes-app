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

/// Which code blocks of one markdown document are coloured, decided from the
/// text alone, in document order.
///
/// The highlighter (`val_highlight`) is quadratic on some inputs and gives
/// every token its own text run, and a run costs about 20 us of layout and
/// paint: one block of 20 000 spaces took ~6 s, 100 000 characters of `1+` ~16 s
/// and 50 blocks of a few thousand runs each ~17 s, all on the UI isolate. So a
/// block is coloured only when no line is over [maxLine], the block is at most
/// [maxBlock] characters, and the coloured blocks before it plus this one stay
/// within [maxDocument] (greedy, in document order).
///
/// The order in which `GptMarkdown` calls its `codeBuilder` says nothing about
/// the document order: it keeps the segments it rendered and draws arbitrary
/// subsets of them again (a changed segment, the end of a held reply released
/// by a timer, a dependency change). So the decision is made once per text, by
/// parsing it with the package's own public parser (`Plusparse.parse`, no
/// `BuildContext`), and the builder only looks its block up by its code. A
/// block the plan does not know is plain.
///
/// Identical copies that straddle the limit stay plain. The builder cannot
/// tell which copy of a code string it is drawing (the package may draw one
/// copy alone), so copies of one code share one decision. When the greedy rule
/// would colour some copies of a code and refuse others, every copy of it is
/// refused, and the room the coloured copies would have taken goes to later
/// blocks (the pass is run again until no group is split). Identical copies that
/// all fit stay coloured.
///
/// Where the plan can disagree with what the renderer draws, it fails safe
/// (the block stays plain; a block is never coloured because of a mismatch):
///
/// * The renderer parses the document segment by segment and the plan parses
///   it whole, so a block whose code differs between the two (a list split at
///   a blank line, a definition that a segment resolves differently) is not
///   found and stays plain.
/// * The text is prepared as the package prepares it: CRLF and lone CR become
///   LF, the text is trimmed, a lone surrogate becomes U+FFFD (one at the very
///   end is dropped). A change in that preparation makes blocks mismatch.
/// * An unclosed fence at the end of a streaming reply is a block like any
///   other, with the code so far. The renderer holds back the last characters
///   of a stream, so it may draw a start of that code: a start of the tail is
///   judged on its own text, after the characters coloured before the tail,
///   unless the tail belongs to a group of identical copies that stays plain.
/// * Blocks the parser does not report as code nodes (inside raw HTML such as
///   `<details>`, in a table cell) are not in the plan.
class CodeColourPlan {
  CodeColourPlan._(
    this._admitted,
    this._tail,
    this._tailUsedBefore,
    this._maxLine,
    this._maxBlock,
    this._maxDocument,
  );

  /// The plan for [markdown], as `GptMarkdown` would read it.
  factory CodeColourPlan.scan(
    String markdown, {
    int maxLine = kHighlightMaxLine,
    int maxBlock = kHighlightMaxBlock,
    int maxDocument = kHighlightMaxDocument,
  }) {
    final blocks = _codeBlocks(markdown).toList();
    var refused = <String>{};
    // While a stream's end is held back, the open block at the end is drawn
    // with a start of its code that can equal an earlier block's code: one
    // more copy of it. Groups that straddle the limit with that copy are
    // refused as well, so the plan holds in both states.
    if (blocks.isNotEmpty && !blocks.last.$2) {
      final tail = blocks.last.$1;
      for (final (code, _) in blocks.take(blocks.length - 1)) {
        if (code.isNotEmpty &&
            code != tail &&
            tail.startsWith(code) &&
            tail.length - code.length <= _heldMax) {
          final held = [...blocks.take(blocks.length - 1), (code, false)];
          refused = _settle(held, refused, maxLine, maxBlock, maxDocument).$4;
          // The tail drawn in full is a copy of the group as well.
          if (refused.contains(code)) refused = {...refused, tail};
        }
      }
    }
    final (admitted, tail, tailUsed, _) = _settle(
      blocks,
      refused,
      maxLine,
      maxBlock,
      maxDocument,
    );
    return CodeColourPlan._(
      admitted,
      tail,
      tailUsed,
      maxLine,
      maxBlock,
      maxDocument,
    );
  }

  /// The most characters the renderer holds back at the end of a stream: a
  /// lone line of up to three backticks.
  static const _heldMax = 3;

  /// Runs the greedy rule over [blocks] until no group of identical copies is
  /// split, starting with the codes in [refused]: each group the rule splits
  /// is refused as a whole, so its room goes to the blocks after it. The set
  /// only grows, so the passes end. Returns what each code is decided, the
  /// open block at the end (null unless it is coloured-eligible), the
  /// characters coloured before it, and the refused codes.
  static (Map<String, bool>, String?, int, Set<String>) _settle(
    List<(String, bool)> blocks,
    Set<String> refused,
    int maxLine,
    int maxBlock,
    int maxDocument,
  ) {
    refused = {...refused};
    while (true) {
      final admitted = <String, bool>{};
      final split = <String>{};
      var used = 0;
      String? tail;
      var tailUsed = 0;
      for (final (code, closed) in blocks) {
        final ok =
            !refused.contains(code) &&
            _fits(code, used, maxLine, maxBlock, maxDocument);
        tail = closed || refused.contains(code) ? null : code;
        tailUsed = used;
        if (ok) used += code.length;
        final before = admitted[code];
        if (before != null && before != ok) split.add(code);
        admitted[code] = (before ?? ok) && ok;
      }
      if (split.isEmpty) return (admitted, tail, tailUsed, refused);
      refused.addAll(split);
    }
  }

  /// Whether the copies of each code are coloured.
  final Map<String, bool> _admitted;

  /// The code of the unclosed block the document ends in, and the characters
  /// coloured before it.
  final String? _tail;
  final int _tailUsedBefore;
  final int _maxLine;
  final int _maxBlock;
  final int _maxDocument;

  /// Whether a block with body [code] may be coloured. False for a block the
  /// plan does not know, except for the start of the unclosed block the
  /// document ends in (see the class comment).
  bool admits(String code) {
    final key = _key(code);
    final known = _admitted[key];
    if (known != null) return known;
    final tail = _tail;
    if (tail != null && tail.startsWith(key)) {
      return _fits(key, _tailUsedBefore, _maxLine, _maxBlock, _maxDocument);
    }
    return false;
  }

  /// A code string as both sides compare it: line ends as LF.
  static String _key(String code) => code.contains('\r')
      ? code.replaceAll('\r\n', '\n').replaceAll('\r', '\n')
      : code;

  static bool _fits(
    String code,
    int usedBefore,
    int maxLine,
    int maxBlock,
    int maxDocument,
  ) {
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

  /// The code of every block the parser reports, in document order.
  static Iterable<(String, bool)> _codeBlocks(String markdown) sync* {
    for (final node in Plusparse.parse(_prepare(markdown)).children) {
      yield* _inside(node);
    }
  }

  static Iterable<(String, bool)> _inside(MdNode node) sync* {
    switch (node) {
      case MdCodeBlock(:final code, :final closed):
        yield (_key(code), closed);
      case MdBlockQuote(:final children):
        for (final child in children) {
          yield* _inside(child);
        }
      case MdUnorderedList(:final items) || MdOrderedList(:final items):
        for (final item in items) {
          for (final child in item.children) {
            yield* _inside(child);
          }
        }
      case MdFootnoteDefinitions(:final footnotes):
        for (final note in footnotes) {
          for (final child in note.children) {
            yield* _inside(child);
          }
        }
      default:
        break;
    }
  }

  /// The source as `GptMarkdown` prepares it before parsing.
  static String _prepare(String source) {
    final text =
        (source.contains('\r')
                ? source.replaceAll('\r\n', '\n').replaceAll('\r', '\n')
                : source)
            .trim();
    StringBuffer? out;
    var copied = 0;
    final n = text.length;
    for (var i = 0; i < n; i++) {
      final c = text.codeUnitAt(i);
      if (c < 0xD800 || c > 0xDFFF) continue;
      final high = c <= 0xDBFF;
      if (high && i + 1 < n) {
        final next = text.codeUnitAt(i + 1);
        if (next >= 0xDC00 && next <= 0xDFFF) {
          i++;
          continue;
        }
      }
      out ??= StringBuffer();
      out.write(text.substring(copied, i));
      if (!(high && i == n - 1)) out.write('�');
      copied = i + 1;
    }
    if (out == null) return text;
    out.write(text.substring(copied));
    return out.toString();
  }
}

/// `GptMarkdown` whose fenced code blocks stay within a render budget (see
/// [CodeColourPlan]): a block over it is drawn as plain monospace text in
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
    @visibleForTesting this.debugPlanFor,
  });

  final String data;
  final TextStyle? style;
  final void Function(String url, String title)? onLinkTap;
  // ignore: deprecated_member_use
  final LinkBuilder? linkBuilder;
  final CheckboxBuilder? checkboxBuilder;
  final RadioOptionBuilder? radioOptionBuilder;

  /// Replaces the scan, so a test can hand the renderer blocks the plan does
  /// not know.
  final CodeColourPlan Function(String data)? debugPlanFor;

  @override
  State<BoundedMarkdown> createState() => _BoundedMarkdownState();
}

class _BoundedMarkdownState extends State<BoundedMarkdown> {
  /// The plan for [_planFor], made when a block first asks, once per text.
  CodeColourPlan? _plan;
  String? _planFor;

  bool _admit(String code) {
    if (_planFor != widget.data) {
      _plan = (widget.debugPlanFor ?? CodeColourPlan.scan)(widget.data);
      _planFor = widget.data;
    }
    return _plan!.admits(code);
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
