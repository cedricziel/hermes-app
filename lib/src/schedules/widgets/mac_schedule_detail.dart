import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../widgets/adaptive_popup_menu_button.dart';
import '../schedule_models.dart';
import '../schedule_widgets.dart';
import 'run_history_empty.dart';

/// One job in a Mac window's detail pane: a header with Edit and Run now,
/// the last failure, the job's settings as a grid and its recent runs.
///
/// [runs] is null while they load; [runsFailed] says the load failed.
/// [muted] is null where notifications cannot be muted.
class MacScheduleDetail extends StatelessWidget {
  const MacScheduleDetail({
    super.key,
    required this.job,
    required this.now,
    required this.runs,
    required this.onRunNow,
    required this.onEdit,
    required this.onTogglePaused,
    required this.onDelete,
    required this.onOpenRun,
    required this.onRetryRuns,
    this.runsFailed = false,
    this.onShowMoreRuns,
    this.muted,
    this.onMutedChanged,
  });

  static const double maxWidth = 560;

  final CronJob job;
  final DateTime now;
  final List<CronRun>? runs;
  final bool runsFailed;
  final bool? muted;
  final VoidCallback onRunNow;
  final VoidCallback onEdit;
  final VoidCallback onTogglePaused;
  final VoidCallback onDelete;
  final ValueChanged<CronRun> onOpenRun;
  final VoidCallback onRetryRuns;

