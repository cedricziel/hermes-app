import 'package:flutter/material.dart';

import '../../widgets/grouped_dialog.dart';
import 'kanban_worker_log.dart';
import '../kanban_models.dart';
import '../kanban_repository.dart';

/// The tail of a task's worker log.
class KanbanTaskLogDialog extends StatefulWidget {
  const KanbanTaskLogDialog({
    super.key,
    required this.repository,
    required this.taskId,
    this.board,
  });

  final KanbanRepository repository;
  final String taskId;
  final String? board;

  @override
  State<KanbanTaskLogDialog> createState() => _KanbanTaskLogDialogState();
}

class _KanbanTaskLogDialogState extends State<KanbanTaskLogDialog> {
  KanbanTaskLog? _log;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    widget.repository
        .loadTaskLog(widget.taskId, board: widget.board)
        .then((log) {
          if (mounted) setState(() => _log = log);
        })
        .catchError((_) {
          if (mounted) setState(() => _failed = true);
        });
  }

  @override
  Widget build(BuildContext context) {
    return GroupedDialog(
      title: 'Log · ${widget.taskId}',
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
      children: [KanbanWorkerLog(log: _log, failed: _failed)],
    );
  }
}
