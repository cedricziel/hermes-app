import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../macos/mac_toolbar.dart';
import '../../macos/mac_window.dart';
import '../../theme/app_icons.dart';
import '../kanban_models.dart';
import 'kanban_board_menu.dart';

/// The board's toolbar in a Mac window: the title with what the board shows,
/// then New Task, Refresh, the profile filter, the inspector toggle, the board
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
    required this.onRefresh,
    this.refreshing = false,
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
  final VoidCallback onRefresh;

  /// Shows a spinner on Refresh while the board reloads.
  final bool refreshing;

  /// The menu of less common board actions.
  final Widget? more;

  @override
  Size get preferredSize => const Size.fromHeight(kMacToolbarHeight);

  String _subtitle(AppLocalizations l10n) {
    final name = boards.where((b) => b.slug == board).firstOrNull?.name;
    return [
      ?name,
      profile ?? l10n.kanbanMacSubtitleAllProfiles,
      l10n.kanbanBoardsTaskCount(taskCount),
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return MacToolbar(
      title: l10n.kanbanTitle,
      subtitle: _subtitle(l10n),
      border: true,
      actions: [
        KanbanLiveDot(live: live),
        const SizedBox(width: 4),
        MacToolbarButton(
          label: l10n.macosMenuNewTask,
          shortcut: '⌘N',
          icon: AppIcons.add,
          onPressed: onNewTask,
        ),
        MacToolbarButton(
          key: const Key('kanban-refresh'),
          label: context.l10n.kanbanRefreshAction,
          shortcut: '⌘R',
          icon: AppIcons.refresh,
          busy: refreshing,
          onPressed: onRefresh,
        ),
        if (profiles.isNotEmpty)
          MacToolbarMenu<({String? profile})>(
            label: l10n.kanbanMacFilterByProfile,
            icon: AppIcons.filter,
            selected: profile != null,
            onSelected: (choice) => onProfileChanged(choice.profile),
            itemBuilder: (_) => [
              CheckedPopupMenuItem(
                value: (profile: null),
                checked: profile == null,
                child: Text(l10n.kanbanMacAllProfiles),
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
            label: l10n.kanbanBoardSwitch,
            icon: AppIcons.boardMenu,
            onSelected: (slug) =>
                slug.isEmpty ? onManageBoards() : onSelectBoard(slug),
            itemBuilder: (_) => kanbanBoardMenuItems(l10n, boards, board),
          ),
        const MacToolbarSeparator(),
        MacToolbarButton(
          key: const Key('kanban-inspector-toggle'),
          label: inspectorShown
              ? l10n.chatActivityInspectorHide
              : l10n.chatActivityInspectorShow,
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
