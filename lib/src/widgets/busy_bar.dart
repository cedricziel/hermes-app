import 'package:flutter/material.dart';

/// Whether the system asks for less motion. iOS reports Reduce Motion through
/// the platform's accessibility features, other platforms through
/// [MediaQueryData.disableAnimations].
bool reduceMotionOf(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context) ||
    View.of(context).platformDispatcher.accessibilityFeatures.reduceMotion;

/// A [LinearProgressIndicator] that stops sliding when the system asks to
/// reduce motion. With no [value] it then shows a full, dimmed bar: still
/// "working", but nothing moves.
class BusyBar extends StatelessWidget {
  const BusyBar({super.key, this.value, this.minHeight});

  final double? value;
  final double? minHeight;

  @override
  Widget build(BuildContext context) {
    if (value == null && reduceMotionOf(context)) {
      final theme = Theme.of(context);
      final color =
          theme.progressIndicatorTheme.color ?? theme.colorScheme.primary;
      return Semantics(
        value: 'In progress',
        child: ExcludeSemantics(
          child: LinearProgressIndicator(
            value: 1,
            minHeight: minHeight,
            color: color.withValues(alpha: 0.4),
            backgroundColor: Colors.transparent,
          ),
        ),
      );
    }
    return LinearProgressIndicator(value: value, minHeight: minHeight);
  }
}
