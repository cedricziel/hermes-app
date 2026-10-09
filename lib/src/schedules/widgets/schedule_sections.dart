import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../theme/platform_chrome.dart';
import '../../widgets/grouped_list.dart';
import '../schedule_models.dart';
import '../schedule_widgets.dart';
import 'run_history_empty.dart';
import 'run_history_pending.dart';

/// How [job] is doing as the first row of its detail: the status, the next
/// run, a failure on the error line and an undelivered result on the warning
/// line.
class ScheduleStatusRow extends StatelessWidget {
  const ScheduleStatusRow({super.key, required this.job, required this.now});

  final CronJob job;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final quiet = job.isPaused || job.state == CronJobState.completed;
    final undelivered = job.outcome == CronOutcome.deliveryFailed;
    final deliveryError = job.lastDeliveryError;
    return GroupedRow(
      title: statusText(job, now),
      subtitle: nextRunText(job, now),
      error: !quiet && job.isFailing && !undelivered
          ? failureReason(job)
          : null,
      warning: deliveryError == null
          ? null
          : undelivered
          ? deliveryError
          : 'Delivery failed: $deliveryError',
    );
  }
}

/// A label and its value: on Apple platforms the value muted at the end of
/// the row, on Material under the label.
class ScheduleFactRow extends StatelessWidget {
  const ScheduleFactRow({
    super.key,
    required this.label,
    required this.value,
    this.monospace = false,
  });

  final String label;
  final String value;

  /// Sets [value] in a monospaced font, such as a cron expression.
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    if (!platformChromeOf(context).isApple) {
      return GroupedRow(
        title: label,
        subtitle: value,
        monospaceSubtitle: monospace,
      );
    }
    final metrics = GroupedMetrics.of(context);
    final scheme = Theme.of(context).colorScheme;
    return MergeSemantics(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: metrics.rowMinHeight),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: metrics.rowPadding,
            vertical: metrics.rowVerticalPadding,
          ),
          child: Row(
            spacing: 16,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: metrics.titleSize,
                  color: scheme.onSurface,
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: monospace
                        ? metrics.subtitleSize
                        : metrics.titleSize,
                    fontFamily: monospace ? 'monospace' : null,
                    color: context.hermesColors.subtleText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What [job] does: when it runs, its task, and its settings.
List<Widget> scheduleFactSections(CronJob job) => [
  GroupedSection(
    header: 'Schedule',
    children: [
      ScheduleFactRow(
        label: 'Repeats',
        value: job.scheduleWords.isEmpty ? 'Unknown' : job.scheduleWords,
      ),
      if (job.scheduleKind == 'cron' && job.scheduleExpr != null)
        ScheduleFactRow(
          label: 'Cron',
          value: job.scheduleExpr!,
          monospace: true,
        ),
    ],
  ),
  if (job.prompt.isNotEmpty)
    GroupedSection(header: 'Task', children: [_Prompt(job.prompt)]),
  GroupedSection(
    header: 'Settings',
    children: [
      for (final (label, value) in jobSettings(job))
        ScheduleFactRow(label: label, value: value),
      ScheduleFactRow(label: 'Deliver to', value: deliveryLabel(job.deliver)),
      if (job.profile != null)
        ScheduleFactRow(label: 'Profile', value: job.profile!),
    ],
  ),
];

class _Prompt extends StatelessWidget {
  const _Prompt(this.prompt);

  final String prompt;

  @override
  Widget build(BuildContext context) {
    final metrics = GroupedMetrics.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: metrics.rowPadding,
        vertical: metrics.rowVerticalPadding + 4,
      ),
      child: SelectableText(
        prompt,
        style: TextStyle(fontSize: metrics.titleSize),
      ),
    );
  }
}

/// The runs of [job], each opening its chat. [runs] is null while they load;
/// [runsFailed] says the load failed.
class ScheduleRunsSection extends StatelessWidget {
  const ScheduleRunsSection({
    super.key,
    required this.header,
    required this.job,
    required this.runs,
    required this.onOpenRun,
    required this.onRetry,
    this.runsFailed = false,
    this.onShowMore,
  });

  final String header;
  final CronJob job;
  final List<CronRun>? runs;
  final bool runsFailed;
  final ValueChanged<CronRun> onOpenRun;
  final VoidCallback onRetry;

  /// Loads more runs; null when every run is listed.
  final VoidCallback? onShowMore;

  @override
  Widget build(BuildContext context) {
    final runs = this.runs;
    final metrics = GroupedMetrics.of(context);
    Widget padded(Widget child) => Padding(
      padding: EdgeInsets.symmetric(
        horizontal: metrics.rowPadding,
        vertical: metrics.rowVerticalPadding + 4,
      ),
      child: child,
    );
    final onShowMore = this.onShowMore;
    return GroupedSection(
      header: header,
      dividerIndent: metrics.indentAfterLeading,
      children: [
        if (runs == null)
          padded(RunHistoryPending(failed: runsFailed, onRetry: onRetry))
        else if (runs.isEmpty)
          padded(RunHistoryEmpty(job: job))
        else
          for (final (i, run) in runs.indexed)
            _RunRow(
              run: run,
              failed: i == 0 && job.isFailing && !run.isActive,
              onTap: () => onOpenRun(run),
            ),
        if (onShowMore != null)
          GroupedRow(title: 'Show more', onTap: onShowMore, chevron: false),
      ],
    );
  }
}

class _RunRow extends StatelessWidget {
  const _RunRow({required this.run, required this.failed, required this.onTap});

  final CronRun run;
  final bool failed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.hermesColors;
    final size = GroupedMetrics.of(context).leadingSize;
    final outcome = runOutcomeText(run);
    final (Widget icon, String label) = switch (run) {
      CronRun(isActive: true) => (
        SizedBox.square(
          dimension: size - 4,
          child: const CircularProgressIndicator.adaptive(strokeWidth: 2),
        ),
        outcome,
      ),
      _ when failed => (
        AppIcon(AppIcons.error, color: scheme.error),
        run.duration == null ? 'Failed' : 'Failed · $outcome',
      ),
      CronRun(duration: null) => (
        AppIcon(AppIcons.warning, color: colors.warning),
        outcome,
      ),
      _ => (AppIcon(AppIcons.checkCircle, color: colors.success), outcome),
    };
    return GroupedRow(
      leading: SizedBox.square(
        dimension: size,
        child: Center(child: icon),
      ),
      title: formatTime(context, run.startedAt),
      value: label,
      onTap: onTap,
    );
  }
}
