import 'package:material_ui/material_ui.dart';

import '../../../../l10n/l10n.dart';

import '../../../models/model_provider_option.dart';
import '../../../theme/app_icons.dart';
import '../../../theme/hermes_theme.dart';
import '../../kanban_models.dart';
import '../../../widgets/grouped_list.dart';
import '../../../widgets/named_icon_button.dart';

/// What the task says: diagnostics, description, result, model, dependencies
/// and subtasks.
class KanbanTaskFields extends StatelessWidget {
  const KanbanTaskFields({
    super.key,
    required this.detail,
    required this.onAddParent,
    required this.onRemoveParent,
    required this.onEditModel,
  });

  final KanbanTaskDetail detail;
  final VoidCallback onAddParent;
  final ValueChanged<String> onRemoveParent;
  final VoidCallback onEditModel;

  @override
  Widget build(BuildContext context) {
    final task = detail.task;
    final metrics = GroupedMetrics.of(context);
    final l10n = context.l10n;
    Widget textSection(String title, String text) => GroupedSection(
      header: title,
      children: [
        Padding(
          padding: EdgeInsets.all(metrics.rowPadding),
          child: SelectableText(text),
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (detail.diagnostics.isNotEmpty)
          GroupedSection(
            header: l10n.kanbanTaskNeedsAttention,
            children: [
              for (final d in detail.diagnostics)
                GroupedRow(
                  title: d.title,
                  titleMaxLines: null,
                  subtitle: d.detail.isEmpty ? null : d.detail,
                  subtitleMaxLines: null,
                  chevron: false,
                  leading: AppIcon(
                    AppIcons.warningRounded,
                    color: d.severity == 'warning'
                        ? context.hermesColors.warning
                        : Theme.of(context).colorScheme.error,
                  ),
                ),
            ],
          ),
        if (task.body != null)
          textSection(l10n.kanbanEditTaskDescriptionLabel, task.body!),
        if (task.latestSummary != null || task.result != null)
          textSection(
            l10n.kanbanTaskResult,
            task.latestSummary ?? task.result!,
          ),
        GroupedSection(
          header: l10n.kanbanTaskModel,
          children: [
            GroupedRow(
              key: const Key('kanban-task-model'),
              title: task.modelOverride ?? l10n.kanbanBulkEffortDefault,
              subtitle: task.reasoningEffort == null
                  ? null
                  : effortLabel(task.reasoningEffort!),
              onTap: onEditModel,
            ),
          ],
        ),
        GroupedSection(
          header: l10n.kanbanTaskDependsOn,
          children: [
            for (final id in detail.parents)
              GroupedRow(
                title: id,
                titleMaxLines: null,
                chevron: false,
                trailing: NamedIconButton(
                  label: l10n.kanbanTaskRemoveDependency(id),
                  icon: AppIcons.close,
                  onPressed: () => onRemoveParent(id),
                ),
              ),
            GroupedRow(
              title: l10n.kanbanTaskAdd,
              leading: const AppIcon(AppIcons.add),
              chevron: false,
              onTap: onAddParent,
            ),
          ],
        ),
        if (detail.childResults.isNotEmpty)
          GroupedSection(
            header: l10n.kanbanTaskSubtasks,
            children: [
              for (final c in detail.childResults)
                GroupedRow(
                  title: c.title,
                  titleMaxLines: null,
                  subtitle:
                      '${c.id} · ${kanbanStatusLabel(c.status)}'
                      '${c.summary == null ? '' : '\n${c.summary}'}',
                  subtitleMaxLines: null,
                  chevron: false,
                ),
            ],
          ),
      ],
    );
  }
}
