import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../files/code_highlight.dart' show CodeToken, codeTokenStyle;
import '../../files/widgets/files_metrics.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_code_colors.dart';
import '../../theme/hermes_theme.dart';
import 'tool_hidden_chars.dart';

/// [text] with each lone surrogate (JSON can carry one as `\ud800`, and it
/// makes painting throw) replaced by U+FFFD. Display only.
String wellFormedToolText(String text) {
  StringBuffer? out;
  for (var i = 0; i < text.length; i++) {
    final unit = text.codeUnitAt(i);
    final high = unit >= 0xD800 && unit <= 0xDBFF;
    final low = unit >= 0xDC00 && unit <= 0xDFFF;
    final paired =
        high &&
        i + 1 < text.length &&
        (text.codeUnitAt(i + 1) & 0xFC00) == 0xDC00;
    if (paired) {
      out?.write(text.substring(i, i + 2));
      i++;
    } else if (high || low) {
      out ??= StringBuffer(text.substring(0, i));
      out.write('�');
    } else {
      out?.writeCharCode(unit);
    }
  }
  return out?.toString() ?? text;
}

const TextStyle _mono = TextStyle(
  fontFamily: 'monospace',
  fontSize: 12,
  height: 1.4,
);

/// One entry of the flattened tree, in document order.
class _Node {
  _Node({
    required this.depth,
    required this.key,
    required this.value,
    required this.count,
  });

  final int depth;
  final String? key;
  final Object? value;

  /// The number of entries of an object or array, -1 for a scalar.
  final int count;

  /// The index after the last descendant: where a collapsed node's next
  /// sibling (or the next entry of its parent) is.
  int end = 0;

  bool get isContainer => count >= 0;
}

List<_Node> _flatten(Object? root) {
  final nodes = <_Node>[];
  void walk(String? key, Object? value, int depth) {
    final count = switch (value) {
      Map() => value.length,
      List() => value.length,
      _ => -1,
    };
    final node = _Node(depth: depth, key: key, value: value, count: count);
    nodes.add(node);
    switch (value) {
      case Map():
        for (final entry in value.entries) {
          walk('${entry.key}', entry.value, depth + 1);
        }
      case List():
        for (final item in value) {
          walk(null, item, depth + 1);
        }
    }
    node.end = nodes.length;
  }

  walk(null, root, 0);
  return nodes;
}

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
  const ToolJsonTree({super.key, required this.value});

  final Object? value;

  /// How deep the tree starts open: the root and its entries.
  static const int initiallyOpenDepth = 1;

  @override
  State<ToolJsonTree> createState() => _ToolJsonTreeState();
}

class _ToolJsonTreeState extends State<ToolJsonTree> {
  late List<_Node> _nodes;
  final Set<int> _closed = {};
  late List<int> _visible;

  @override
  void initState() {
    super.initState();
    _nodes = _flatten(widget.value);
    _closeDeep();
  }

  void _closeDeep() {
    _closed.clear();
    for (var i = 0; i < _nodes.length; i++) {
      final node = _nodes[i];
      if (node.isContainer &&
          node.count > 0 &&
          node.depth > ToolJsonTree.initiallyOpenDepth) {
        _closed.add(i);
      }
    }
    _visible = _computeVisible();
  }

  @override
  void didUpdateWidget(ToolJsonTree oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.value, widget.value)) {
      _nodes = _flatten(widget.value);
      _closeDeep();
    }
  }

  List<int> _computeVisible() {
    final visible = <int>[];
    var i = 0;
    while (i < _nodes.length) {
      visible.add(i);
      i = _closed.contains(i) ? _nodes[i].end : i + 1;
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
  Widget build(BuildContext context) => SelectionContainer.disabled(
    child: ListView.builder(
      key: const ValueKey('tool-json-tree'),
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: _visible.length,
      itemBuilder: (context, row) {
        final index = _visible[row];
        return _TreeRow(
          node: _nodes[index],
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
    required this.open,
    required this.onToggle,
  });

  final _Node node;
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
      wellFormedToolText(s),
      style,
      budget,
      boxStyle: base,
      boxLineBreaks: true,
    );

    final spans = <InlineSpan>[];
    final key = node.key;
    if (key != null) {
      spans
        ..addAll(text(key, keyStyle))
        ..add(TextSpan(text: ': ', style: punctuation));
    }
    final value = node.value;
    if (node.isContainer) {
      final summary = value is Map
          ? l10n.chatWidgetsToolValueKeys(node.count)
          : l10n.chatWidgetsToolValueItems(node.count);
      spans.add(
        TextSpan(
          text: value is Map ? '{ $summary }' : '[ $summary ]',
          style: base.copyWith(color: subtle),
        ),
      );
    } else if (value is String) {
      final style = base.merge(codeTokenStyle(CodeToken.string, palette));
      spans
        ..add(TextSpan(text: '"', style: style))
        ..addAll(text(value, style))
        ..add(TextSpan(text: '"', style: style));
    } else if (value is num) {
      spans.add(
        TextSpan(
          text: '$value',
          style: base.merge(codeTokenStyle(CodeToken.number, palette)),
        ),
      );
    } else {
      spans.add(
        TextSpan(
          text: '$value',
          style: base.merge(codeTokenStyle(CodeToken.literal, palette)),
        ),
      );
    }

    final indent = node.depth.clamp(0, _indentSteps) * _indent;
    final content = Padding(
      padding: EdgeInsets.only(left: indent),
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
    );
    if (!node.isContainer || node.count == 0) return content;
    final target = FilesMetrics.of(context).target;
    return Semantics(
      button: true,
      expanded: open,
      onTap: onToggle,
      child: InkWell(
        onTap: onToggle,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: target),
          child: Align(alignment: Alignment.centerLeft, child: content),
        ),
      ),
    );
  }
}
