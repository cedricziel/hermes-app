import 'package:flutter/material.dart';

import 'schedule_models.dart';
import 'schedule_widgets.dart';
import 'schedules_controller.dart';

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
            _Filters(controller: controller),
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
        return _Message(
          text: controller.error!,
          action: FilledButton(
            onPressed: controller.refresh,
            child: const Text('Try again'),
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
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
                child: _Message(
                  text: controller.filter == ScheduleFilter.all
                      ? 'No scheduled tasks'
                      : 'No tasks match this filter',
                ),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        itemCount: jobs.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) => JobTile(
          job: jobs[i],
          now: controller.now,
          showProfile: controller.showProfiles,
          selected: jobs[i].key == selectedKey,
          onTap: () => onSelect(jobs[i]),
          onPausedChanged: (paused) async {
            final message = await controller.setPaused(jobs[i], paused);
            if (message != null && context.mounted) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(message)));
            }
          },
        ),
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.controller});

  final SchedulesController controller;

  @override
  Widget build(BuildContext context) {
    final profile = controller.activeProfile;
    final failing = controller.failingCount;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        spacing: 8,
        children: [
          if (profile != null)
            ChoiceChip(
              label: Text('$profile (active)'),
              selected: !controller.allProfiles,
              onSelected: (_) => controller.allProfiles = false,
            ),
          ChoiceChip(
            label: const Text('All profiles'),
            selected: controller.allProfiles || profile == null,
            onSelected: (_) => controller.allProfiles = true,
          ),
          FilterChip(
            label: Text(failing > 0 ? 'Failing ($failing)' : 'Failing'),
            selected: controller.filter == ScheduleFilter.failing,
            onSelected: (on) => controller.filter = on
                ? ScheduleFilter.failing
                : ScheduleFilter.all,
          ),
          FilterChip(
            label: const Text('Paused'),
            selected: controller.filter == ScheduleFilter.paused,
            onSelected: (on) => controller.filter = on
                ? ScheduleFilter.paused
                : ScheduleFilter.all,
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

class _Message extends StatelessWidget {
  const _Message({required this.text, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: [
          Text(text, textAlign: TextAlign.center),
          ?action,
        ],
      ),
    ),
  );
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
  });

  final CronJob job;
  final DateTime now;
  final bool showProfile;
  final bool selected;
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
      color: selected ? scheme.surfaceContainerHighest : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outline),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
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
                  Switch(
                    value: !job.isPaused && job.state != CronJobState.completed,
                    onChanged: job.state == CronJobState.completed
                        ? null
                        : (on) => onPausedChanged(!on),
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
