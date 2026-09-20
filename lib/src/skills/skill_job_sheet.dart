import 'package:flutter/material.dart';

import 'skill_job.dart';
import 'skills_hub_controller.dart';

/// Shows a running or finished job: a progress bar and the tail of its log
/// while it runs, and the outcome when it ends. Closing it while the job runs
/// leaves the job running.
Future<void> showSkillJobSheet(BuildContext context, SkillsHubController hub) {
  final job = hub.job;
  if (job == null) return Future.value();
  hub.sheetOpen = true;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => SkillJobSheet(job: job),
  ).whenComplete(() {
    hub.sheetOpen = false;
    hub.dismissJob();
  });
}

class SkillJobSheet extends StatelessWidget {
  const SkillJobSheet({super.key, required this.job});

  final SkillJob job;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: job,
      builder: (context, _) {
        final theme = Theme.of(context);
        final tail = job.lines.length > 6
            ? job.lines.sublist(job.lines.length - 6)
            : job.lines;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(job.title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                if (job.running) const LinearProgressIndicator(),
                if (!job.running)
                  Text(
                    _outcome(job),
                    style: TextStyle(
                      color: job.state == JobState.succeeded
                          ? null
                          : theme.colorScheme.error,
                    ),
                  ),
                if (tail.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.inverseSurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      tail.join('\n'),
                      key: const ValueKey('job-log'),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: theme.colorScheme.onInverseSurface,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(job.running ? 'Run in background' : 'Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _outcome(SkillJob job) => switch (job.state) {
    JobState.succeeded => 'Done.',
    JobState.failed => job.error ?? 'It failed.',
    JobState.unknown =>
      'The result could not be confirmed. The installed list was refreshed.',
    _ => '',
  };
}
