import 'package:intl/intl.dart' show NumberFormat;
import 'package:material_ui/material_ui.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/widgets/dialog_presentation.dart';
import 'package:hermes_app/src/widgets/adaptive_dialog.dart';

import '../theme/app_icons.dart';
import 'kanban_board_controller.dart';
import 'kanban_errors.dart';
import 'kanban_models.dart';
import 'kanban_repository.dart';
import 'kanban_transfer_options.dart';
import 'widgets/kanban_board_export_dialog.dart';
import 'widgets/kanban_board_import_dialog.dart';
import 'widgets/kanban_list_rows.dart';
import '../widgets/grouped_list.dart';
import '../widgets/settings_scaffold.dart';
import '../widgets/route_dismissal.dart';

export 'kanban_transfer_options.dart';

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
      title: context.l10n.kanbanBoardsNew,
      hint: context.l10n.kanbanBoardsNameHint,
      confirm: context.l10n.kanbanBoardsCreate,
    );
    if (name == null || name.isEmpty || !context.mounted) return;
    final slug = slugFor(name);
    if (slug.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.kanbanBoardsNameInvalid)),
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
      title: context.l10n.kanbanBoardsRenameTitle,
      initial: current,
      confirm: context.l10n.kanbanBoardsRename,
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
      title: hard
          ? context.l10n.kanbanBoardsDeleteTitle(name)
          : context.l10n.kanbanBoardsArchiveTitle(name),
      confirm: hard ? context.l10n.kanbanDelete : context.l10n.kanbanArchive,
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
        title: Text(context.l10n.kanbanBoardsExportedTitle),
        // A path is data: the whole block lines up at the start on every
        // platform, where an Apple alert would centre only the wrapped lines.
        content: DefaultTextStyle.merge(
          textAlign: TextAlign.start,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(context.l10n.kanbanBoardsExportedLocation),
              const SizedBox(height: 8),
              SelectableText(exported.archive),
              const SizedBox(height: 8),
              Text(
                context.l10n.kanbanBoardsExportedSize(
                  NumberFormat(
                    '0.0',
                    context.l10n.localeName,
                  ).format(exported.size / 1024),
                ),
              ),
            ],
          ),
        ),
        actions: [
          AppDialogAction(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.kanbanBoardsExportedClose),
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
          content: Text(context.l10n.kanbanBoardsImportRenamed(result!.board)),
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
          title: context.l10n.kanbanBoardsTitle,
          subtitle: context.l10n.kanbanBoardsCount(boards.length),
          previousTitle: context.l10n.kanbanBoardsPreviousTitle,
          actions: [
            SettingsBarAction(
              label: context.l10n.kanbanImportTitle,
              icon: AppIcons.openFile,
              onPressed: () => _import(context),
            ),
            SettingsBarAction(
              label: context.l10n.kanbanBoardsNew,
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
  builder: (_) => KanbanBoardExportDialog(name: name),
);

/// Asks which server-side archive to import and how to name the board.
Future<KanbanImportOptions?> showKanbanImportDialog(BuildContext context) =>
    showKanbanDialog<KanbanImportOptions>(
      context,
      textEntry: true,
      builder: (_) => const KanbanBoardImportDialog(),
    );
