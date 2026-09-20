import 'package:flutter/material.dart';

import '../../theme/hermes_theme.dart';
import '../kanban_models.dart';

/// A task on the board: id, title, and the few facts worth scanning for.
class KanbanCard extends StatelessWidget {
  const KanbanCard({
    super.key,
    required this.task,
    this.onTap,
    this.selected = false,
    this.onLongPress,
  });

  final KanbanTask task;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtle = theme.colorScheme.onSurface.withValues(alpha: 0.55);
    final small = theme.textTheme.bodySmall?.copyWith(color: subtle);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kHermesRadius),
        side: BorderSide(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.outline,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(kHermesRadius),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(task.id, style: small?.copyWith(fontFamily: 'monospace')),
              const SizedBox(height: 2),
              Text(
                task.title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (task.assignee != null)
                    _Meta(Icons.person_outline, task.assignee!, small),
                  if (task.priority > 0)
                    _Tag('P${task.priority}', theme.colorScheme.error),
                  if (task.tenant != null) _Tag(task.tenant!, null),
                  if (task.commentCount > 0)
                    _Meta(
                      Icons.chat_bubble_outline,
                      '${task.commentCount}',
                      small,
                    ),
                  if (task.progressTotal > 0)
                    _Meta(
                      Icons.account_tree_outlined,
                      '${task.progressDone}/${task.progressTotal}',
                      small,
                    ),
                  if (task.warningCount > 0)
                    _Tag('⚠ ${task.warningCount}', Colors.amber.shade800),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.label, this.style);

  final IconData icon;
  final String label;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: style?.color),
      const SizedBox(width: 3),
      Text(label, style: style),
    ],
  );
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, this.color);

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = color ?? theme.colorScheme.onSurface.withValues(alpha: 0.7);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: (color ?? theme.colorScheme.onSurface).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(color: fg, fontSize: 11),
      ),
    );
  }
}