  /// Loads more runs; null when every run is listed.
  final VoidCallback? onShowMoreRuns;
  final ValueChanged<bool>? onMutedChanged;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 20,
            children: [
              _header(context),
              ?_failure(context),
              _Facts(rows: _facts(context)),
              _runs(context),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _header(BuildContext context) {
    final theme = Theme.of(context);
    final next = job.isPaused || job.state == CronJobState.completed
        ? null
        : job.nextRunAt;
    final subtitle = [
      if (job.scheduleWords.isNotEmpty) job.scheduleWords,
      if (next != null) 'next run ${relativeTime(next, now)}',
    ].join(' · ');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [
              Text(job.title, style: theme.textTheme.titleMedium),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.hermesColors.subtleText,
                  ),
                ),
            ],
          ),
        ),
        _more(context),
        OutlinedButton(onPressed: onEdit, child: const Text('Edit')),
        FilledButton.icon(
          onPressed: onRunNow,
          icon: const AppIcon(AppIcons.play, size: 16),
          label: const Text('Run now'),
        ),
      ],
    );
  }

  Widget _more(BuildContext context) {
    final muted = this.muted;
    final onMutedChanged = this.onMutedChanged;
    return AdaptivePopupMenuButton<_MoreAction>(
      tooltip: 'More',
      icon: const AppIcon(AppIcons.more, size: 18),
      onSelected: (action) => switch (action) {
        _MoreAction.pause => onTogglePaused(),
        _MoreAction.mute => onMutedChanged?.call(!(muted ?? false)),
        _MoreAction.delete => onDelete(),
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _MoreAction.pause,
          enabled: job.state != CronJobState.completed,
          child: Text(job.isPaused ? 'Resume' : 'Pause'),
        ),
        if (muted != null && onMutedChanged != null)
          CheckedPopupMenuItem(
            value: _MoreAction.mute,
            checked: muted,
            child: const Text('Mute Notifications'),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _MoreAction.delete,
          child: Text(
            'Delete…',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ],
    );
  }

  Widget? _failure(BuildContext context) {
    final delivery = job.outcome == CronOutcome.deliveryFailed;
    if (!job.isFailing && !delivery) return null;
    final colors = context.hermesColors;
    final color = delivery
        ? colors.warning
        : Theme.of(context).colorScheme.error;
    final last = job.lastRunAt;
    final detail = [
      ?failureReason(job),
      if (last != null) relativeTime(last, now),
    ].join(' · ');
    return _Card(
      padding: const EdgeInsets.all(12),
      child: Row(
        spacing: 10,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Badge(label: delivery ? 'Delivery failed' : 'Failed', color: color),
          Expanded(
            child: SelectableText(
              detail,
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  List<(String, Widget)> _facts(BuildContext context) {
    Widget text(String value) => Text(value);
    final deliveryError = job.lastDeliveryError;
    return [
      if (job.profile != null) ('Profile', text(job.profile!)),
      ('Deliver to', text(deliveryLabel(job.deliver))),
      ('Status', text(_status)),
      if (job.scheduleKind == 'cron' && job.scheduleExpr != null)
        (
          'Cron',
          Text(
            job.scheduleExpr!,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ),
      if (deliveryError != null && job.outcome != CronOutcome.deliveryFailed)
        ('Delivery', text('Failed: $deliveryError')),
      if (job.skills.isNotEmpty) ('Skills', text(job.skills.join(', '))),
      if (job.model != null) ('Model', text(job.model!)),
      if (job.provider != null) ('Provider', text(job.provider!)),
      if (job.script != null) ('Script', text(job.script!)),
      if (job.workdir != null) ('Working directory', text(job.workdir!)),
      if (job.contextFrom.isNotEmpty)
        ('Takes context from', text(job.contextFrom.join(', '))),
      if (job.prompt.isNotEmpty) ('Prompt', SelectableText(job.prompt)),
    ];
  }

  String get _status => switch (job.state) {
    CronJobState.paused => 'Paused',
    CronJobState.completed => 'Completed',
    _ => 'Active',
  };

  Widget _runs(BuildContext context) {
    final theme = Theme.of(context);
    final runs = this.runs;
    final Widget body;
    if (runs == null) {
      body = runsFailed
          ? Row(
              children: [
                const Expanded(child: Text('Could not load the runs')),
                TextButton(onPressed: onRetryRuns, child: const Text('Retry')),
              ],
            )
          : const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator.adaptive()),
            );
    } else if (runs.isEmpty) {
      body = RunHistoryEmpty(job: job);
    } else {
      body = _Card(
        child: Column(
          children: [
            for (final (i, run) in runs.indexed) ...[
              if (i > 0) Divider(height: 1, color: theme.dividerColor),
              _RunRow(
                run: run,
                failed: i == 0 && job.isFailing && !run.isActive,
                onTap: () => onOpenRun(run),
              ),
            ],
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Text('Recent runs', style: theme.textTheme.titleSmall),
        body,
        if (onShowMoreRuns != null)
          TextButton(onPressed: onShowMoreRuns, child: const Text('Show more')),
      ],
    );
  }
}

enum _MoreAction { pause, mute, delete }

/// The settings as two columns: a 110 point column of muted keys, then the
/// values.
class _Facts extends StatelessWidget {
  const _Facts({required this.rows});

  final List<(String, Widget)> rows;

  @override
  Widget build(BuildContext context) {
    final muted = context.hermesColors.subtleText;
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: 13, height: 1.4),
      child: Column(
        spacing: 8,
        children: [
          for (final (key, value) in rows)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 110,
                  child: Text(key, style: TextStyle(color: muted)),
                ),
                Expanded(child: value),
              ],
            ),
        ],
      ),
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
    final duration = run.duration;
    final took = duration == null ? null : formatDuration(duration);
    final (Widget icon, String outcome) = run.isActive
        ? (
            const SizedBox.square(
              dimension: 14,
              child: CircularProgressIndicator.adaptive(strokeWidth: 2),
            ),
            'Running',
          )
        : failed
        ? (
            AppIcon(AppIcons.error, size: 16, color: scheme.error),
            took == null ? 'Failed' : 'Failed · $took',
          )
        : took == null
        ? (
            AppIcon(AppIcons.warning, size: 16, color: colors.warning),
            'Unfinished',
          )
        : (
            AppIcon(AppIcons.checkCircle, size: 16, color: colors.success),
            took,
          );
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 36,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            spacing: 10,
            children: [
              icon,
              Expanded(
                child: Text(
                  formatTime(context, run.startedAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              Text(
                outcome,
                style: TextStyle(fontSize: 12, color: colors.subtleText),
              ),
              AppIcon(
                AppIcons.chevronRight,
                size: 14,
                color: colors.subtleText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = EdgeInsets.zero});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).dividerColor),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Material(type: MaterialType.transparency, child: child),
  );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
    ),
  );
}
