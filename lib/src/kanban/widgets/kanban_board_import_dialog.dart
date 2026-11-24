import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../widgets/grouped_dialog.dart';
import '../../widgets/grouped_form.dart';
import '../../widgets/grouped_list.dart';
import '../kanban_transfer_options.dart';

/// Asks which server-side archive to import and how to name the board. Pops
/// the chosen [KanbanImportOptions] for Import (off until an archive path is
/// typed) and null for Cancel from its own route. The initial values only seed
/// the fields, so a catalog can show each state.
class KanbanBoardImportDialog extends StatefulWidget {
  const KanbanBoardImportDialog({
    super.key,
    this.initialArchive = '',
    this.initialSlug = '',
    this.initialOpen = true,
  });

  final String initialArchive;
  final String initialSlug;
  final bool initialOpen;

  @override
  State<KanbanBoardImportDialog> createState() =>
      _KanbanBoardImportDialogState();
}

class _KanbanBoardImportDialogState extends State<KanbanBoardImportDialog> {
  late final _archive = TextEditingController(text: widget.initialArchive);
  late final _slug = TextEditingController(text: widget.initialSlug);
  late bool _open = widget.initialOpen;

  @override
  void dispose() {
    _archive.dispose();
    _slug.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GroupedDialog(
      title: l10n.kanbanImportTitle,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.widgetsCancel),
        ),
        FilledButton(
          onPressed: _archive.text.trim().isEmpty
              ? null
              : () => Navigator.pop<KanbanImportOptions>(context, (
                  archive: _archive.text.trim(),
                  slug: _slug.text.trim(),
                  open: _open,
                )),
          child: Text(l10n.kanbanImportAction),
        ),
      ],
      children: [
        GroupedSection(
          footer: l10n.kanbanImportFooter,
          children: [
            GroupedTextFieldRow(
              label: l10n.kanbanImportArchiveLabel,
              controller: _archive,
              autofocus: true,
              onChanged: (_) => setState(() {}),
            ),
            GroupedTextFieldRow(
              label: l10n.kanbanImportSlugLabel,
              hint: l10n.kanbanImportSlugHint,
              controller: _slug,
            ),
          ],
        ),
        GroupedSection(
          children: [
            GroupedSwitchRow(
              title: l10n.kanbanImportOpenAfter,
              value: _open,
              onTap: () => setState(() => _open = !_open),
              onChanged: (value) => setState(() => _open = value),
            ),
          ],
        ),
      ],
    );
  }
}
