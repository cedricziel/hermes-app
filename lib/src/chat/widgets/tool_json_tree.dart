import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../files/code_highlight.dart' show CodeToken, codeTokenStyle;
import '../../files/widgets/files_metrics.dart';
import '../../theme/app_icons.dart';
import '../../theme/focus_ring.dart';
import '../../theme/hermes_code_colors.dart';
import '../../theme/hermes_theme.dart';
import '../../files/widgets/safe_path_text.dart' show wellFormedText;
import '../json_tree_parser.dart';
import '../tool_value_language.dart'
    show kToolJsonTreeMaxDepth, kToolJsonTreeMaxNodes;
import 'tool_hidden_chars.dart';
import 'tool_value_view.dart' show ToolValueView, kToolMonoStyle;

const TextStyle _mono = kToolMonoStyle;

/// The collapsible JSON tree of a tool call: an object or array already
/// decoded ([value], within the depth the tree is offered for). Rows are
/// built lazily and cannot be selected; the text view is for that, and the
/// Copy button copies the text as sent.
///
/// Colours are the code palette's through [codeTokenStyle]: keys in the key
/// colour, strings, numbers and `true`, `false`, `null` as in the text view.
/// A hidden character in a key or a string is a boxed escape, and a line
/// break inside a string a boxed `\n`, so a row stays one row.
class ToolJsonTree extends StatefulWidget {
  const ToolJsonTree({super.key, required this.text, this.nodes});

  /// The JSON text. The tree parses it itself within [kToolJsonTreeMaxDepth]
  /// levels and [kToolJsonTreeMaxNodes] nodes, whoever asks for it, and shows
  /// the text flat when it is invalid or over either cap.
  final String text;

  /// [text] already parsed by the caller (`toolValueShape`), so it is not
  /// parsed twice.
  final List<JsonTreeNode>? nodes;

  /// How deep the tree starts open: the root and its entries.
  static const int initiallyOpenDepth = 1;

  @override
  State<ToolJsonTree> createState() => _ToolJsonTreeState();
}

class _ToolJsonTreeState extends State<ToolJsonTree> {
  List<JsonTreeNode>? _nodes;
  final Set<int> _closed = {};
  late List<int> _visible;

  /// The place of each node in the array that holds it, -1 elsewhere.
  List<int> _position = const [];

  /// Whether the root has its own row: only an empty one does; otherwise the
  /// tree starts at its entries.
  bool get _rootRow => (_nodes?.first.count ?? 0) == 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _nodes =
        widget.nodes ??
        parseJsonTree(
          widget.text,
          maxDepth: kToolJsonTreeMaxDepth,
          maxNodes: kToolJsonTreeMaxNodes,
        ).nodes;
    _closeDeep();
  }

  void _closeDeep() {
    _closed.clear();
    final nodes = _nodes ?? const <JsonTreeNode>[];
    _position = List.filled(nodes.length, -1);
    // Open: the root, depth 1 and the first container at depth 2.
    var firstDeepOpen = false;
    final counters = <int, int>{};
    final ends = <(int, int)>[];
    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      while (ends.isNotEmpty && ends.last.$1 <= i) {
        ends.removeLast();
      }
      if (ends.isNotEmpty && nodes[ends.last.$2].kind == JsonTreeKind.array) {
        _position[i] = counters[ends.last.$2] =
            (counters[ends.last.$2] ?? -1) + 1;
      }
      if (node.isContainer) ends.add((node.end, i));
      if (node.isContainer &&
          node.count > 0 &&
          node.depth > ToolJsonTree.initiallyOpenDepth) {
        if (node.depth == ToolJsonTree.initiallyOpenDepth + 1 &&
            !firstDeepOpen) {
          firstDeepOpen = true;
        } else {
          _closed.add(i);
        }
      }
    }
    _visible = _computeVisible();
  }

  @override
  void didUpdateWidget(ToolJsonTree oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        !identical(oldWidget.nodes, widget.nodes)) {
      _load();
    }
  }

  List<int> _computeVisible() {
    final visible = <int>[];
    final nodes = _nodes ?? const <JsonTreeNode>[];
    var i = _rootRow || nodes.isEmpty ? 0 : 1;
    while (i < nodes.length) {
      visible.add(i);
      i = _closed.contains(i) ? nodes[i].end : i + 1;
    }
    return visible;
  }

  void _toggle(int index) {
    setState(() {
      if (!_closed.remove(index)) _closed.add(index);
      _visible = _computeVisible();
    });
  }

  @override
  Widget build(BuildContext context) {
    final nodes = _nodes;
    if (nodes == null) {
      return ToolValueView(text: widget.text, language: 'json');
    }
    return _list(nodes);
  }

  Widget _list(List<JsonTreeNode> nodes) => SelectionContainer.disabled(
    child: ListView.builder(
      key: const ValueKey('tool-json-tree'),
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: _visible.length,
      itemBuilder: (context, row) {
        final index = _visible[row];
        return _TreeRow(
          node: nodes[index],
          position: _position[index],
          rootless: !_rootRow,
          open: !_closed.contains(index),
          onToggle: () => _toggle(index),
        );
      },
    ),
  );
}

