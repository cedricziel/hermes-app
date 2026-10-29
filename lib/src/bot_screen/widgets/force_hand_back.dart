import 'package:flutter/material.dart';

import '../../widgets/adaptive_dialog.dart';
import '../../widgets/dialog_presentation.dart';

/// The question before a lease nobody here holds is handed back to Hermes.
///
/// It says that whoever is using the screen loses control, because the person
/// holding the lease may be someone else, or this device before the app
/// restarted.
class ForceHandBackDialog extends StatelessWidget {
  const ForceHandBackDialog({
    super.key,
    required this.onCancel,
    required this.onConfirm,
  });

  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) => AppAlertDialog(
    title: const Text('Hand control back to Hermes?'),
    content: const Text(
      'Whoever is using the screen loses control, which may be you on '
      'another device or before the app restarted. Hermes carries on with '
      'the screen.',
    ),
    actions: [
      AppDialogAction(onPressed: onCancel, child: const Text('Cancel')),
      AppDialogAction(
        isDefault: true,
        isDestructive: true,
        onPressed: onConfirm,
        child: const Text('Hand Back'),
      ),
    ],
  );
}

/// Asks whether to hand the screen back to Hermes whoever holds it, and if so
/// runs [handBack]; says so when it did not work.
Future<void> confirmForceHandBack(
  BuildContext context,
  Future<bool> Function() handBack,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final confirmed =
      await showAppDialog<bool>(
        context: context,
        builder: (dialog) => ForceHandBackDialog(
          onCancel: () => Navigator.pop(dialog, false),
          onConfirm: () => Navigator.pop(dialog, true),
        ),
      ) ??
      false;
  if (!confirmed) return;
  if (await handBack()) return;
  messenger?.showSnackBar(
    const SnackBar(content: Text("Couldn't hand control back to Hermes.")),
  );
}
