import 'package:flutter/material.dart';

import '../../chat/widgets/relative_time.dart';
import '../../theme/app_icons.dart';
import '../../theme/platform_chrome.dart';
import '../../widgets/adaptive_popup_menu_button.dart';
import '../../widgets/grouped_list.dart';
import '../../widgets/row_actions.dart';
import '../kanban_models.dart';

/// A board in the boards list: its name, slug and task count, "Current" for
/// the open board, and a menu to rename, export, archive or delete it.
/// [removable] is false for the only board, which must stay.
class KanbanBoardRow extends StatelessWidget {
  const KanbanBoardRow({
    super.key,
    required this.board,
    required this.current,
    required this.removable,
    required this.onOpen,
    required this.onRename,
    required this.onExport,
    required this.onArchive,
    required this.onDelete,
  });

  final KanbanBoardInfo board;
  final bool current;
  final bool removable;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onExport;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => _MenuRow(
    title: board.name,
    subtitle: '${board.slug} · ${board.total} tasks',
    value: current ? 'Current' : null,
    onTap: onOpen,
    actions: [
      RowAction(label: 'Rename', icon: AppIcons.edit, onPressed: onRename),
      RowAction(label: 'Export…', icon: AppIcons.share, onPressed: onExport),
      if (removable) ...[
        RowAction(
          label: 'Archive',
          icon: AppIcons.archive,
          onPressed: onArchive,
        ),
        RowAction(
          label: 'Delete',
          icon: AppIcons.delete,
          destructive: true,
          onPressed: onDelete,
        ),
      ],
    ],
  );
}

/// A running worker: its task, the run and the profile running it, when it
/// started and last reported, and a menu to inspect or stop the process.
class KanbanWorkerRow extends StatelessWidget {
  const KanbanWorkerRow({
    super.key,
    required this.worker,
    required this.onOpen,
    required this.onInspect,
    required this.onTerminate,
  });

  final KanbanWorker worker;
  final VoidCallback onOpen;
  final VoidCallback onInspect;
  final VoidCallback onTerminate;

  @override
  Widget build(BuildContext context) {
    final w = worker;
    final times = [
      if (w.startedAt case final at?) 'started ${relativeTime(at)}',
      if (w.lastHeartbeatAt case final at?) 'heartbeat ${relativeTime(at)}',
    ];
    return _MenuRow(
      title: w.taskTitle,
      subtitle: [w.taskId, 'run #${w.runId}', ?w.profile].join(' · '),
      caption: times.isEmpty ? null : times.join(' · '),
      onTap: onOpen,
      actions: [
        RowAction(
          label: 'Inspect process',
          icon: AppIcons.info,
          onPressed: onInspect,
        ),
        RowAction(
          label: 'Terminate',
          icon: AppIcons.stop,
          destructive: true,
          onPressed: onTerminate,
        ),
      ],
    );
  }
}

/// A [GroupedRow] that opens on tap and offers its [actions] in a trailing
/// menu, plus the platform's own way: a swipe or long press on iOS, a right
/// click on the Mac.
class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.actions,
    this.caption,
    this.value,
  });

  final String title;
  final String subtitle;
  final String? caption;
  final String? value;
  final VoidCallback onTap;
  final List<RowAction> actions;

  @override
  Widget build(BuildContext context) {
    final mac = platformChromeOf(context) == PlatformChrome.macos;
    return RowActions(
      title: title,
      actions: actions,
      child: GroupedRow(
        title: title,
        subtitle: subtitle,
        caption: caption,
        value: value,
        onTap: onTap,
        trailing: AdaptivePopupMenuButton<RowAction>(
          padding: EdgeInsets.all(mac ? 2 : 8),
          icon: mac ? const AppIcon(AppIcons.more, size: 16) : null,
          onSelected: (action) => action.onPressed(),
          itemBuilder: (_) => [
            for (final action in actions)
              AdaptiveMenuItem(
                value: action,
                destructive: action.destructive,
                child: Text(action.label),
              ),
          ],
        ),
      ),
    );
  }
}
