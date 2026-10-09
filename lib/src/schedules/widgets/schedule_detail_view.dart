import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../theme/platform_chrome.dart';
import '../../widgets/adaptive_popup_menu_button.dart';
import '../../widgets/grouped_list.dart';
import '../schedule_models.dart';
import '../schedule_widgets.dart';
import 'schedule_sections.dart';

/// One job in full as grouped sections: how it is doing, what can be done
/// with it, what it does and its runs. A Mac pane leads with
/// [MacScheduleHeader], which holds the actions, muting and deleting.
///
/// [runs] is null while they load; [runsFailed] says the load failed.
/// [muted] is null where notifications cannot be muted.
class ScheduleDetailView extends StatelessWidget {
  const ScheduleDetailView({
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
    this.showTitle = true,
  });

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

  /// Names the job above its sections; off where the bar already does.
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final mac = platformChromeOf(context) == PlatformChrome.macos;
    final metrics = GroupedMetrics.of(context);
    final muted = this.muted;
    final onMutedChanged = this.onMutedChanged;
    return GroupedListView(
      children: [
        if (mac)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: MacScheduleHeader(
              job: job,
              now: now,
              muted: muted,
              onMutedChanged: onMutedChanged,
              onRunNow: onRunNow,
              onEdit: onEdit,
              onTogglePaused: onTogglePaused,
              onDelete: onDelete,
            ),
          )
        else if (showTitle)
          Padding(
            padding: EdgeInsets.fromLTRB(
              metrics.rowPadding,
              16,
              metrics.rowPadding,
              0,
            ),
            child: Text(
              job.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
        GroupedSection(
          children: [
            ScheduleStatusRow(job: job, now: now),
            if (!mac && muted != null && onMutedChanged != null)
              GroupedSwitchRow(
                key: const Key('job-mute'),
                title: 'Mute notifications',
                subtitle: 'No alert when this task runs',
                value: muted,
                onChanged: onMutedChanged,
              ),
          ],
        ),
        if (!mac)
          GroupedSection(
            dividerIndent: metrics.indentAfterLeading,
            children: [
              GroupedRow(
                leading: const AppIcon(AppIcons.play),
                title: 'Run now',
                onTap: onRunNow,
                chevron: false,
              ),
              if (job.state != CronJobState.completed)
                GroupedRow(
                  leading: AppIcon(
                    job.isPaused ? AppIcons.resume : AppIcons.pause,
                  ),
                  title: job.isPaused ? 'Resume' : 'Pause',
                  onTap: onTogglePaused,
                  chevron: false,
                ),
              GroupedRow(
                leading: const AppIcon(AppIcons.edit),
                title: 'Edit',
                onTap: onEdit,
              ),
            ],
          ),
        ...scheduleFactSections(job),
        ScheduleRunsSection(
          header: mac ? 'Recent runs' : 'Run history',
          job: job,
          runs: runs,
          runsFailed: runsFailed,
          onOpenRun: onOpenRun,
          onRetry: onRetryRuns,
          onShowMore: onShowMoreRuns,
        ),
        if (!mac)
          GroupedSection(
            children: [
              GroupedRow(
                title: 'Delete task',
                destructive: true,
                onTap: onDelete,
                chevron: false,
              ),
            ],
          ),
      ],
    );
  }
}

/// The top of a job's Mac pane: its title over when it runs, a More menu,
/// Edit and Run now. In a narrow pane the buttons go under the title.
class MacScheduleHeader extends StatelessWidget {
  const MacScheduleHeader({
    super.key,
    required this.job,
    required this.now,
    required this.onRunNow,
    required this.onEdit,
    required this.onTogglePaused,
    required this.onDelete,
    this.muted,
    this.onMutedChanged,
  });

  final CronJob job;
  final DateTime now;
  final bool? muted;
  final VoidCallback onRunNow;
  final VoidCallback onEdit;
  final VoidCallback onTogglePaused;
  final VoidCallback onDelete;
  final ValueChanged<bool>? onMutedChanged;

  static const double _rowMinWidth = 460;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final next = upcomingRun(job);
    final subtitle = [
      if (job.scheduleWords.isNotEmpty) job.scheduleWords,
      if (next != null) 'next run ${relativeTime(next, now)}',
    ].join(' · ');
    final heading = Column(
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
    );
    final buttons = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        _more(context),
        OutlinedButton(onPressed: onEdit, child: const Text('Edit')),
        FilledButton.icon(
          onPressed: onRunNow,
          icon: const AppIcon(AppIcons.play, size: 16),
          label: const Text('Run now'),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, box) => box.maxWidth < _rowMinWidth
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: [heading, buttons],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                Expanded(child: heading),
                buttons,
              ],
            ),
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
}

enum _MoreAction { pause, mute, delete }
