import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/hermes_theme.dart';
import '../../widgets/grouped_list.dart';
import 'usage_format.dart';

class UsageModelEntry {
  const UsageModelEntry({
    required this.model,
    required this.tokens,
    required this.cost,
    required this.conversations,
    required this.share,
  });

  /// As Hermes reports it.
  final String model;
  final int tokens;
  final double cost;
  final int conversations;

  /// Its part of the window's tokens, 0 to 1.
  final double share;
}

/// "By model": rows in the order given (the page sorts by tokens), each with
/// a share and a thin proportion bar that only decorates it.
class UsageModelList extends StatelessWidget {
  const UsageModelList({super.key, required this.models, this.footer});

  final List<UsageModelEntry> models;
  final String? footer;

  @override
  Widget build(BuildContext context) => GroupedSection(
    header: context.l10n.serverCareUsageByModel,
    footer: footer,
    children: [for (final m in models) _ModelRow(entry: m)],
  );
}

class _ModelRow extends StatelessWidget {
  const _ModelRow({required this.entry});

  final UsageModelEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final metrics = GroupedMetrics.of(context);
    final scheme = Theme.of(context).colorScheme;
    final muted = context.hermesColors.subtleText;
    final share = formatShare(l10n, entry.share);
    final subtitle =
        '${formatTokens(l10n, entry.tokens)} · '
        '${formatDollars(l10n, entry.cost)} · '
        '${formatConversations(l10n, entry.conversations)}';
    return Semantics(
      container: true,
      label: l10n.serverCareUsageModelSpoken(
        entry.model,
        formatTokensSpoken(l10n, entry.tokens),
        formatDollars(l10n, entry.cost),
        formatConversations(l10n, entry.conversations),
        share,
      ),
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: metrics.rowMinHeight),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: metrics.rowPadding,
              vertical: metrics.rowVerticalPadding + 4,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.model,
                        style: TextStyle(
                          fontSize: metrics.titleSize,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: metrics.subtitleSize,
                          color: muted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: entry.share.clamp(0.0, 1.0),
                          minHeight: 4,
                          color: scheme.primary,
                          backgroundColor: scheme.outlineVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  share,
                  style: TextStyle(
                    fontSize: metrics.titleSize,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
