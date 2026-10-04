import 'package:flutter/material.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

import 'schedule_models.dart';

Color outcomeColor(BuildContext context, CronJob job) {
  final scheme = Theme.of(context).colorScheme;
  if (job.isPaused || job.state == CronJobState.completed) {
    return scheme.onSurfaceVariant;
  }
  return switch (job.outcome) {
    CronOutcome.failed => scheme.error,
    CronOutcome.deliveryFailed => context.hermesColors.warning,
    CronOutcome.ok => context.hermesColors.success,
    CronOutcome.none => scheme.onSurfaceVariant,
  };
}

/// The one line a row and the detail say about how the job is doing.
String statusText(CronJob job, DateTime now) {
  if (job.state == CronJobState.paused) return 'Paused';
  if (job.state == CronJobState.completed) return 'Completed';
  final last = job.lastRunAt;
  // A status without a readable time still says how the run went.
  final at = last == null ? '' : ' ${relativeTime(last, now)}';
  return switch (job.outcome) {
    CronOutcome.none => 'Not run yet',
    CronOutcome.ok => 'Last run succeeded$at',
    CronOutcome.failed => 'Failed$at',
    CronOutcome.deliveryFailed => 'Ran, but delivery failed$at',
  };
}

/// When [job] runs next; null while it is paused or done.
DateTime? upcomingRun(CronJob job) =>
    job.isPaused || job.state == CronJobState.completed ? null : job.nextRunAt;

String? nextRunText(CronJob job, DateTime now) {
  final next = upcomingRun(job);
  return next == null ? null : 'Next run ${relativeTime(next, now)}';
}

/// How a run went, in a word or its length.
String runOutcomeText(CronRun run) => run.isActive
    ? 'Running'
    : run.duration == null
    ? 'Unfinished'
    : formatDuration(run.duration!);

/// The job's settings a detail lists, as label and value.
List<(String, String)> jobSettings(CronJob job) => [
  if (job.skills.isNotEmpty) ('Skills', job.skills.join(', ')),
  if (job.model != null) ('Model', job.model!),
  if (job.provider != null) ('Provider', job.provider!),
  if (job.script != null) ('Script', job.script!),
  if (job.workdir != null) ('Working directory', job.workdir!),
  if (job.contextFrom.isNotEmpty)
    ('Takes context from', job.contextFrom.join(', ')),
];

/// The short reason a run failed, for the list: the first line, trimmed.
String? failureReason(CronJob job) {
  final text = job.outcome == CronOutcome.deliveryFailed
      ? job.lastDeliveryError
      : job.lastError;
  if (text == null) return null;
  final line = text.split('\n').first.trim();
  return line.isEmpty ? null : line;
}

class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// A small outlined label, used for the delivery target and profile.
class InfoChip extends StatelessWidget {
  const InfoChip(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

String deliveryLabel(String? deliver) => switch (deliver) {
  null || '' || 'local' => 'Local',
  'origin' => 'Origin chat',
  final other => other[0].toUpperCase() + other.substring(1),
};

String formatTime(BuildContext context, DateTime time) {
  final l10n = MaterialLocalizations.of(context);
  return '${l10n.formatShortDate(time)} '
      '${l10n.formatTimeOfDay(TimeOfDay.fromDateTime(time))}';
}
