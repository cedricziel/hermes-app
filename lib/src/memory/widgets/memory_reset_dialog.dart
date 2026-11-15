import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../widgets/adaptive_dialog.dart';
import '../../widgets/dialog_presentation.dart';
import '../memory_provider.dart';

/// Asks which memory files to erase for [profile]. Answers the target, or
/// null on Cancel.
Future<MemoryResetTarget?> showMemoryResetDialog(
  BuildContext context, {
  required String profile,
}) => showAppDialog<MemoryResetTarget>(
  context: context,
  builder: (dialog) => MemoryResetAlert(
    profile: profile,
    onPick: (target) => Navigator.pop(dialog, target),
    onCancel: () => Navigator.pop(dialog),
  ),
);

class MemoryResetAlert extends StatelessWidget {
  const MemoryResetAlert({
    super.key,
    required this.profile,
    required this.onPick,
    required this.onCancel,
  });

  final String profile;
  final ValueChanged<MemoryResetTarget> onPick;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppAlertDialog(
      title: Text(l10n.memoryResetTitle),
      content: Text(l10n.memoryResetMessage(profile)),
      actions: [
        for (final (label, target) in [
          (l10n.memoryResetAgentNotes, MemoryResetTarget.agentNotes),
          (l10n.memoryResetAboutYou, MemoryResetTarget.aboutYou),
          (l10n.memoryResetBoth, MemoryResetTarget.both),
        ])
          AppDialogAction(
            isDestructive: true,
            onPressed: () => onPick(target),
            child: Text(label),
          ),
        AppDialogAction(
          isDefault: true,
          onPressed: onCancel,
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
      ],
    );
  }
}
