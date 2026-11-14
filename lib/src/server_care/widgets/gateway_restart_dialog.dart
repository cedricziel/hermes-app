import 'package:flutter/material.dart';

import '../../theme/platform_chrome.dart';
import '../../widgets/adaptive_dialog.dart';

/// The question before a gateway restart: what it interrupts, one line each.
///
/// A restart stops conversations on messaging channels, so no button is
/// filled: Cancel comes first and is the default on Apple platforms, and
/// Material shows two text buttons. Pops `true` only on [confirmLabel].
class GatewayRestartDialog extends StatelessWidget {
  const GatewayRestartDialog({
    super.key,
    required this.title,
    required this.lines,
    required this.confirmLabel,
    required this.cancelLabel,
  });

  final String title;
  final List<String> lines;
  final String confirmLabel;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) {
    final apple = platformChromeOf(context).isApple;
    final scheme = Theme.of(context).colorScheme;
    return AppAlertDialog(
      // On the dark scaffold the default dialog surface is almost the scrim's
      // black and its edge vanishes. Only this dialog sets its own: a dialog
      // theme for the whole app would hide anything zinc800 inside others.
      backgroundColor: !apple && scheme.brightness == Brightness.dark
          ? scheme.surfaceContainerHighest
          : null,
      title: Text(title),
      // Four lines at the largest text size outgrow a phone: scroll them.
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < lines.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              Text(
                lines[i],
                textAlign: apple ? TextAlign.center : TextAlign.start,
              ),
            ],
          ],
        ),
      ),
      actions: [
        AppDialogAction(
          isDefault: apple,
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
}
