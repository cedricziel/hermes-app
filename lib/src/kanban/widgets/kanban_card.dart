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
    this.handle,
  });

  final KanbanTask task;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;

  /// Something to grab the card by where a long press already means another
  /// thing; floats over the card's top right corner.
  final Widget? handle;

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
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.id,
                    style: small?.copyWith(fontFamily: 'monospace'),
                  ),
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
                        _Meta(
                          Icons.warning_amber_rounded,
                          '${task.warningCount}',
                          small?.copyWith(color: context.hermesColors.warning),
                        ),
                    ],
                  ),
                  if (task.status == 'running') ...[
                    const SizedBox(height: 10),
                    _WorkingBar(task: task),
                  ],
                ],
              ),
            ),
            if (handle != null) Positioned(top: 0, right: 0, child: handle!),
          ],
        ),
      ),
    );
  }
}

/// How far a running task has got: the share of its children done, or a
/// bar that just moves while there is nothing to count. The board's live
/// stream refetches it, so it advances as the work does.
class _WorkingBar extends StatelessWidget {
  const _WorkingBar({required this.task});

  final KanbanTask task;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'In progress',
    value: task.progressTotal > 0
        ? '${task.progressDone} of ${task.progressTotal} done'
        : null,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        minHeight: 3,
        value: task.progressTotal > 0
            ? (task.progressDone / task.progressTotal).clamp(0.0, 1.0)
            : null,
      ),
    ),
  );
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
