import 'package:flutter/material.dart';

import '../widgets/busy_bar.dart';
import '../widgets/dialog_presentation.dart';
import 'skill_job.dart';
import 'skills_hub_controller.dart';

/// Shows a running or finished job: a progress bar and the tail of its log
/// while it runs, and the outcome when it ends. Closing it while the job runs
/// leaves the job running.
Future<void> showSkillJobSheet(BuildContext context, SkillsHubController hub) {
  final job = hub.job;
  if (job == null) return Future.value();
  hub.sheetOpen = true;
  return showSkillJobStatus(context, job).whenComplete(() {
    hub.sheetOpen = false;
    hub.dismissJob();
  });
}

/// Presents [job] without changing its execution or owning its lifetime.
Future<void> showSkillJobStatus(BuildContext context, SkillJob job) {
  if (Theme.of(context).platform == TargetPlatform.macOS) {
    return showAppDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
          child: SkillJobSheet(job: job),
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => SkillJobSheet(job: job),
  );
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
        final desktop = theme.platform == TargetPlatform.macOS;
        final close = Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(job.running ? 'Run in background' : 'Close'),
          ),
        );
        final details = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(job.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            if (job.running) const BusyBar(),
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
          ],
        );
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, desktop ? 16 : 0, 16, 16),
            child: desktop
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(child: SingleChildScrollView(child: details)),
                      const SizedBox(height: 8),
                      close,
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [details, const SizedBox(height: 8), close],
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
