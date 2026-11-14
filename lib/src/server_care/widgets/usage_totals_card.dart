import 'package:flutter/material.dart';

import '../../theme/hermes_theme.dart';
import '../../widgets/grouped_list.dart';
import 'usage_chart.dart';
import 'usage_format.dart';

/// The numbers over the chart: the window's total in the chosen metric, what
/// it covers, and the parts it is made of.
class UsageTotalsCard extends StatelessWidget {
  const UsageTotalsCard({
    super.key,
    required this.metric,
    required this.window,
    required this.tokens,
    required this.estimatedCost,
    required this.conversations,
    required this.inputTokens,
    required this.outputTokens,
    required this.cacheReadTokens,
    this.billedCost,
  });

  final UsageChartMetric metric;
  final UsageChartWindow window;
  final int tokens;
  final double estimatedCost;
  final int conversations;
  final int inputTokens;
  final int outputTokens;
  final int cacheReadTokens;

  /// What the provider billed, when Hermes reports it; shown with the cost.
  final double? billedCost;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = context.hermesColors.subtleText;
    final metrics = GroupedMetrics.of(context);
    final cost = metric == UsageChartMetric.cost;
    final big = cost
        ? '${formatDollars(estimatedCost)} estimated'
        : formatTokens(tokens);
    final bigSpoken = cost
        ? '${formatDollars(estimatedCost)} estimated'
        : formatTokensSpoken(tokens);
    final window = this.window.phrase;
    final period =
        '${window[0].toUpperCase()}${window.substring(1)} · ${formatConversations(conversations)}';
    final parts =
        'Input ${formatCompact(inputTokens)} · Output ${formatCompact(outputTokens)} · '
        'Cache reads ${formatCompact(cacheReadTokens)}';
    final partsSpoken =
        'Input ${formatCompactSpoken(inputTokens)}, output ${formatCompactSpoken(outputTokens)}, '
        'cache reads ${formatCompactSpoken(cacheReadTokens)}';
    final billed = cost && (billedCost ?? 0) > 0
        ? 'Billed ${formatDollars(billedCost!)}'
        : null;
    final small = TextStyle(fontSize: metrics.subtitleSize, color: muted);

    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(metrics.radius),
        side: BorderSide(color: scheme.outline),
      ),
      child: Semantics(
        container: true,
        label: [
          bigSpoken,
          period.replaceFirst(' · ', ', '),
          partsSpoken,
          ?billed,
        ].join('. '),
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  big,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  period,
                  style: TextStyle(
                    fontSize: metrics.titleSize,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(parts, style: small),
                if (billed != null) ...[
                  const SizedBox(height: 2),
                  Text(billed, style: small),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
