import 'package:flutter/material.dart';

import '../../../widgets/grouped_form.dart';
import '../../../widgets/grouped_list.dart';

import '../../../theme/hermes_theme.dart';
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
    final subtle = theme.colorScheme.onSurface.withValues(
      alpha: kHermesMutedAlpha,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
        GroupedSection(
          children: [
            GroupedValueRow(
              title: 'Assignee',
              value: task.assignee ?? 'Unassigned',
              onTap: onAssign,
            ),
            GroupedValueRow(
              title: 'Priority',
              value: task.priority == 0 ? 'Normal' : 'P${task.priority}',
              onTap: onPrioritise,
            ),
            if (task.tenant != null)
              GroupedValueRow(title: 'Tenant', value: task.tenant!),
            GroupedMenuRow<String>(
              title: 'Move to…',
              options: [
                for (final s in kanbanSettableStatuses)
                  if (s != task.status) s,
              ],
              labelOf: kanbanStatusLabel,
              selected: null,
              placeholder: kanbanStatusLabel(task.status),
              onSelected: onMove,
            ),
          ],
        ),
      ],
    );
  }
}
