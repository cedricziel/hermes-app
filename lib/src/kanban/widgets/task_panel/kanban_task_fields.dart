import 'package:flutter/material.dart';

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
            header: 'Needs attention',
            children: [
              for (final d in detail.diagnostics)
                GroupedRow(
                  title: d.title,
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
        if (task.body != null) textSection('Description', task.body!),
        if (task.latestSummary != null || task.result != null)
          textSection('Result', task.latestSummary ?? task.result!),
        GroupedSection(
          header: 'Model',
          children: [
            GroupedRow(
              key: const Key('kanban-task-model'),
              title: task.modelOverride ?? 'Profile default',
              subtitle: task.reasoningEffort == null
                  ? null
                  : effortLabel(task.reasoningEffort!),
              onTap: onEditModel,
            ),
          ],
        ),
        GroupedSection(
          header: 'Depends on',
          children: [
            for (final id in detail.parents)
              GroupedRow(
                title: id,
                chevron: false,
                trailing: NamedIconButton(
                  label: 'Remove dependency $id',
                  icon: AppIcons.close,
                  onPressed: () => onRemoveParent(id),
                ),
              ),
            GroupedRow(
              title: 'Add',
              leading: const AppIcon(AppIcons.add),
              chevron: false,
              onTap: onAddParent,
            ),
          ],
        ),
        if (detail.childResults.isNotEmpty)
          GroupedSection(
            header: 'Subtasks',
            children: [
              for (final c in detail.childResults)
                GroupedRow(
                  title: c.title,
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
