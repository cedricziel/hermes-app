import 'package:flutter/material.dart';

import '../../macos/mac_toolbar.dart';
import '../../macos/mac_window.dart';
import '../../theme/app_icons.dart';
import '../kanban_models.dart';
import 'kanban_board_menu.dart';

/// The board's toolbar in a Mac window: the title with what the board shows,
/// then New Task, the profile filter, the inspector toggle, the board
/// switcher and [more].
class KanbanMacToolbar extends StatelessWidget implements PreferredSizeWidget {
  const KanbanMacToolbar({
    super.key,
    required this.taskCount,
    required this.boards,
    required this.board,
    required this.profiles,
    required this.profile,
    required this.live,
    required this.inspectorShown,
    required this.onNewTask,
    required this.onSelectBoard,
    required this.onManageBoards,
    required this.onProfileChanged,
    required this.onToggleInspector,
    this.more,
  });

  /// The tasks on screen, after the filters.
  final int taskCount;
  final List<KanbanBoardInfo> boards;

  /// The slug of the board on screen.
  final String? board;

  /// The profiles tasks are assigned to, and the one the board is narrowed
  /// to; null shows all.
  final List<String> profiles;
  final String? profile;

  final bool live;
  final bool inspectorShown;

  /// Null while there is no board to add to.
  final VoidCallback? onNewTask;
  final ValueChanged<String> onSelectBoard;
  final VoidCallback onManageBoards;
  final ValueChanged<String?> onProfileChanged;
  final VoidCallback onToggleInspector;

  /// The menu of less common board actions.
  final Widget? more;

  @override
  Size get preferredSize => const Size.fromHeight(kMacToolbarHeight);

  String get _subtitle {
    final name = boards.where((b) => b.slug == board).firstOrNull?.name;
    return [
      ?name,
      profile ?? 'all profiles',
      taskCount == 1 ? '1 task' : '$taskCount tasks',
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return MacToolbar(
      title: 'Kanban',
      subtitle: _subtitle,
      border: true,
      actions: [
        KanbanLiveDot(live: live),
        const SizedBox(width: 4),
        MacToolbarButton(
          label: 'New Task',
          shortcut: '⌘N',
          icon: AppIcons.add,
          onPressed: onNewTask,
        ),
        if (profiles.isNotEmpty)
          MacToolbarMenu<({String? profile})>(
            label: 'Filter by profile',
            icon: AppIcons.filter,
            selected: profile != null,
            onSelected: (choice) => onProfileChanged(choice.profile),
            itemBuilder: (_) => [
              CheckedPopupMenuItem(
                value: (profile: null),
                checked: profile == null,
                child: const Text('All profiles'),
              ),
              for (final p in profiles)
                CheckedPopupMenuItem(
                  value: (profile: p),
                  checked: profile == p,
                  child: Text(p),
                ),
            ],
          ),
        if (boards.isNotEmpty)
          MacToolbarMenu<String>(
            label: 'Switch board',
            icon: AppIcons.boardMenu,
            onSelected: (slug) =>
                slug.isEmpty ? onManageBoards() : onSelectBoard(slug),
            itemBuilder: (_) => kanbanBoardMenuItems(boards, board),
          ),
        const MacToolbarSeparator(),
        MacToolbarButton(
          key: const Key('kanban-inspector-toggle'),
          label: inspectorShown ? 'Hide Inspector' : 'Show Inspector',
          shortcut: '⌥⌘I',
          icon: AppIcons.inspector,
          selected: inspectorShown,
          onPressed: onToggleInspector,
        ),
        ?more,
      ],
    );
  }
}
