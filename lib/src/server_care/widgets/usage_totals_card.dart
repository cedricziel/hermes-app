import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
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
    final l10n = context.l10n;
    final big = cost
        ? l10n.serverCareUsageEstimatedAmount(
            formatDollars(l10n, estimatedCost),
          )
        : formatTokens(l10n, tokens);
    final bigSpoken = cost
        ? l10n.serverCareUsageEstimatedAmount(
            formatDollars(l10n, estimatedCost),
          )
        : formatTokensSpoken(l10n, tokens);
    final days = window.days;
    final conversationsText = formatConversations(l10n, conversations);
    final period =
        '${l10n.serverCareUsagePeriodLast(days)} · $conversationsText';
    final parts = l10n.serverCareUsagePartsText(
      formatCompact(l10n, inputTokens),
      formatCompact(l10n, outputTokens),
      formatCompact(l10n, cacheReadTokens),
    );
    final partsSpoken = l10n.serverCareUsagePartsSpoken(
      formatCompactSpoken(l10n, inputTokens),
      formatCompactSpoken(l10n, outputTokens),
      formatCompactSpoken(l10n, cacheReadTokens),
    );
    final billed = cost && (billedCost ?? 0) > 0
        ? l10n.serverCareUsageBilled(formatDollars(l10n, billedCost!))
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
          '${l10n.serverCareUsagePeriodLast(days)}, $conversationsText',
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
