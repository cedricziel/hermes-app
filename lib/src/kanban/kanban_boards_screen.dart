import 'package:flutter/material.dart';

import 'kanban_board_controller.dart';
import 'kanban_errors.dart';
import 'kanban_models.dart';
import 'kanban_repository.dart';

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
    final options = await showDialog<_ExportOptions>(
      context: context,
      builder: (_) => _ExportDialog(name: name),
    );
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
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Board exported'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('The archive is on the server, at:'),
            const SizedBox(height: 8),
            SelectableText(exported.archive),
            const SizedBox(height: 8),
            Text('${(exported.size / 1024).toStringAsFixed(1)} KB'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _import(BuildContext context) async {
    final options = await showDialog<_ImportOptions>(
      context: context,
      builder: (_) => const _ImportDialog(),
    );
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
      if (context.mounted) Navigator.pop(context);
      await controller.selectBoard(result!.board);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text('Boards'),
          actions: [
            IconButton(
              tooltip: 'Import a board',
              icon: const Icon(Icons.file_open_outlined),
              onPressed: () => _import(context),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _create(context),
          icon: const Icon(Icons.add),
          label: const Text('New board'),
        ),
        body: ListView(
          children: [
            for (final b in controller.boards)
              ListTile(
                leading: Icon(
                  b.slug == controller.boardSlug
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                ),
                title: Text(b.name),
                subtitle: Text('${b.slug} · ${b.total} tasks'),
                onTap: () {
                  controller.selectBoard(b.slug);
                  Navigator.pop(context);
                },
                trailing: PopupMenuButton<String>(
                  onSelected: (action) => switch (action) {
                    'rename' => _rename(context, b.slug, b.name),
                    'export' => _export(context, b.slug, b.name),
                    'archive' => _remove(context, b.slug, b.name, hard: false),
                    _ => _remove(context, b.slug, b.name, hard: true),
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'rename', child: Text('Rename')),
                    const PopupMenuItem(
                      value: 'export',
                      child: Text('Export…'),
                    ),
                    if (controller.boards.length > 1) ...const [
                      PopupMenuItem(value: 'archive', child: Text('Archive')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

typedef _ExportOptions = ({String output, bool attachments, bool logs});

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
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Export ${widget.name}'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'The archive is written on the server, not on this device.',
          ),
          TextField(
            controller: _output,
            decoration: const InputDecoration(
              labelText: 'Server path (optional)',
              helperText: 'Empty uses the server’s export folder',
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Include attachments'),
            value: _attachments,
            onChanged: (v) => setState(() => _attachments = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Include worker logs'),
            value: _logs,
            onChanged: (v) => setState(() => _logs = v),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop<_ExportOptions>(context, (
          output: _output.text.trim(),
          attachments: _attachments,
          logs: _logs,
        )),
        child: const Text('Export'),
      ),
    ],
  );
}

typedef _ImportOptions = ({String archive, String slug, bool open});

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
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Import a board'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('The archive must already be on the server.'),
          TextField(
            controller: _archive,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Archive path on the server',
            ),
            onChanged: (_) => setState(() {}),
          ),
          TextField(
            controller: _slug,
            decoration: const InputDecoration(
              labelText: 'New board slug (optional)',
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Open it afterwards'),
            value: _open,
            onChanged: (v) => setState(() => _open = v),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _archive.text.trim().isEmpty
            ? null
            : () => Navigator.pop<_ImportOptions>(context, (
                archive: _archive.text.trim(),
                slug: _slug.text.trim(),
                open: _open,
              )),
        child: const Text('Import'),
      ),
    ],
  );
}
