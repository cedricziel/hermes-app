import 'package:flutter/material.dart';

import '../../widgets/grouped_form.dart';
import '../../widgets/grouped_list.dart';

class BotEditFields extends StatelessWidget {
  const BotEditFields({
    super.key,
    required this.profile,
    required this.title,
    required this.summary,
    required this.description,
    required this.soul,
    this.model,
    this.provider,
    this.onChooseModel,
  });

  final String profile;
  final TextEditingController title, summary, description, soul;
  final String? model, provider;
  final VoidCallback? onChooseModel;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      GroupedSection(
        footer: 'Profile: $profile',
        children: [
          GroupedTextFieldRow(label: 'Title', controller: title),
          GroupedTextFieldRow(label: 'Roster summary', controller: summary),
        ],
      ),
      GroupedSection(
        header: 'Description',
        children: [
          GroupedTextFieldRow(
            label: 'Description',
            controller: description,
            minLines: 2,
            maxLines: 3,
          ),
        ],
      ),
      GroupedSection(
        header: 'Standing instructions',
        children: [
          GroupedTextFieldRow(
            label: 'Standing instructions',
            controller: soul,
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
              value: model ?? 'Choose default model',
              caption: provider,
              onTap: onChooseModel,
            ),
          ],
        ),
    ],
  );
}
