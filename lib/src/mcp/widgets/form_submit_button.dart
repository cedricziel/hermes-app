import 'package:flutter/material.dart';

import '../../theme/platform_chrome.dart';

/// The button that ends a form, such as "Add" or "Save": the full width on a
/// phone, at the trailing edge on a Mac, with a spinner while [busy].
class FormSubmitButton extends StatelessWidget {
  const FormSubmitButton({
    super.key,
    this.buttonKey,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  /// The key of the [FilledButton] itself, for finding it.
  final Key? buttonKey;
  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final button = FilledButton(
      key: buttonKey,
      onPressed: onPressed,
      child: busy
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator.adaptive(strokeWidth: 2),
            )
          : Text(label),
    );
    if (platformChromeOf(context) == PlatformChrome.macos) {
      return Align(alignment: Alignment.centerRight, child: button);
    }
    return button;
  }
}
