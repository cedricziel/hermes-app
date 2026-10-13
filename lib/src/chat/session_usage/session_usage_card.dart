import 'dart:async';

import 'package:flutter/material.dart';

import '../../widgets/disclosure_tile.dart';
import 'session_usage_controller.dart';

class SessionUsageCard extends StatelessWidget {
  const SessionUsageCard({
    super.key,
    required this.controller,
    this.initiallyOpen = false,
  });
  final SessionUsageController controller;
  final bool initiallyOpen;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      if (!controller.bound) return const SizedBox.shrink();
      final snapshot = controller.snapshot;
      final total = snapshot?.total;
      final title = total == null
          ? 'Session usage'
          : 'Session usage · ${MaterialLocalizations.of(context).formatDecimal(total)} tokens';
      return DisclosureTile(
        initiallyExpanded: initiallyOpen,
        onExpansionChanged: (open) {
          if (open) unawaited(controller.opened());
        },
        dense: true,
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (controller.loading) const Text('Loading session usage…'),
                if (controller.freshness == UsageFreshness.stale)
                  const Text('Stale session usage'),
                if (controller.freshness == UsageFreshness.unsupported)
                  const Text('Session usage is unavailable on this server.'),
                if (!controller.loading &&
                    snapshot == null &&
                    controller.freshness == UsageFreshness.unavailable)
                  const Text('Session usage unavailable'),
                if (snapshot?.model case final model?)
                  SelectableText('Model: $model'),
                if (snapshot != null) ...[
                  for (final metric in snapshot.metrics.entries)
                    if (metric.value case final value?)
                      Text('${metric.key}: $value'),
                  if (snapshot.contextEstimated == true)
                    const Text('Estimated context'),
                  if (snapshot.costStatus case final status?)
                    SelectableText('Cost status: $status'),
                ],
                if (controller.failure == UsageFailure.transport)
                  const Text('Could not refresh session usage.'),
                if (controller.canRefresh)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => unawaited(controller.refresh()),
                      child: const Text('Refresh usage'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    },
  );
}
