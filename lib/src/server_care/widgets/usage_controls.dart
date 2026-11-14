import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../widgets/adaptive_tab_bar.dart';
import '../../widgets/grouped_form.dart';
import '../../widgets/grouped_list.dart';
import 'usage_chart.dart';

/// The Usage page's window and metric switches: stacked grouped rows on a
/// phone, side by side as pills from 600 pt up.
class UsageControls extends StatelessWidget {
  const UsageControls({
    super.key,
    required this.window,
    required this.metric,
    required this.onWindow,
    required this.onMetric,
  });

  final UsageChartWindow window;
  final UsageChartMetric metric;
  final ValueChanged<UsageChartWindow> onWindow;
  final ValueChanged<UsageChartMetric> onMetric;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final windows = {
      for (final w in UsageChartWindow.values)
        w: l10n.serverCareUsageWindowDays(w.days),
    };
    final metrics = {
      UsageChartMetric.tokens: l10n.serverCareUsageMetricTokens,
      UsageChartMetric.cost: l10n.serverCareUsageMetricCost,
    };
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth >= 600) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: PillSegmentedControl<UsageChartWindow>(
                    value: window,
                    segments: windows,
                    onChanged: onWindow,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PillSegmentedControl<UsageChartMetric>(
                    value: metric,
                    segments: metrics,
                    onChanged: onMetric,
                  ),
                ),
              ],
            ),
          );
        }
        return GroupedSection(
          children: [
            GroupedSegmentedRow<UsageChartWindow>(
              value: window,
              segments: windows,
              onChanged: onWindow,
            ),
            GroupedSegmentedRow<UsageChartMetric>(
              value: metric,
              segments: metrics,
              onChanged: onMetric,
            ),
          ],
        );
      },
    );
  }
}
