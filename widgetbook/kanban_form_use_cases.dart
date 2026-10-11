import 'package:flutter/material.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_orchestration_fields.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_task_edit_fields.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

WidgetbookNode kanbanFormFieldsNode() => WidgetbookFolder(
  name: 'Kanban form fields',
  children: [
    WidgetbookComponent(
      name: 'Task editing',
      useCases: [
        for (final state in ['Empty', 'Populated', 'Long description'])
          ...onEachPlatform(
            state,
            (_) => frame(_TaskFieldsPreview(state: state)),
          ),
      ],
    ),
    WidgetbookComponent(
      name: 'Orchestration',
      useCases: [
        for (final state in [
          'Loading',
          'Failed',
          'Inherited',
          'Pinned profiles',
          'Stale profile',
        ])
          ...onEachPlatform(
            state,
            (_) => frame(_OrchestrationPreview(state: state)),
          ),
      ],
    ),
  ],
);

class _TaskFieldsPreview extends StatefulWidget {
  const _TaskFieldsPreview({required this.state});
  final String state;

  @override
  State<_TaskFieldsPreview> createState() => _TaskFieldsPreviewState();
}

class _TaskFieldsPreviewState extends State<_TaskFieldsPreview> {
  late final title = TextEditingController(
    text: widget.state == 'Empty' ? '' : 'Review release notes',
  );
  late final body = TextEditingController(
    text: switch (widget.state) {
      'Empty' => '',
      'Long description' => List.generate(
        20,
        (i) => 'Step ${i + 1}: review the changes and verify the result.',
      ).join('\n'),
      _ => 'Check the examples and confirm the commands work.',
    },
  );

  @override
  void dispose() {
    title.dispose();
    body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      KanbanTaskEditFields(title: title, body: body);
}

class _OrchestrationPreview extends StatefulWidget {
  const _OrchestrationPreview({required this.state});
  final String state;

  @override
  State<_OrchestrationPreview> createState() => _OrchestrationPreviewState();
}

class _OrchestrationPreviewState extends State<_OrchestrationPreview> {
  bool decompose = false;
  bool promote = true;
  late String orchestrator = switch (widget.state) {
    'Pinned profiles' => 'writer',
    'Stale profile' => 'previous-lead',
    _ => '',
  };
  late String assignee = widget.state == 'Pinned profiles' ? 'reviewer' : '';

  @override
  Widget build(BuildContext context) => KanbanOrchestrationFields(
    loading: widget.state == 'Loading',
    error: widget.state == 'Failed' ? 'Could not load the settings' : null,
    autoDecompose: decompose,
    autoPromote: promote,
    orchestrator: orchestrator,
    defaultAssignee: assignee,
    activeProfile: 'default',
    profiles: const ['writer', 'reviewer'],
    onDecomposeChanged: (value) => setState(() => decompose = value),
    onPromoteChanged: (value) => setState(() => promote = value),
    onOrchestratorChanged: (value) => setState(() => orchestrator = value),
    onAssigneeChanged: (value) => setState(() => assignee = value),
  );
}
