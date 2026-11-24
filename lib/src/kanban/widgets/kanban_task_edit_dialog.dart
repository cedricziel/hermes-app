import 'package:flutter/material.dart';
import 'package:hermes_app/l10n/l10n.dart';

import '../../widgets/grouped_dialog.dart';
import '../kanban_models.dart';
import 'kanban_task_edit_fields.dart';

class KanbanTaskEditDialog extends StatefulWidget {
  const KanbanTaskEditDialog({super.key, required this.task});

  final KanbanTask task;

  @override
  State<KanbanTaskEditDialog> createState() => _KanbanTaskEditDialogState();
}

class _KanbanTaskEditDialogState extends State<KanbanTaskEditDialog> {
  late final _title = TextEditingController(text: widget.task.title);
  late final _body = TextEditingController(text: widget.task.body ?? '');

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GroupedDialog(
      title: l10n.kanbanEditTaskTitle,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.widgetsCancel),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, (_title.text.trim(), _body.text.trim())),
          child: Text(l10n.kanbanSaveAction),
        ),
      ],
      children: [KanbanTaskEditFields(title: _title, body: _body)],
    );
  }
}
