import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../widgets/grouped_dialog.dart';
import '../../widgets/grouped_form.dart';
import '../../widgets/grouped_list.dart';
import '../kanban_transfer_options.dart';

/// Asks what to put in the archive of the board [name]. Pops the chosen
/// [KanbanExportOptions] for Export and null for Cancel from its own route.
/// The initial values only seed the fields, so a catalog can show each state.
class KanbanBoardExportDialog extends StatefulWidget {
  const KanbanBoardExportDialog({
    super.key,
    required this.name,
    this.initialOutput = '',
    this.initialAttachments = true,
    this.initialLogs = false,
  });

  final String name;
  final String initialOutput;
  final bool initialAttachments;
  final bool initialLogs;

  @override
  State<KanbanBoardExportDialog> createState() =>
      _KanbanBoardExportDialogState();
}

class _KanbanBoardExportDialogState extends State<KanbanBoardExportDialog> {
  late final _output = TextEditingController(text: widget.initialOutput);
  late bool _attachments = widget.initialAttachments;
  late bool _logs = widget.initialLogs;

  @override
  void dispose() {
    _output.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GroupedDialog(
      title: l10n.kanbanExportTitle(widget.name),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.widgetsCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop<KanbanExportOptions>(context, (
            output: _output.text.trim(),
            attachments: _attachments,
            logs: _logs,
          )),
          child: Text(l10n.kanbanExportAction),
        ),
      ],
      children: [
        GroupedSection(
          footer: l10n.kanbanExportFooter,
          children: [
            GroupedTextFieldRow(
              label: l10n.kanbanExportPathLabel,
              hint: l10n.kanbanExportPathHint,
              controller: _output,
            ),
          ],
        ),
        GroupedSection(
          children: [
            GroupedSwitchRow(
              title: l10n.kanbanExportAttachments,
              value: _attachments,
              onTap: () => setState(() => _attachments = !_attachments),
              onChanged: (value) => setState(() => _attachments = value),
            ),
            GroupedSwitchRow(
              title: l10n.kanbanExportLogs,
              value: _logs,
              onTap: () => setState(() => _logs = !_logs),
              onChanged: (value) => setState(() => _logs = value),
            ),
          ],
        ),
      ],
    );
  }
}
