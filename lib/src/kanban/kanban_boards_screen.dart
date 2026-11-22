import 'package:flutter/material.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/widgets/dialog_presentation.dart';
import 'package:hermes_app/src/widgets/adaptive_dialog.dart';

import '../theme/app_icons.dart';
import 'kanban_board_controller.dart';
import 'kanban_errors.dart';
import 'kanban_models.dart';
import 'kanban_repository.dart';
import 'widgets/kanban_list_rows.dart';
import '../widgets/grouped_list.dart';
import '../widgets/grouped_dialog.dart';
import '../widgets/grouped_form.dart';
import '../widgets/settings_scaffold.dart';
import '../widgets/route_dismissal.dart';

/// Lists the plugin's boards; opens, creates, renames, archives or deletes them.
class KanbanBoardsScreen extends StatelessWidget {
  const KanbanBoardsScreen({
    super.key,
    required this.controller,
    required this.repository,
  });

  final KanbanBoardController controller;
  final KanbanRepository repository;

  /// `Ops team!` becomes `ops-team`, the shape the plugin accepts for a slug.
  static String slugFor(String name) => name
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  Future<void> _create(BuildContext context) async {
    final name = await askKanbanText(
      context,
      title: 'New board',
      hint: 'Name',
      confirm: 'Create',
    );
    if (name == null || name.isEmpty || !context.mounted) return;
    final slug = slugFor(name);
    if (slug.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Use letters or numbers in the board name.'),
        ),
      );
      return;
    }
    final ok = await runKanbanAction(
      context,
      () => repository.createBoard(slug: slug, name: name),
    );
    if (ok) await controller.loadBoards();
  }

  Future<void> _rename(
    BuildContext context,
    String slug,
    String current,
  ) async {
    final name = await askKanbanText(
      context,
      title: 'Rename board',
      initial: current,
      confirm: 'Rename',
    );
    if (name == null || name.isEmpty || name == current || !context.mounted) {
      return;
    }
    final ok = await runKanbanAction(
      context,
      () => repository.renameBoard(slug, name: name),
    );
    if (ok) await controller.loadBoards();
  }

  Future<void> _remove(
    BuildContext context,
    String slug,
    String name, {
    required bool hard,
  }) async {
    final confirmed = await confirmKanban(
      context,
      title: hard ? 'Delete “$name” for good?' : 'Archive “$name”?',
      confirm: hard ? 'Delete' : 'Archive',
    );
    if (!confirmed || !context.mounted) return;
    final ok = await runKanbanAction(
      context,
      () => repository.removeBoard(slug, hardDelete: hard),
    );
    if (ok) await controller.loadBoards();
  }

  Future<void> _export(BuildContext context, String slug, String name) async {
    final options = await showKanbanExportDialog(context, name: name);
    if (options == null || !context.mounted) return;
    KanbanExport? result;
    final ok = await runKanbanAction(
      context,
      () async => result = await repository.exportBoard(
        slug,
        output: options.output,
        attachments: options.attachments,
        logs: options.logs,
      ),
    );
    if (!ok || result == null || !context.mounted) return;
    final exported = result!;
    await showAppDialog<void>(
      context: context,
      builder: (context) => AppAlertDialog(
        title: const Text('Board exported'),
        // A path is data: the whole block lines up at the start on every
        // platform, where an Apple alert would centre only the wrapped lines.
        content: DefaultTextStyle.merge(
          textAlign: TextAlign.start,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('The archive is on the server, at:'),
              const SizedBox(height: 8),
              SelectableText(exported.archive),
              const SizedBox(height: 8),
              Text('${(exported.size / 1024).toStringAsFixed(1)} KB'),
            ],
          ),
        ),
        actions: [
          AppDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _import(BuildContext context) async {
    final options = await showKanbanImportDialog(context);
    if (options == null || !context.mounted) return;
    KanbanImport? result;
    final ok = await runKanbanAction(
      context,
      () async => result = await repository.importBoard(
        options.archive,
        slug: options.slug.isEmpty ? null : options.slug,
      ),
    );
    if (!ok || result == null) return;
    await controller.loadBoards();
    if (context.mounted && result!.renamed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'That name was taken, so the board is ${result!.board}.',
          ),
        ),
      );
    }
    if (options.open && result!.board.isNotEmpty) {
      // Opened here, not by the server: `switch` on the import would also
      // make it the server's current board for the CLI and other clients.
      if (context.mounted) dismissRoute(context);
      await controller.selectBoard(result!.board);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final boards = controller.boards;
        final removable = boards.length > 1;
        return SettingsScaffold(
          title: 'Boards',
          subtitle: boards.length == 1 ? '1 board' : '${boards.length} boards',
          previousTitle: 'Kanban',
          actions: [
            SettingsBarAction(
              label: 'Import a board',
              icon: AppIcons.openFile,
              onPressed: () => _import(context),
            ),
            SettingsBarAction(
              label: 'New board',
              icon: AppIcons.add,
              onPressed: () => _create(context),
            ),
          ],
          body: GroupedListView(
            children: [
              if (boards.isNotEmpty)
                GroupedSection(
                  children: [
                    for (final b in boards)
                      KanbanBoardRow(
                        board: b,
                        current: b.slug == controller.boardSlug,
                        onOpen: () {
                          controller.selectBoard(b.slug);
                          Navigator.pop(context);
                        },
                        onRename: () => _rename(context, b.slug, b.name),
                        onExport: () => _export(context, b.slug, b.name),
                        removable: removable,
                        onArchive: () =>
                            _remove(context, b.slug, b.name, hard: false),
                        onDelete: () =>
                            _remove(context, b.slug, b.name, hard: true),
                      ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Asks what to put in the archive of the board [name].
Future<KanbanExportOptions?> showKanbanExportDialog(
  BuildContext context, {
  required String name,
}) => showKanbanDialog<KanbanExportOptions>(
  context,
  textEntry: true,
  builder: (_) => _ExportDialog(name: name),
);

typedef KanbanExportOptions = ({String output, bool attachments, bool logs});

class _ExportDialog extends StatefulWidget {
  const _ExportDialog({required this.name});

  final String name;

  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  final _output = TextEditingController();
  bool _attachments = true;
  bool _logs = false;

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

/// Asks which server-side archive to import and how to name the board.
Future<KanbanImportOptions?> showKanbanImportDialog(BuildContext context) =>
    showKanbanDialog<KanbanImportOptions>(
      context,
      textEntry: true,
      builder: (_) => const _ImportDialog(),
    );

typedef KanbanImportOptions = ({String archive, String slug, bool open});

class _ImportDialog extends StatefulWidget {
  const _ImportDialog();

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  final _archive = TextEditingController();
  final _slug = TextEditingController();
  bool _open = true;

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
