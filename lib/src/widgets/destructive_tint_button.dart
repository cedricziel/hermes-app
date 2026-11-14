import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/platform_chrome.dart';

/// A destructive action drawn tinted: the error colour on a faint tint of
/// itself with an outline, never filled, so the one filled button of a screen
/// stays the safe action.
///
/// The touch target is 44 pt on iOS and iPadOS, 48 dp on Material and 28 pt on
/// a Mac. [onPressed] null draws it disabled; [busy] shows a spinner beside
/// the label and ignores presses until the work ends. The label is the
/// button's accessible name. A busy button announces nothing by itself, so
/// the caller changes the label while it works, for example to "Stopping".
/// It takes plain values: the confirmation that makes the action safe belongs
/// to the caller.
class DestructiveTintButton extends StatelessWidget {
  const DestructiveTintButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppIconSet? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final error = scheme.error;
    final chrome = platformChromeOf(context);
    final minHeight = switch (chrome) {
      PlatformChrome.material => 48.0,
      PlatformChrome.ios => kAppleMinTapTarget,
      PlatformChrome.macos => 28.0,
    };
    final enabled = onPressed != null && !busy;
    final disabledColor = scheme.onSurface.withValues(alpha: 0.38);
    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(0, minHeight)),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled) && !busy
            ? disabledColor
            : error,
      ),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled) && !busy
            ? scheme.onSurface.withValues(alpha: 0.06)
            : error.withValues(alpha: 0.12),
      ),
      // A light overlay keeps the label above 4.5:1 while hovered, focused or
      // pressed.
      overlayColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? null
            : error.withValues(alpha: 0.06),
      ),
      side: WidgetStateProperty.resolveWith(
        (states) => BorderSide(
          color: states.contains(WidgetState.disabled) && !busy
              ? scheme.onSurface.withValues(alpha: 0.12)
              : error.withValues(alpha: 0.4),
        ),
      ),
    );
    return OutlinedButton(
      onPressed: enabled ? onPressed : null,
      style: style,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (busy)
            ExcludeSemantics(
              child: SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: error),
              ),
            )
          else if (icon != null)
            ExcludeSemantics(child: AppIcon(icon!, size: 18)),
          if (busy || icon != null) const SizedBox(width: 8),
          Flexible(child: Text(label, textAlign: TextAlign.center)),
        ],
      ),
    );
  }
}
