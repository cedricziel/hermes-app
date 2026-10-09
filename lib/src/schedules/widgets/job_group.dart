import 'package:flutter/material.dart';

import '../../widgets/grouped_list.dart';
import '../../widgets/row_actions.dart';
import '../schedule_models.dart';
import '../schedules_list.dart';

/// The jobs as the rows of one inset group, the selected one marked. On iOS
/// a row swipes to delete and a long press opens its actions; on macOS a
/// right click does.
class JobGroup extends StatelessWidget {
  const JobGroup({
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
  Widget build(BuildContext context) => GroupedSection(
    children: [for (final job in jobs) _row(job, actionsFor?.call(job))],
  );

  Widget _row(CronJob job, List<RowAction>? actions) {
    final tile = JobTile(
      job: job,
      now: now,
      showProfile: showProfile,
      selected: job.key == selectedKey,
      onTap: () => onSelect(job),
      onPausedChanged: (paused) => onPausedChanged(job, paused),
    );
    return actions == null
        ? tile
        : RowActions(title: job.title, actions: actions, child: tile);
  }
}
