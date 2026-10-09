import 'package:flutter/material.dart';
import 'package:hermes_app/src/widgets/grouped_form.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';
import 'package:hermes_app/src/widgets/settings_scaffold.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

WidgetbookNode groupedFormNode() => WidgetbookFolder(
  name: 'Settings forms',
  children: [
    WidgetbookComponent(
      name: 'Form rows',
      useCases: [
        ...onEachPlatform('Empty', (_) => pushed(const _FormPage())),
        ...onEachPlatform(
          'Filled',
          (_) => pushed(
            const _FormPage(
              name: 'Morning brief',
              body:
                  'Summarise the news and my calendar for today, and flag '
                  'anything that needs an answer.',
              assignee: 'coder',
            ),
          ),
        ),
        ...onEachPlatform(
          'Saving with an error',
          (_) => pushed(
            const _FormPage(
              name: 'Morning brief',
              saving: true,
              error: 'script must be inside the profile’s scripts folder',
            ),
          ),
        ),
      ],
    ),
  ],
);

const _assignees = ['coder', 'reviewer', 'researcher'];

/// A form page built from every shared form row, as the job and task forms
/// use them.
class _FormPage extends StatefulWidget {
  const _FormPage({
    this.name = '',
    this.body = '',
    this.assignee,
    this.saving = false,
    this.error,
  });

  final String name;
  final String body;
  final String? assignee;
  final bool saving;
  final String? error;

  @override
  State<_FormPage> createState() => _FormPageState();
}

class _FormPageState extends State<_FormPage> {
  late String? _assignee = widget.assignee;
  var _priority = 0;
  var _paused = false;

  @override
  Widget build(BuildContext context) => SettingsScaffold(
    title: 'New task',
    subtitle: 'work',
    previousTitle: null,
    cancel: true,
    formAction: SettingsFormAction(
      label: 'Save',
      busy: widget.saving,
      onPressed: () {},
    ),
    body: GroupedListView(
      children: [
        GroupedSection(
          children: [
            GroupedTextFieldRow(label: 'Name', initialValue: widget.name),
            GroupedTextFieldRow(
              label: 'Task',
              hint: 'What should Hermes do each time?',
              initialValue: widget.body,
              minLines: 3,
              maxLines: 8,
            ),
          ],
        ),
        GroupedSection(
          header: 'Priority',
          children: [
            GroupedSegmentedRow<int>(
              value: _priority,
              segments: const {0: 'Normal', 1: 'P1', 2: 'P2', 3: 'P3'},
              onChanged: (p) => setState(() => _priority = p),
            ),
          ],
        ),
        GroupedSection(
          header: 'Options',
          footer: 'Changes apply from the next run.',
          children: [
            GroupedMenuRow<String>(
              title: 'Assignee',
              options: _assignees,
              labelOf: (a) => a,
              selected: _assignee,
              placeholder: 'Auto',
              onSelected: (a) => setState(() => _assignee = a),
            ),
            GroupedValueRow(
              title: 'Model',
              value: 'claude-opus-4',
              caption: 'Anthropic',
              onTap: () {},
            ),
            const GroupedValueRow(title: 'Time', value: '08:00', busy: true),
            GroupedMenuRow<String>(
              title: 'Deliver results to',
              options: const ['discord'],
              labelOf: (_) => 'Discord',
              selected: 'discord',
              warning:
                  'No home channel is set on the server for this platform.',
              onSelected: (_) {},
            ),
            GroupedSwitchRow(
              title: 'Start paused',
              value: _paused,
              onChanged: (v) => setState(() => _paused = v),
            ),
          ],
        ),
        if (widget.error case final error?) GroupedFormError(error),
      ],
    ),
  );
}
