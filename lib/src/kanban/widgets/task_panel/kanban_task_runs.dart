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
        _Disclosure(
          title: 'Runs (${runs.length})',
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
        _Disclosure(
          title: 'History',
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

/// An [ExpansionTile] whose header screen readers announce as a button that
/// is open or closed; the tile itself only gives a hint, which macOS drops.
class _Disclosure extends StatefulWidget {
  const _Disclosure({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  State<_Disclosure> createState() => _DisclosureState();
}

class _DisclosureState extends State<_Disclosure> {
  var _open = false;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    tilePadding: EdgeInsets.zero,
    onExpansionChanged: (open) => setState(() => _open = open),
    title: Semantics(button: true, expanded: _open, child: Text(widget.title)),
    children: widget.children,
  );
}
