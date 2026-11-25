import 'package:material_ui/material_ui.dart';

import '../../../../l10n/l10n.dart';

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
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (task.status != 'done')
          GroupedSection(
            header: l10n.kanbanTaskActions,
            children: [
              if (task.status == 'triage') ...[
                GroupedRow(
                  title: l10n.kanbanTaskDecompose,
                  chevron: false,
                  onTap: onDecompose,
                ),
                GroupedRow(
                  title: l10n.kanbanTaskSpecify,
                  chevron: false,
                  onTap: onSpecify,
                ),
              ],
              if (task.status == 'running')
                GroupedRow(
                  title: l10n.kanbanTaskReclaim,
                  chevron: false,
                  onTap: onReclaim,
                ),
              GroupedRow(
                title: l10n.kanbanTaskComplete,
                chevron: false,
                onTap: onComplete,
              ),
              if (task.status != 'blocked')
                GroupedRow(
                  title: l10n.kanbanTaskBlock,
                  chevron: false,
                  onTap: onBlock,
                ),
            ],
          ),
        GroupedSection(
          footer: estimate?.ok == true ? estimate?.rationale : null,
          children: [
            GroupedRow(
              title: l10n.kanbanTaskEstimate,
              chevron: false,
              leading: const AppIcon(AppIcons.speed),
              subtitle: estimating || estimate == null
                  ? null
                  : kanbanEstimateSummary(l10n, estimate),
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
    final l10n = context.l10n;
    return GroupedSection(
      children: [
        GroupedRow(
          title: l10n.kanbanArchive,
          leading: const AppIcon(AppIcons.archive),
          chevron: false,
          onTap: onArchive,
        ),
        GroupedRow(
          title: l10n.kanbanDelete,
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
