import 'package:flutter/material.dart';

import '../schedule_models.dart';
import '../schedule_widgets.dart';

/// What the run history says when a job has no runs to list.
class RunHistoryEmpty extends StatelessWidget {
  const RunHistoryEmpty({super.key, required this.job});

  final CronJob job;

  @override
  Widget build(BuildContext context) {
    if (!job.isBlocked) return const Text('No runs yet');
    final theme = Theme.of(context);
    final reason = failureReason(job);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: [
        const Text(
          'Hermes blocked this task before it could start, so no run was '
          'recorded. It tries again at the next scheduled time.',
        ),
        if (reason != null)
          Text(
            reason,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontFamily: 'monospace',
            ),
          ),
      ],
    );
  }
}
