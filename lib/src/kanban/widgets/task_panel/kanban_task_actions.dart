import 'package:flutter/material.dart';

import '../../kanban_models.dart';

/// The buttons a task's status offers (triage, reclaim, complete, block)
/// and its estimate.
class KanbanTaskActions extends StatelessWidget {
  const KanbanTaskActions({
    super.key,
    required this.task,
    required this.onDecompose,
    required this.onSpecify,
    required this.onReclaim,
    required this.onComplete,
    required this.onBlock,
    required this.onEstimate,
    this.estimate,
    this.estimating = false,
  });

  final KanbanTask task;
  final VoidCallback onDecompose;
  final VoidCallback onSpecify;
  final VoidCallback onReclaim;
  final VoidCallback onComplete;
  final VoidCallback onBlock;
  final VoidCallback onEstimate;
  final KanbanEstimate? estimate;
  final bool estimating;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtle = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final estimate = this.estimate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (task.status == 'triage')
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  onPressed: onDecompose,
                  child: const Text('Decompose'),
                ),
                OutlinedButton(
                  onPressed: onSpecify,
                  child: const Text('Specify'),
                ),
              ],
            ),
          ),
        if (task.status == 'running')
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              children: [
                OutlinedButton(
                  onPressed: onReclaim,
                  child: const Text('Reclaim'),
                ),
              ],
            ),
          ),
        if (task.status != 'done')
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  onPressed: onComplete,
                  child: const Text('Complete'),
                ),
                if (task.status != 'blocked')
                  OutlinedButton(
                    onPressed: onBlock,
                    child: const Text('Block'),
                  ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: estimating ? null : onEstimate,
                icon: const Icon(Icons.speed_outlined, size: 18),
                label: const Text('Estimate'),
              ),
              if (estimating)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (estimate != null)
                Text(estimate.summary),
            ],
          ),
        ),
        if (estimate?.rationale != null && estimate!.ok)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              estimate.rationale!,
              style: theme.textTheme.bodySmall?.copyWith(color: subtle),
            ),
          ),
      ],
    );
  }
}

/// Archive and delete, at the foot of the panel.
class KanbanTaskFooter extends StatelessWidget {
  const KanbanTaskFooter({
    super.key,
    required this.onArchive,
    required this.onDelete,
  });

  final VoidCallback onArchive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return Row(
      children: [
        TextButton.icon(
          onPressed: onArchive,
          icon: const Icon(Icons.archive_outlined),
          label: const Text('Archive'),
        ),
        TextButton.icon(
          onPressed: onDelete,
          icon: Icon(Icons.delete_outline, color: error),
          label: Text('Delete', style: TextStyle(color: error)),
        ),
      ],
    );
  }
}
