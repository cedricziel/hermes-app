import 'package:material_ui/material_ui.dart';

import '../../../../l10n/l10n.dart';

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
    final l10n = context.l10n;
    final subtle = theme.colorScheme.onSurface.withValues(
      alpha: kHermesMutedAlpha,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${task.id} · ${kanbanStatusLabel(l10n, task.status)}',
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
              label: l10n.kanbanTaskEdit,
              icon: AppIcons.edit,
              onPressed: onEdit,
            ),
          ],
        ),
        GroupedSection(
          children: [
            GroupedValueRow(
              title: l10n.kanbanTaskAssignee,
              value: task.assignee ?? l10n.kanbanTaskUnassigned,
              onTap: onAssign,
            ),
            GroupedValueRow(
              title: l10n.kanbanBulkPriorityTitle,
              value: task.priority == 0
                  ? l10n.kanbanBulkPriorityNormal
                  : l10n.kanbanTaskPriorityLevel(task.priority),
              onTap: onPrioritise,
            ),
            if (task.tenant != null)
              GroupedValueRow(
                title: l10n.kanbanTaskTenant,
                value: task.tenant!,
              ),
            GroupedMenuRow<String>(
              title: l10n.kanbanTaskMoveTo,
              options: [
                for (final s in kanbanSettableStatuses)
                  if (s != task.status) s,
              ],
              labelOf: (s) => kanbanStatusLabel(l10n, s),
              selected: null,
              placeholder: kanbanStatusLabel(l10n, task.status),
              onSelected: onMove,
            ),
          ],
        ),
      ],
    );
  }
}
