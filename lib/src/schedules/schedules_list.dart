import 'package:flutter/material.dart';
import 'package:hermes_app/src/widgets/state_message.dart';

import '../theme/app_icons.dart';
import '../widgets/grouped_list.dart';
import 'schedule_actions.dart';
import 'schedule_models.dart';
import 'schedule_widgets.dart';
import 'schedules_controller.dart';
import 'widgets/job_group.dart';

/// The jobs of the server as one inset group; the bar holds the filter.
class SchedulesList extends StatelessWidget {
  const SchedulesList({
    super.key,
    required this.controller,
    required this.onSelect,
    this.selectedKey,
    this.macLayout = false,
  });

  final SchedulesController controller;
  final ValueChanged<CronJob> onSelect;
  final String? selectedKey;

  /// Lays the jobs out for a Mac window, whose toolbar holds the scope.
  final bool macLayout;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (controller.error != null && controller.loaded)
            _ErrorNote(controller: controller),
          Expanded(child: _body(context, controller.visibleJobs)),
        ],
      ),
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
                  title: controller.filter != ScheduleFilter.all
                      ? 'No tasks match this filter'
                      : macLayout && !controller.allProfiles
                      ? 'No schedules in this profile'
                      : 'No scheduled tasks',
                ),
              ),
            ],
          ),
        ),
      );
    }
    Future<void> pausedChanged(CronJob job, bool paused) async {
      final message = await controller.setPaused(job, paused);
      if (message != null && context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
    }

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: GroupedListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          JobGroup(
            jobs: jobs,
            now: controller.now,
            showProfile: controller.showProfiles,
            selectedKey: selectedKey,
            onSelect: onSelect,
            onPausedChanged: pausedChanged,
            actionsFor: (job) => scheduleRowActions(context, controller, job),
          ),
        ],
      ),
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
          AppIcon(AppIcons.error, size: 16, color: scheme.error),
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

/// A job as a row of a [GroupedSection]: its schedule and where it delivers,
/// how it is doing, a failure on the error or warning line, and a switch
/// that pauses it.
class JobTile extends StatelessWidget {
  const JobTile({
    super.key,
    required this.job,
    required this.now,
    required this.onTap,
    required this.onPausedChanged,
    this.showProfile = false,
    this.selected = false,
  });

  final CronJob job;
  final DateTime now;
  final bool showProfile;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<bool> onPausedChanged;

  @override
  Widget build(BuildContext context) {
    final completed = job.state == CronJobState.completed;
    final alert = jobAlert(job);
    final warning = alert == JobAlert.undelivered;
    final error = alert == JobAlert.failed;
    final status = [
      statusText(job, now),
      if (job.isFailing || job.outcome == CronOutcome.deliveryFailed)
        ?failureReason(job),
    ].join(' · ');
    final next = nextRunText(job, now);
    return GroupedSwitchRow(
      title: job.title,
      subtitle: [
        if (job.scheduleWords.isNotEmpty) job.scheduleWords,
        deliveryLabel(job.deliver),
        if (showProfile && job.profile != null) job.profile!,
      ].join(' · '),
      caption: error || warning ? next : [status, ?next].join(' · '),
      error: error ? status : null,
      warning: warning ? status : null,
      selected: selected,
      value: !job.isPaused && !completed,
      onChanged: completed ? null : (on) => onPausedChanged(!on),
      onTap: onTap,
    );
  }
}
