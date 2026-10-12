import 'package:flutter/material.dart';

import '../../../chat/widgets/relative_time.dart';
import '../../../theme/app_icons.dart';
import '../../../widgets/disclosure_tile.dart';
import '../../kanban_models.dart';
import '../../../widgets/grouped_list.dart';

/// The task's worker runs, newest first, with its log, and its history.
class KanbanTaskRuns extends StatelessWidget {
  const KanbanTaskRuns({
    super.key,
    required this.runs,
    required this.events,
    required this.taskRunning,
    required this.onTerminate,
    required this.onShowLog,
  });

  final List<KanbanRun> runs;
  final List<KanbanEvent> events;

  /// Only a running task's active run can be terminated.
  final bool taskRunning;
  final ValueChanged<KanbanRun> onTerminate;
  final VoidCallback onShowLog;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (runs.isNotEmpty)
        DisclosureTile(
          tilePadding: EdgeInsets.zero,
          title: Text('Runs (${runs.length})'),
          children: [
            GroupedSection(
              children: [
                for (final r in runs.reversed)
                  GroupedRow(
                    titleMaxLines: null,
                    subtitleMaxLines: null,
                    title:
                        '#${r.id} · ${r.profile ?? 'worker'} · '
                        '${r.active ? 'running' : (r.outcome ?? r.status)}',
                    subtitle: r.error != null || r.summary != null
                        ? r.error ?? r.summary!
                        : null,
                    separateTrailing: true,
                    trailing: r.active && taskRunning
                        ? TextButton(
                            onPressed: () => onTerminate(r),
                            child: const Text('Terminate'),
                          )
                        : null,
                  ),
                GroupedRow(
                  title: 'Worker log',
                  chevron: false,
                  onTap: onShowLog,
                  leading: const AppIcon(AppIcons.terminal),
                ),
              ],
            ),
          ],
        ),
      if (events.isNotEmpty)
        DisclosureTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('History'),
          children: [
            GroupedSection(
              children: [
                for (final e in events.reversed)
                  GroupedRow(
                    title: e.kind.replaceAll('_', ' '),
                    titleMaxLines: null,
                    value: e.createdAt == null
                        ? null
                        : relativeTime(e.createdAt!),
                  ),
              ],
            ),
          ],
        ),
    ],
  );
}
