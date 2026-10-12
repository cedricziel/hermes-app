import 'package:flutter/material.dart';

import '../../../widgets/grouped_list.dart';
import '../../../theme/app_icons.dart';
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
    final estimate = this.estimate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (task.status != 'done')
          GroupedSection(
            header: 'Actions',
            children: [
              if (task.status == 'triage') ...[
                GroupedRow(
                  title: 'Decompose',
                  chevron: false,
                  onTap: onDecompose,
                ),
                GroupedRow(title: 'Specify', chevron: false, onTap: onSpecify),
              ],
              if (task.status == 'running')
                GroupedRow(title: 'Reclaim', chevron: false, onTap: onReclaim),
              GroupedRow(title: 'Complete', chevron: false, onTap: onComplete),
              if (task.status != 'blocked')
                GroupedRow(title: 'Block', chevron: false, onTap: onBlock),
            ],
          ),
        GroupedSection(
          footer: estimate?.ok == true ? estimate?.rationale : null,
          children: [
            GroupedRow(
              title: 'Estimate',
              chevron: false,
              leading: const AppIcon(AppIcons.speed),
              subtitle: estimating ? null : estimate?.summary,
              subtitleMaxLines: null,
              enabled: !estimating,
              onTap: onEstimate,
              trailing: estimating
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                    )
                  : null,
            ),
          ],
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
    return GroupedSection(
      children: [
        GroupedRow(
          title: 'Archive',
          leading: const AppIcon(AppIcons.archive),
          chevron: false,
          onTap: onArchive,
        ),
        GroupedRow(
          title: 'Delete',
          leading: AppIcon(
            AppIcons.delete,
            color: Theme.of(context).colorScheme.error,
          ),
          destructive: true,
          chevron: false,
          onTap: onDelete,
        ),
      ],
    );
  }
}