class _TreeRow extends StatelessWidget {
  const _TreeRow({
    required this.node,
    required this.position,
    required this.rootless,
    required this.open,
    required this.onToggle,
  });

  final JsonTreeNode node;

  /// The index of an array item, -1 for anything else.
  final int position;

  /// Whether the root has no row, so every row sits one level up.
  final bool rootless;
  final bool open;
  final VoidCallback onToggle;

  static const double _indent = 14;
  static const int _indentSteps = 12;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final palette = context.codeColors;
    final subtle = context.hermesColors.subtleText;
    final base = _mono.copyWith(color: scheme.onSurface);
    final keyStyle = base.merge(codeTokenStyle(CodeToken.key, palette));
    final punctuation = base.merge(
      codeTokenStyle(CodeToken.punctuation, palette),
    );
    final budget = HiddenBoxBudget();

    List<InlineSpan> text(String s, TextStyle style) => hiddenCharSpans(
      context,
      wellFormedText(s),
      style,
      budget,
      boxStyle: base,
      boxLineBreaks: true,
    );

    final spans = <InlineSpan>[];
    final key = node.key;
    final container = node.isContainer;
    // A container's count follows its key or index after a 4 pt gap; any
    // other value follows a colon (a key) or a wider gap (an index).
    final gap = WidgetSpan(child: SizedBox(width: container ? 4 : 8));
    if (key != null) {
      spans
        ..addAll(text(key, keyStyle))
        ..add(TextSpan(text: container ? ':' : ': ', style: punctuation));
      if (container) spans.add(gap);
    } else if (position >= 0) {
      // An array item shows its index, with no colon.
      spans
        ..add(
          TextSpan(
            text: '$position',
            style: base.copyWith(color: subtle),
          ),
        )
        ..add(gap);
    }
    switch (node.kind) {
      case JsonTreeKind.object || JsonTreeKind.array:
        final isObject = node.kind == JsonTreeKind.object;
        final summary = isObject
            ? l10n.chatWidgetsToolValueKeys(node.count)
            : l10n.chatWidgetsToolValueItems(node.count);
        // Plain muted sans text, not code: no braces.
        spans.add(
          TextSpan(
            text: summary,
            // The UI font, not the code font the row inherits.
            style: TextStyle(
              inherit: false,
              fontSize: 11.5,
              color: subtle,
              fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
              fontFamilyFallback: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.fontFamilyFallback,
            ),
          ),
        );
      case JsonTreeKind.string:
        final style = base.merge(codeTokenStyle(CodeToken.string, palette));
        spans
          ..add(TextSpan(text: '"', style: style))
          ..addAll(text(node.text, style))
          ..add(TextSpan(text: '"', style: style));
      case JsonTreeKind.number:
        // As written: 1.50, 1e3 and a 20-digit id stay exactly so.
        spans.add(
          TextSpan(
            text: node.text,
            style: base.merge(codeTokenStyle(CodeToken.number, palette)),
          ),
        );
      case JsonTreeKind.literal:
        spans.add(
          TextSpan(
            text: node.text,
            style: base.merge(codeTokenStyle(CodeToken.literal, palette)),
          ),
        );
    }

    final level = (rootless ? node.depth - 1 : node.depth).clamp(
      0,
      _indentSteps,
    );
    final indent = level * _indent;
    final content = CustomPaint(
      painter: _GuidePainter(
        levels: level,
        step: _indent,
        color: scheme.outline,
        rtl: Directionality.of(context) == TextDirection.rtl,
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.only(start: indent),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: node.isContainer && node.count > 0
                  ? AppIcon(
                      open ? AppIcons.dropDown : AppIcons.dropRight,
                      size: 18,
                      color: subtle,
                    )
                  : null,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Text.rich(TextSpan(children: spans), style: base),
              ),
            ),
          ],
        ),
      ),
    );
    if (!node.isContainer || node.count == 0) return content;
    final target = FilesMetrics.of(context).target;
    // One node per row: its text is the label, and the only tap is the
    // Semantics one (the InkWell adds none of its own).
    return Semantics(
      button: true,
      expanded: open,
      onTap: onToggle,
      child: FocusRing(
        radius: 0,
        child: InkWell(
          excludeFromSemantics: true,
          onTap: onToggle,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: target),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

/// One thin vertical line per level of nesting, at the start of each level's
/// indent, so a deep row can be followed back to its parent.
class _GuidePainter extends CustomPainter {
  const _GuidePainter({
    required this.levels,
    required this.step,
    required this.color,
    required this.rtl,
  });

  final int levels;
  final double step;
  final Color color;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var i = 0; i < levels; i++) {
      final x = i * step + 10;
      final dx = rtl ? size.width - x : x;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_GuidePainter old) =>
      old.levels != levels || old.color != color || old.rtl != rtl;
}
