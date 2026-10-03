import 'package:flutter/material.dart';

/// A [LinearProgressIndicator] that stops sliding when the system asks to
/// reduce motion. With no [value] it then shows a full, dimmed bar: still
/// "working", but nothing moves.
class BusyBar extends StatelessWidget {
  const BusyBar({super.key, this.value, this.minHeight});

  final double? value;
  final double? minHeight;

  @override
  Widget build(BuildContext context) {
    if (value == null && MediaQuery.disableAnimationsOf(context)) {
      final theme = Theme.of(context);
      final color =
          theme.progressIndicatorTheme.color ?? theme.colorScheme.primary;
      return LinearProgressIndicator(
        value: 1,
        minHeight: minHeight,
        color: color.withValues(alpha: 0.4),
      );
    }
    return LinearProgressIndicator(value: value, minHeight: minHeight);
  }
}
