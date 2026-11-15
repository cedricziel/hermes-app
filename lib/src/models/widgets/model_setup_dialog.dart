import 'package:flutter/material.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/widgets/adaptive_dialog.dart';
import 'package:hermes_app/src/widgets/dialog_presentation.dart';

/// Explains how to configure the selected profile on the connected server.
Future<void> showModelSetup(BuildContext context, String? profile) =>
    showAppDialog<void>(
      context: context,
      builder: (dialog) => ModelSetupAlert(
        profile: profile,
        onCheckAgain: () => Navigator.of(dialog).pop(),
      ),
    );

/// The alert [showModelSetup] shows: the profile, the command that sets it up
/// and a Check again button.
class ModelSetupAlert extends StatelessWidget {
  const ModelSetupAlert({
    super.key,
    required this.profile,
    required this.onCheckAgain,
  });

  final String? profile;
  final VoidCallback onCheckAgain;

  @override
  Widget build(BuildContext context) {
    final name = profile == null || profile!.isEmpty ? 'default' : profile!;
    final argument = RegExp(r'^[a-zA-Z0-9_.-]+$').hasMatch(name)
        ? name
        : "'${name.replaceAll("'", "'\"'\"'")}'";
    final command = name == 'default'
        ? 'hermes model'
        : 'hermes -p $argument model';
    final l10n = context.l10n;
    return AppAlertDialog(
      scrollable: true,
      title: Text(l10n.modelsSetupTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.modelsSetupBody(name)),
          const SizedBox(height: 12),
          SelectableText(
            command,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
          ),
        ],
      ),
      actions: [
        AppDialogAction(
          isDefault: true,
          filledOnMaterial: false,
          onPressed: onCheckAgain,
          child: Text(l10n.modelsSetupCheckAgain),
        ),
      ],
    );
  }
}
