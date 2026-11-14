import 'package:flutter/material.dart';

import '../../theme/platform_chrome.dart';
import '../../widgets/adaptive_dialog.dart';

/// The question before the shown log lines are copied: logs can hold private
/// details, so it warns first. Cancel is the default; Copy is not
/// destructive.
class LogsCopyDialog extends StatelessWidget {
  const LogsCopyDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) => AppAlertDialog(
    title: Text(title),
    content: Text(message),
    actions: [
      AppDialogAction(
        isDefault: platformChromeOf(context).isApple,
        onPressed: () => Navigator.pop(context, false),
        child: Text(cancelLabel),
      ),
      AppDialogAction(
        onPressed: () => Navigator.pop(context, true),
        child: Text(confirmLabel),
      ),
    ],
  );
}
