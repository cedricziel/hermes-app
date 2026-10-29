import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../widgets/named_icon_button.dart';

/// What a computer's viewer header offers while in control, besides Hand Back:
/// Paste, and on Windows and Linux Send F8, since F8 itself closes the viewer
/// there. A mouse and a keyboard need no key bar.
class BotScreenDesktopTools extends StatelessWidget {
  const BotScreenDesktopTools({
    super.key,
    required this.onPaste,
    this.onSendF8,
  });

  final VoidCallback onPaste;

  /// Sends F8 to the screen; null leaves the button out (a Mac).
  final VoidCallback? onSendF8;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      NamedIconButton(
        label: 'Paste',
        icon: AppIcons.paste,
        iconSize: 20,
        onPressed: onPaste,
      ),
      if (onSendF8 != null)
        TextButton(
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          onPressed: onSendF8,
          child: const Text('Send F8'),
        ),
    ],
  );
}
