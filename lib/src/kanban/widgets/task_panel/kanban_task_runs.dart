import 'package:flutter/material.dart';

import '../../../chat/widgets/relative_time.dart';
import '../../kanban_models.dart';

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
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text('Runs (${runs.length})'),
          children: [
            for (final r in runs.reversed)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '#${r.id} · ${r.profile ?? 'worker'} · '
                  '${r.active ? 'running' : (r.outcome ?? r.status)}',
                ),
                subtitle: r.error != null || r.summary != null
                    ? Text(r.error ?? r.summary!)
                    : null,
                trailing: r.active && taskRunning
                    ? TextButton(
                        onPressed: () => onTerminate(r),
                        child: const Text('Terminate'),
                      )
                    : null,
              ),
            TextButton.icon(
              onPressed: onShowLog,
              icon: const Icon(Icons.terminal),
              label: const Text('Worker log'),
            ),
          ],
        ),
      if (events.isNotEmpty)
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('History'),
          children: [
            for (final e in events.reversed)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(e.kind.replaceAll('_', ' ')),
                trailing: e.createdAt == null
                    ? null
                    : Text(relativeTime(e.createdAt!)),
              ),
          ],
        ),
    ],
  );
}
