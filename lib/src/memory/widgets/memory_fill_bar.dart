import 'package:flutter/material.dart';

import '../../theme/hermes_theme.dart';
import '../../widgets/grouped_list.dart';
import '../memory_usage.dart';

/// How full one memory file is: the entry count, "912 of 1,375 characters"
/// and a thin bar, which takes the warning style once Hermes has to shorten
/// entries before it can add one.
class MemoryFillBar extends StatelessWidget {
  const MemoryFillBar({super.key, required this.usage});

  final MemoryUsage usage;

  @override
  Widget build(BuildContext context) {
    final metrics = GroupedMetrics.of(context);
    final scheme = Theme.of(context).colorScheme;
    final colors = context.hermesColors;
    final style = TextStyle(
      fontSize: metrics.subtitleSize,
      color: colors.subtleText,
    );
    final fraction = usage.fraction;
    final warn = usage.nearlyFull;
    final count = usage.entries == 1 ? '1 entry' : '${usage.entries} entries';
    final used = groupThousands(usage.used);
    final prefix = usage.lowerBound ? 'at least ' : '';
    final amount = usage.limit == null
        ? '$prefix$used characters'
        : '$prefix$used of ${groupThousands(usage.limit!)} characters';
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: metrics.rowPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(count, style: style),
              const SizedBox(width: 12),
              Expanded(
                child: Text(amount, textAlign: TextAlign.end, style: style),
              ),
            ],
          ),
          if (fraction != null) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: fraction.toDouble(),
                minHeight: 4,
                color: warn ? colors.warning : scheme.primary,
                backgroundColor: scheme.outlineVariant,
              ),
            ),
          ],
          if (warn) ...[
            const SizedBox(height: 8),
            Text(
              'Full',
              style: TextStyle(
                fontSize: metrics.subtitleSize,
                fontWeight: FontWeight.w600,
                color: colors.warning,
              ),
            ),
            Text(
              'Hermes has to shorten or remove entries before it can add one. '
              'Remove what you no longer need to make room.',
              style: TextStyle(
                fontSize: metrics.subtitleSize,
                color: colors.warning,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
