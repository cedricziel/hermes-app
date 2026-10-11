import 'package:flutter/material.dart';

import '../../models/model_provider_option.dart';
import '../../widgets/disclosure_tile.dart';
import '../../widgets/grouped_dialog.dart';
import '../../widgets/grouped_form.dart';
import '../../widgets/grouped_list.dart';

class BotCreationFields extends StatelessWidget {
  const BotCreationFields({
    super.key,
    required this.name,
    required this.title,
    required this.description,
    required this.soul,
    required this.copyKeys,
    required this.onCopyKeysChanged,
    this.chosen,
    this.onChooseModel,
    this.nameError,
    this.modelError,
    this.modelLoading = false,
    this.saving = false,
    this.createdName,
    this.initiallyExpanded = false,
  });

  final TextEditingController name;
  final TextEditingController title;
  final TextEditingController description;
  final TextEditingController soul;
  final bool copyKeys;
  final ValueChanged<bool> onCopyKeysChanged;
  final ModelChoice? chosen;
  final VoidCallback? onChooseModel;
  final String? nameError;
  final String? modelError;
  final bool modelLoading;
  final bool saving;
  final String? createdName;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final metrics = GroupedMetrics.of(context);
    final editable = !saving && createdName == null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupedSection(
          footer: nameError ?? 'Name is the permanent profile identifier.',
          children: [
            GroupedTextFieldRow(
              label: 'Name',
              hint: 'writer',
              controller: name,
              enabled: editable,
              autocorrect: false,
            ),
            GroupedTextFieldRow(
              label: 'Title',
              hint: 'Writing assistant',
              controller: title,
              enabled: !saving,
            ),
            GroupedTextFieldRow(
              label: 'Description',
              hint: 'Role or focus',
              controller: description,
              enabled: !saving,
            ),
          ],
        ),
        DisclosureTile(
          title: Text(
            'Advanced',
            style: TextStyle(fontSize: metrics.titleSize),
          ),
          initiallyExpanded: initiallyExpanded,
          tilePadding: EdgeInsets.symmetric(horizontal: metrics.rowPadding),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          shape: const Border(),
          collapsedShape: const Border(),
          children: [
            GroupedSection(
              header: 'Standing instructions',
              children: [
                GroupedTextFieldRow(
                  label: 'Standing instructions',
                  hint: 'How should this bot work?',
                  controller: soul,
                  enabled: editable,
                  minLines: 3,
                  maxLines: 5,
                ),
              ],
            ),
            if (onChooseModel != null)
              GroupedSection(
                children: [
                  GroupedValueRow(
                    title: 'Default model',
                    value: chosen?.modelId ?? 'Use server default',
                    caption: chosen?.providerId,
                    warning: modelError,
                    busy: modelLoading,
                    onTap: editable ? onChooseModel : null,
                  ),
                ],
              ),
            GroupedSection(
              footer: 'The server copies API keys. OAuth sign-ins require separate authentication.',
              children: [
                GroupedSwitchRow(
                  title: 'Copy provider API keys',
                  value: copyKeys,
                  onChanged: editable ? onCopyKeysChanged : null,
                ),
              ],
            ),
          ],
        ),
        if (createdName != null)
          GroupedDialogNote(
            'Profile $createdName was created. Retry saves its details.',
          ),
      ],
    );
  }
}
