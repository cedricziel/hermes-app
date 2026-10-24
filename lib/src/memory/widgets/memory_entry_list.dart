import 'package:flutter/material.dart';

import '../../theme/hermes_theme.dart';
import '../../widgets/grouped_list.dart';
import '../memory_usage.dart';
import 'memory_fill_bar.dart';

/// One memory file as a list: what Hermes does with it, how full it is, and
/// its entries by their text alone, since Hermes keeps no date, author or
/// chat for an entry.
class MemoryEntryList extends StatelessWidget {
  const MemoryEntryList({
    super.key,
    required this.usage,
    required this.entries,
    required this.onOpen,
    required this.onRefresh,
    this.header = const [],
    this.footer = const [],
  });

  final MemoryUsage usage;
  final List<String> entries;
  final ValueChanged<int> onOpen;
  final VoidCallback onRefresh;

  /// What comes first: a card that needs the user's attention.
  final List<Widget> header;

  /// What follows the entries: the profile's settings.
  final List<Widget> footer;

  @override
  Widget build(BuildContext context) {
    final metrics = GroupedMetrics.of(context);
    final muted = context.hermesColors.subtleText;
    final textStyle = TextStyle(fontSize: metrics.subtitleSize, color: muted);
    return GroupedListView(
      children: [
        ...header,
        Padding(
          padding: EdgeInsets.fromLTRB(
            metrics.rowPadding,
            12,
            metrics.rowPadding,
            12,
          ),
          child: Text(
            'Hermes reads these notes at the start of every new chat. It adds '
            'to them as it learns, and you can change or remove anything.',
            style: textStyle,
          ),
        ),
        MemoryFillBar(usage: usage),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
            child: Column(
              children: [
                Text(
                  'Nothing remembered yet',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'As you chat, Hermes notes your preferences here. You can '
                  'also just tell it: “Remember that I prefer metric units.”',
                  textAlign: TextAlign.center,
                  style: textStyle,
                ),
              ],
            ),
          )
        else
          GroupedSection(
            children: [
              for (final (i, text) in entries.indexed)
                GroupedRow(
                  title: text,
                  titleMaxLines: 3,
                  onTap: () => onOpen(i),
                ),
            ],
          ),
        GroupedSection(
          children: [GroupedRow(title: 'Refresh', onTap: onRefresh)],
        ),
        ...footer,
      ],
    );
  }
}
