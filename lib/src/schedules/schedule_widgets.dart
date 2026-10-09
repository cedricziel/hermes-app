import 'package:flutter/material.dart';

import 'schedule_models.dart';

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

/// What a job's row and detail flag about its last run.
enum JobAlert { failed, undelivered }

/// The alert [job] calls for; none while it is paused or finished, whose
/// last failure is told rather than flagged.
JobAlert? jobAlert(CronJob job) {
  if (job.isPaused || job.state == CronJobState.completed) return null;
  if (job.outcome == CronOutcome.deliveryFailed) return JobAlert.undelivered;
  return job.isFailing ? JobAlert.failed : null;
}

/// The short reason a run failed, for the list: the first line, trimmed.
String? failureReason(CronJob job) {
  final text = job.outcome == CronOutcome.deliveryFailed
      ? job.lastDeliveryError
      : job.lastError;
  if (text == null) return null;
  final line = text.split('\n').first.trim();
  return line.isEmpty ? null : line;
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
