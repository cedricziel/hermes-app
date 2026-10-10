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
/// run, why the last run failed on the error line and an undelivered result
/// on the warning line. A paused or finished job keeps them. On a Mac they
/// are monospaced and selectable, so a failure can be copied.
class ScheduleStatusRow extends StatelessWidget {
  const ScheduleStatusRow({super.key, required this.job, required this.now});

  final CronJob job;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final undelivered = job.outcome == CronOutcome.deliveryFailed;
    final failure = job.isFailing && !undelivered ? failureReason(job) : null;
    final deliveryError = job.lastDeliveryError;
    final warning = deliveryError == null
        ? null
        : undelivered
        ? deliveryError
        : 'Delivery failed: $deliveryError';
    final mac = platformChromeOf(context) == PlatformChrome.macos;
    final row = GroupedRow(
      title: statusText(job, now),
      subtitle: nextRunText(job, now),
      error: mac ? null : failure,
      warning: mac ? null : warning,
    );
    if (!mac || (failure == null && warning == null)) return row;
    final metrics = GroupedMetrics.of(context);
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row,
          Padding(
            padding: EdgeInsets.fromLTRB(
              metrics.rowPadding,
              0,
              metrics.rowPadding,
              metrics.rowVerticalPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 4,
              children: [
                if (failure != null)
                  _SelectableProblem(
                    icon: AppIcons.error,
                    text: failure,
                    color: Theme.of(context).colorScheme.error,
                  ),
                if (warning != null)
                  _SelectableProblem(
                    icon: AppIcons.warning,
                    text: warning,
                    color: context.hermesColors.warning,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A failure under a Mac status row, monospaced and selectable.
class _SelectableProblem extends StatelessWidget {
  const _SelectableProblem({
    required this.icon,
    required this.text,
    required this.color,
  });

  final AppIconSet icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final size = GroupedMetrics.of(context).subtitleSize;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: AppIcon(icon, size: size, color: color),
        ),
        Expanded(
          child: SelectableText(
            text,
            style: TextStyle(
              fontSize: size,
              fontFamily: 'monospace',
              color: color,
            ),
          ),
        ),
      ],
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

/// Free content in a group, such as a prompt or a note, padded like a row.
class _Padded extends StatelessWidget {
  const _Padded(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final metrics = GroupedMetrics.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: metrics.rowPadding,
        vertical: metrics.rowVerticalPadding + 4,
      ),
      child: child,
    );
  }
}

class _Prompt extends StatelessWidget {
  const _Prompt(this.prompt);

  final String prompt;

  @override
  Widget build(BuildContext context) => _Padded(
    SelectableText(
      prompt,
      style: TextStyle(fontSize: GroupedMetrics.of(context).titleSize),
    ),
  );
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
    final onShowMore = this.onShowMore;
    return GroupedSection(
      header: header,
      dividerIndent: metrics.indentAfterLeading,
      children: [
        if (runs == null)
          _Padded(RunHistoryPending(failed: runsFailed, onRetry: onRetry))
        else if (runs.isEmpty)
          _Padded(RunHistoryEmpty(job: job))
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
