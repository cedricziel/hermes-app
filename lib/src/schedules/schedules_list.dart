import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hermes_app/src/theme/platform_chrome.dart';
import 'package:hermes_app/src/widgets/state_message.dart';

import 'schedule_models.dart';
import 'schedule_widgets.dart';
import 'schedules_controller.dart';
import 'widgets/schedule_filter_bar.dart';

/// The jobs of the server as cards, with the profile and filter chips above.
class SchedulesList extends StatelessWidget {
  const SchedulesList({
    super.key,
    required this.controller,
    required this.onSelect,
    this.selectedKey,
  });

  final SchedulesController controller;
  final ValueChanged<CronJob> onSelect;
  final String? selectedKey;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final jobs = controller.visibleJobs;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ScheduleFilterBar(
              activeProfile: controller.activeProfile,
              allProfiles: controller.allProfiles,
              filter: controller.filter,
              failingCount: controller.failingCount,
              onAllProfilesChanged: (all) => controller.allProfiles = all,
              onFilterChanged: (filter) => controller.filter = filter,
            ),
            if (controller.error != null && controller.loaded)
              _ErrorNote(controller: controller),
            Expanded(child: _body(context, jobs)),
          ],
        );
      },
    );
  }

  Widget _body(BuildContext context, List<CronJob> jobs) {
    if (!controller.loaded) {
      if (controller.error != null) {
        return StateMessage(
          title: controller.error!,
          action: FilledButton(
            onPressed: controller.refresh,
            child: const Text('Try again'),
          ),
        );
      }
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    if (jobs.isEmpty) {
      return RefreshIndicator(
        onRefresh: controller.refresh,
        child: LayoutBuilder(
          builder: (context, box) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: box.maxHeight,
                child: StateMessage(
                  title: controller.filter == ScheduleFilter.all
                      ? 'No scheduled tasks'
                      : 'No tasks match this filter',
                ),
              ),
            ],
          ),
        ),
      );
    }
    final apple = platformChromeOf(context).isApple;
    Widget tile(CronJob job, {required bool grouped}) => JobTile(
      job: job,
      now: controller.now,
      showProfile: controller.showProfiles,
      selected: job.key == selectedKey,
      grouped: grouped,
      onTap: () => onSelect(job),
      onPausedChanged: (paused) async {
        final message = await controller.setPaused(job, paused);
        if (message != null && context.mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(message)));
        }
      },
    );
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: apple
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                InsetGroupedJobs(
                  children: [for (final job in jobs) tile(job, grouped: true)],
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
              itemCount: jobs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) => tile(jobs[i], grouped: false),
            ),
    );
  }
}

/// The jobs as the rows of one iOS inset grouped list.
class InsetGroupedJobs extends StatelessWidget {
  const InsetGroupedJobs({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CupertinoListSection.insetGrouped(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      separatorColor: scheme.outline,
      hasLeading: false,
      dividerMargin: 16,
      topMargin: 4,
      children: children,
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.controller});

  final SchedulesController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 16, color: scheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              controller.error!,
              style: TextStyle(color: scheme.error),
            ),
          ),
          TextButton(onPressed: controller.refresh, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class JobTile extends StatelessWidget {
  const JobTile({
    super.key,
    required this.job,
    required this.now,
    required this.onTap,
    required this.onPausedChanged,
    this.showProfile = false,
    this.selected = false,
    this.grouped = false,
  });

  final CronJob job;
  final DateTime now;
  final bool showProfile;
  final bool selected;

  /// Draws the job as a row of an inset grouped list, without its own card.
  final bool grouped;
  final VoidCallback onTap;
  final ValueChanged<bool> onPausedChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final subtle = scheme.onSurfaceVariant;
    final color = outcomeColor(context, job);
    final next = nextRunText(job, now);
    final reason = job.isFailing || job.outcome == CronOutcome.deliveryFailed
        ? failureReason(job)
        : null;
    return Material(
      color: selected
          ? (grouped ? scheme.outline : scheme.surfaceContainerHighest)
          : Colors.transparent,
      shape: grouped
          ? null
          : RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: scheme.outline),
            ),
      child: InkWell(
        borderRadius: grouped ? null : BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: grouped
              ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
              : const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 6,
            children: [
              Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          job.title,
                          style: theme.textTheme.titleMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        InfoChip(deliveryLabel(job.deliver)),
                        if (showProfile && job.profile != null)
                          InfoChip(job.profile!),
                      ],
                    ),
                  ),
                  MergeSemantics(
                    child: Semantics(
                      label: job.title,
                      child: Switch.adaptive(
                        value:
                            !job.isPaused &&
                            job.state != CronJobState.completed,
                        onChanged: job.state == CronJobState.completed
                            ? null
                            : (on) => onPausedChanged(!on),
                      ),
                    ),
                  ),
                ],
              ),
              if (job.scheduleWords.isNotEmpty)
                Text(
                  job.scheduleWords,
                  style: theme.textTheme.bodyMedium?.copyWith(color: subtle),
                ),
              const Divider(height: 12),
              Row(
                spacing: 8,
                children: [
                  StatusDot(color: color),
                  Expanded(
                    child: Text(
                      statusText(job, now),
                      style: theme.textTheme.bodySmall?.copyWith(color: color),
                    ),
                  ),
                  if (next != null)
                    Text(
                      next,
                      style: theme.textTheme.bodySmall?.copyWith(color: subtle),
                    ),
                ],
              ),
              if (reason != null)
                Text(
                  reason,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: color,
                    fontFamily: 'monospace',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
