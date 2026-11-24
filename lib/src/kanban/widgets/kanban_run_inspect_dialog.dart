import 'package:flutter/material.dart';

import '../../widgets/adaptive_dialog.dart';
import '../kanban_models.dart';

/// What the dispatcher's worker process for run [runId] looks like right now:
/// its figures while it runs, or that it is gone. Its Close button pops the
/// dialog's own route.
class KanbanRunInspectDialog extends StatelessWidget {
  const KanbanRunInspectDialog({
    super.key,
    required this.runId,
    required this.inspection,
  });

  final int runId;
  final KanbanRunInspection inspection;

  @override
  Widget build(BuildContext context) {
    final i = inspection;
    return AppAlertDialog(
      title: Text('Run #$runId'),
      content: Text(
        i.alive
            ? [
                if (i.pid != null) 'Process ${i.pid}',
                if (i.status != null) 'Status: ${i.status}',
                if (i.memoryBytes != null)
                  'Memory: ${(i.memoryBytes! / (1024 * 1024)).toStringAsFixed(0)} MB',
                if (i.threads != null) 'Threads: ${i.threads}',
                if (i.note != null) i.note!,
              ].join('\n')
            : 'The process is not running${i.note == null ? '' : ': ${i.note}'}.',
      ),
      actions: [
        AppDialogAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
