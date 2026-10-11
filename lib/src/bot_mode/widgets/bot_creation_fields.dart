import 'package:flutter/material.dart';

import '../../models/model_provider_option.dart';
import '../../widgets/disclosure_tile.dart';
import '../../widgets/adaptive_dialog.dart';
import '../../theme/platform_chrome.dart';

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
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (platformChromeOf(context).isApple) ...[
        AppDialogTextField(
          controller: name,
          hint: 'Name',
          enabled: !saving && createdName == null,
          autofocus: false,
        ),
        const Text('Permanent profile identifier.'),
        if (nameError != null) Text(nameError!),
      ] else
        TextField(
          controller: name,
          enabled: !saving && createdName == null,
          decoration: InputDecoration(
            labelText: 'Name',
            helperText: 'Permanent profile identifier.',
            errorText: nameError,
          ),
        ),
      const SizedBox(height: 12),
      if (platformChromeOf(context).isApple)
        AppDialogTextField(
          controller: title,
          hint: 'Title',
          enabled: !saving,
          autofocus: false,
        )
      else
        TextField(
          controller: title,
          enabled: !saving,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
      const SizedBox(height: 12),
      if (platformChromeOf(context).isApple)
        AppDialogTextField(
          controller: description,
          hint: 'Description',
          enabled: !saving,
          autofocus: false,
        )
      else
        TextField(
          controller: description,
          enabled: !saving,
          decoration: const InputDecoration(labelText: 'Description'),
        ),
      DisclosureTile(
        title: const Text('Advanced'),
        initiallyExpanded: initiallyExpanded,
        tilePadding: EdgeInsets.zero,
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (platformChromeOf(context).isApple)
            AppDialogTextField(
              controller: soul,
              hint: 'Standing instructions',
              enabled: !saving && createdName == null,
              maxLines: 3,
              autofocus: false,
            )
          else
            TextField(
              controller: soul,
              enabled: !saving && createdName == null,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Standing instructions',
              ),
            ),
          const SizedBox(height: 12),
          if (onChooseModel != null) ...[
            TextButton(
              onPressed: saving || modelLoading || createdName != null
                  ? null
                  : onChooseModel,
              child: Text(
                modelLoading
                    ? 'Loading models…'
                    : chosen == null
                    ? 'Choose model and provider'
                    : '${chosen!.providerId} · ${chosen!.modelId}',
              ),
            ),
            if (chosen == null)
              const Text('Leave unset to use the server’s default model.'),
            if (modelError != null) Text(modelError!),
          ],
          SwitchListTile.adaptive(
            value: copyKeys,
            contentPadding: EdgeInsets.zero,
            title: const Text('Copy provider API keys'),
            subtitle: const Text(
              'The server copies API keys. OAuth sign-ins require separate authentication.',
            ),
            onChanged: saving || createdName != null ? null : onCopyKeysChanged,
          ),
        ],
      ),
      if (createdName != null)
        Text('Profile $createdName was created. Retry saves its details.'),
    ],
  );
}
