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
  Widget build(BuildContext context) {
    // A Material dialog shrinks its padding as the text grows, down to a third
    // at twice the size, which leaves the text touching the edge; give back
    // what it took.
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final side = platformChromeOf(context).isApple
        ? 0.0
        : 16 * (scale - 1).clamp(0.0, 1.0);
    Widget padded(Widget child) => side == 0
        ? child
        : Padding(
            padding: EdgeInsets.symmetric(horizontal: side),
            child: child,
          );
    return _dialog(context, padded);
  }

  Widget _dialog(BuildContext context, Widget Function(Widget) padded) =>
      AppAlertDialog(
        title: padded(Text(title)),
        content: padded(Text(message)),
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
