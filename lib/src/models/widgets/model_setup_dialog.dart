import 'package:flutter/material.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/widgets/adaptive_dialog.dart';
import 'package:hermes_app/src/widgets/dialog_presentation.dart';

/// Explains how to configure the selected profile on the connected server.
Future<void> showModelSetup(BuildContext context, String? profile) {
  final name = profile == null || profile.isEmpty ? 'default' : profile;
  final argument = RegExp(r'^[a-zA-Z0-9_.-]+$').hasMatch(name)
      ? name
      : "'${name.replaceAll("'", "'\"'\"'")}'";
  final command = name == 'default'
      ? 'hermes model'
      : 'hermes -p $argument model';
  return showAppDialog<void>(
    context: context,
    builder: (dialog) => AppAlertDialog(
      title: Text(dialog.l10n.modelsSetupTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dialog.l10n.modelsSetupBody(name)),
          const SizedBox(height: 12),
          SelectableText(command),
        ],
      ),
      actions: [
        AppDialogAction(
          isDefault: true,
          filledOnMaterial: false,
          onPressed: () => Navigator.of(dialog).pop(),
          child: Text(dialog.l10n.modelsSetupCheckAgain),
        ),
      ],
    ),
  );
}
