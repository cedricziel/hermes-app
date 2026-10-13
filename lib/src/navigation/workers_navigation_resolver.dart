import 'package:flutter/material.dart';

import '../api/hermes_repositories.dart';
import '../kanban/kanban_workers_screen.dart';
import 'desktop_navigation_history.dart';

Future<Route<void>?> resolveWorkersNavigation(
  WorkersNavigationTarget target,
  HermesRepositories repositories,
  bool Function() canNavigate,
) async {
  if (!canNavigate() ||
      !await repositories.plugins.isKanbanEnabled() ||
      !canNavigate()) {
    return null;
  }
  final board = target.boardSlug;
  final boards = await repositories.kanban.listBoards();
  if (!canNavigate() ||
      (board != null && !boards.any((b) => b.slug == board))) {
    return null;
  }
  return MaterialPageRoute<void>(
    settings: RouteSettings(arguments: target),
    builder: (_) =>
        KanbanWorkersScreen(repository: repositories.kanban, board: board),
  );
}
