import 'package:flutter/material.dart';

import '../../kanban_models.dart';
import '../../kanban_repository.dart';

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
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          children: [
            ActionChip(
              avatar: const Icon(Icons.person_outline, size: 16),
              label: Text(task.assignee ?? 'Unassigned'),
              onPressed: onAssign,
            ),
            ActionChip(
              avatar: const Icon(Icons.flag_outlined, size: 16),
              label: Text(task.priority == 0 ? 'Normal' : 'P${task.priority}'),
              onPressed: onPrioritise,
            ),
            if (task.tenant != null) Chip(label: Text(task.tenant!)),
            PopupMenuButton<String>(
              tooltip: 'Move to',
              onSelected: onMove,
              itemBuilder: (_) => [
                for (final s in kanbanSettableStatuses)
                  if (s != task.status)
                    PopupMenuItem(value: s, child: Text(kanbanStatusLabel(s))),
              ],
              child: const Chip(
                avatar: Icon(Icons.swap_horiz, size: 16),
                label: Text('Move to…'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
