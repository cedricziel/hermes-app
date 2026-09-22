import 'package:flutter/material.dart';

import '../../theme/hermes_theme.dart';
import '../kanban_models.dart';

/// The app bar menu that switches boards, with a way to manage them.
class KanbanBoardMenu extends StatelessWidget {
  const KanbanBoardMenu({
    super.key,
    required this.boards,
    required this.selected,
    required this.onSelected,
    required this.onManage,
  });

  final List<KanbanBoardInfo> boards;

  /// The slug of the board on screen.
  final String? selected;
  final ValueChanged<String> onSelected;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Switch board',
      icon: const Icon(Icons.dashboard_customize_outlined),
      onSelected: (slug) => slug.isEmpty ? onManage() : onSelected(slug),
      itemBuilder: (_) => [
        for (final b in boards)
          CheckedPopupMenuItem(
            value: b.slug,
            checked: b.slug == selected,
            child: Text('${b.name} (${b.total})'),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(value: '', child: Text('Manage boards…')),
      ],
    );
  }
}

/// Whether the board's event stream is connected.
class KanbanLiveDot extends StatelessWidget {
  const KanbanLiveDot({super.key, required this.live});

  final bool live;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: live ? 'Live' : 'Reconnecting…',
    child: Icon(
      Icons.circle,
      size: 10,
      color: live
          ? context.hermesColors.success
          : context.hermesColors.subtleText,
    ),
  );
}
