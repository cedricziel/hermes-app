import 'package:flutter/material.dart';

import '../../widgets/row_actions.dart';
import '../schedule_models.dart';
import '../schedules_list.dart';

/// The job list column of a Mac window: each job a rounded row of its own,
/// 8 points apart, the selected one marked. A right click opens the row's
/// actions.
class MacJobList extends StatelessWidget {
  const MacJobList({
    super.key,
    required this.jobs,
    required this.now,
    required this.onSelect,
    required this.onPausedChanged,
    this.actionsFor,
    this.selectedKey,
    this.showProfile = false,
  });

  final List<CronJob> jobs;
  final DateTime now;
  final ValueChanged<CronJob> onSelect;
  final void Function(CronJob job, bool paused) onPausedChanged;
  final List<RowAction> Function(CronJob job)? actionsFor;
  final String? selectedKey;

  /// Names each job's profile, for a list of every profile's jobs.
  final bool showProfile;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: jobs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final job = jobs[i];
        final tile = Material(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: JobTile(
            job: job,
            now: now,
            showProfile: showProfile,
            selected: job.key == selectedKey,
            grouped: true,
            onTap: () => onSelect(job),
            onPausedChanged: (paused) => onPausedChanged(job, paused),
          ),
        );
        final actions = actionsFor?.call(job);
        return actions == null
            ? tile
            : RowActions(title: job.title, actions: actions, child: tile);
      },
    );
  }
}
