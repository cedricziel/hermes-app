import 'package:flutter/material.dart';
import 'package:hermes_app/src/widgets/adaptive_popup_menu_button.dart';

import '../../../theme/app_icons.dart';
import '../../kanban_models.dart';
import '../../kanban_repository.dart';
import '../../../widgets/named_icon_button.dart';

/// The top of the task panel: id and status, title, assignee, priority,
/// tenant and a menu to move the task.
class KanbanTaskHeader extends StatelessWidget {
  const KanbanTaskHeader({
    super.key,
    required this.task,
    required this.onEdit,
    required this.onAssign,
    required this.onPrioritise,
    required this.onMove,
  });

  final KanbanTask task;
  final VoidCallback onEdit;
  final VoidCallback onAssign;
  final VoidCallback onPrioritise;
  final ValueChanged<String> onMove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtle = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${task.id} · ${kanbanStatusLabel(task.status)}',
          style: theme.textTheme.bodySmall?.copyWith(color: subtle),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(task.title, style: theme.textTheme.titleLarge),
            ),
            NamedIconButton(
              label: 'Edit',
              icon: AppIcons.edit,
              onPressed: onEdit,
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          children: [
            ActionChip(
              avatar: const AppIcon(AppIcons.person, size: 16),
              label: Text(task.assignee ?? 'Unassigned'),
              onPressed: onAssign,
            ),
            ActionChip(
              avatar: const AppIcon(AppIcons.flag, size: 16),
              label: Text(task.priority == 0 ? 'Normal' : 'P${task.priority}'),
              onPressed: onPrioritise,
            ),
            if (task.tenant != null) Chip(label: Text(task.tenant!)),
            MergeSemantics(
              child: Semantics(
                button: true,
                child: AdaptivePopupMenuButton<String>(
                  // The chip already says it; a tooltip would be read twice.
                  tooltip: '',
                  onSelected: onMove,
                  itemBuilder: (_) => [
                    for (final s in kanbanSettableStatuses)
                      if (s != task.status)
                        PopupMenuItem(
                          value: s,
                          child: Text(kanbanStatusLabel(s)),
                        ),
                  ],
                  child: const Chip(
                    avatar: AppIcon(AppIcons.swap, size: 16),
                    label: Text('Move to…'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
