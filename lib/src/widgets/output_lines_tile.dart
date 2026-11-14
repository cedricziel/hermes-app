import 'package:flutter/material.dart';

import 'disclosure_tile.dart';
import 'grouped_list.dart';

/// A disclosure row that opens lines of command output, in monospace and
/// selectable, in a tinted box. Closed unless [initiallyOpen]. The caller
/// words the [label].
class OutputLinesTile extends StatelessWidget {
  const OutputLinesTile({
    super.key,
    required this.label,
    required this.lines,
    this.initiallyOpen = false,
  });

  final String label;
  final List<String> lines;
  final bool initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final metrics = GroupedMetrics.of(context);
    final scheme = Theme.of(context).colorScheme;
    return DisclosureTile(
      initiallyExpanded: initiallyOpen,
      shape: const Border(),
      collapsedShape: const Border(),
      minTileHeight: metrics.rowMinHeight,
      tilePadding: EdgeInsets.symmetric(horizontal: metrics.rowPadding),
      childrenPadding: EdgeInsets.fromLTRB(
        metrics.rowPadding,
        0,
        metrics.rowPadding,
        metrics.rowPadding,
      ),
      title: Text(label, style: TextStyle(fontSize: metrics.titleSize)),
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: SizedBox(
              width: double.infinity,
              child: SelectableText(
                lines.join('\n'),
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: metrics.footerSize,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
