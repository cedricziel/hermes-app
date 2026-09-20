import 'package:flutter/material.dart';

import 'kanban_board_controller.dart';
import 'kanban_errors.dart';
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Boards')),
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
                    'archive' => _remove(context, b.slug, b.name, hard: false),
                    _ => _remove(context, b.slug, b.name, hard: true),
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'rename', child: Text('Rename')),
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
