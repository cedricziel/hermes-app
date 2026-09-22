import 'package:flutter/material.dart';

import '../../../theme/hermes_theme.dart';
import '../../kanban_models.dart';
import 'kanban_task_heading.dart';

/// What the task says: diagnostics, description, result, dependencies and
/// subtasks.
class KanbanTaskFields extends StatelessWidget {
  const KanbanTaskFields({
    super.key,
    required this.detail,
    required this.onAddParent,
    required this.onRemoveParent,
  });

  final KanbanTaskDetail detail;
  final VoidCallback onAddParent;
  final ValueChanged<String> onRemoveParent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final task = detail.task;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (detail.diagnostics.isNotEmpty) ...[
          const KanbanTaskHeading('Needs attention'),
          for (final d in detail.diagnostics)
            Card(
              margin: const EdgeInsets.only(bottom: 6),
              color: d.severity == 'warning'
                  ? context.hermesColors.warning.withValues(alpha: 0.15)
                  : theme.colorScheme.error.withValues(alpha: 0.12),
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.warning_amber_rounded),
                title: Text(d.title),
                subtitle: d.detail.isEmpty ? null : Text(d.detail),
              ),
            ),
        ],
        if (task.body != null) ...[
          const KanbanTaskHeading('Description'),
          SelectableText(task.body!),
        ],
        if (task.latestSummary != null || task.result != null) ...[
          const KanbanTaskHeading('Result'),
          SelectableText(task.latestSummary ?? task.result!),
        ],
        const KanbanTaskHeading('Depends on'),
        Wrap(
          spacing: 6,
          children: [
            for (final id in detail.parents)
              InputChip(label: Text(id), onDeleted: () => onRemoveParent(id)),
            ActionChip(
              avatar: const Icon(Icons.add, size: 16),
              label: const Text('Add'),
              onPressed: onAddParent,
            ),
          ],
        ),
        if (detail.childResults.isNotEmpty) ...[
          const KanbanTaskHeading('Subtasks'),
          for (final c in detail.childResults)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(c.title),
              subtitle: Text(
                '${c.id} · ${kanbanStatusLabel(c.status)}'
                '${c.summary == null ? '' : '\n${c.summary}'}',
              ),
            ),
        ],
      ],
    );
  }
}
