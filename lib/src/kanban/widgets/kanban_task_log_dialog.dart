import 'package:flutter/material.dart';

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
    final log = _log;
    final String text;
    if (log == null) {
      text = _failed ? 'Could not load the log.' : 'Loading…';
    } else if (!log.exists) {
      text = 'No worker has run this task yet.';
    } else {
      text = log.content.isEmpty ? '(empty)' : log.content;
    }
    return AlertDialog(
      title: Text('Log · ${widget.taskId}'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          reverse: true,
          child: SelectableText(
            log?.truncated == true ? '… (earlier output cut)\n$text' : text,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
