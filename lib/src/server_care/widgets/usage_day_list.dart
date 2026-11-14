import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../widgets/grouped_list.dart';
import 'usage_format.dart';

/// One day of the table: the chart's alternative for people who cannot, or
/// would rather not, read bars.
class UsageDayEntry {
  const UsageDayEntry({
    required this.day,
    required this.tokens,
    required this.cost,
    required this.conversations,
  });

  final DateTime day;
  final int tokens;
  final double cost;
  final int conversations;
}

const _firstDays = 10;
const _moreDays = 20;

/// "By day", newest first: the first ten days, then a row that shows twenty
/// more each time it is pressed.
class UsageDayList extends StatefulWidget {
  const UsageDayList({super.key, required this.days});

  /// In any order; shown newest first.
  final List<UsageDayEntry> days;

  @override
  State<UsageDayList> createState() => _UsageDayListState();
}

class _UsageDayListState extends State<UsageDayList> {
  int _shown = _firstDays;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sorted = [...widget.days]..sort((a, b) => b.day.compareTo(a.day));
    final visible = sorted.take(_shown).toList();
    final remaining = sorted.length - visible.length;
    final next = remaining < _moreDays ? remaining : _moreDays;
    return GroupedSection(
      header: l10n.serverCareUsageByDay,
      children: [
        for (final d in visible)
          GroupedRow(
            title: formatDayShort(l10n, d.day),
            subtitle:
                '${formatTokens(l10n, d.tokens)} · ${formatDollars(l10n, d.cost)} · '
                '${formatConversations(l10n, d.conversations)}',
            subtitleMaxLines: null,
          ),
        if (remaining > 0)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
              onPressed: () => setState(() => _shown += _moreDays),
              child: Text(l10n.serverCareUsageShowMoreDays(next)),
            ),
          ),
      ],
    );
  }
}
