import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
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
    final l10n = context.l10n;
    return AppAlertDialog(
      title: Text(l10n.kanbanInspectTitle(runId)),
      content: Text(
        i.alive
            ? [
                if (i.pid != null) l10n.kanbanInspectProcess(i.pid!),
                if (i.status != null) l10n.kanbanInspectStatus(i.status!),
                if (i.memoryBytes != null)
                  l10n.kanbanInspectMemory(
                    (i.memoryBytes! / (1024 * 1024)).toStringAsFixed(0),
                  ),
                if (i.threads != null) l10n.kanbanInspectThreads(i.threads!),
                if (i.note != null) i.note!,
              ].join('\n')
            : i.note == null
            ? l10n.kanbanInspectGone
            : l10n.kanbanInspectGoneNote(i.note!),
      ),
      actions: [
        AppDialogAction(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.kanbanInspectClose),
        ),
      ],
    );
  }
}
