import 'package:flutter/material.dart';

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

  static const _windows = {
    UsageChartWindow.days7: '7 days',
    UsageChartWindow.days30: '30 days',
    UsageChartWindow.days90: '90 days',
  };
  static const _metrics = {
    UsageChartMetric.tokens: 'Tokens',
    UsageChartMetric.cost: 'Estimated cost',
  };

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      if (box.maxWidth >= 600) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: PillSegmentedControl<UsageChartWindow>(
                  value: window,
                  segments: _windows,
                  onChanged: onWindow,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PillSegmentedControl<UsageChartMetric>(
                  value: metric,
                  segments: _metrics,
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
            segments: _windows,
            onChanged: onWindow,
          ),
          GroupedSegmentedRow<UsageChartMetric>(
            value: metric,
            segments: _metrics,
            onChanged: onMetric,
          ),
        ],
      );
    },
  );
}
