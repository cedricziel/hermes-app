import 'package:flutter/material.dart';

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
  Widget build(BuildContext context) => AppAlertDialog(
    title: const Text('Reset memory?'),
    content: Text(
      'Hermes forgets what you pick, on the server, for the $profile '
      "profile. This can't be undone.",
    ),
    actions: [
      for (final (label, target) in [
        ('Reset agent notes', MemoryResetTarget.agentNotes),
        ('Reset about you', MemoryResetTarget.aboutYou),
        ('Reset both', MemoryResetTarget.both),
      ])
        AppDialogAction(
          isDestructive: true,
          onPressed: () => onPick(target),
          child: Text(label),
        ),
      AppDialogAction(
        isDefault: true,
        onPressed: onCancel,
        child: const Text('Cancel'),
      ),
    ],
  );
}
