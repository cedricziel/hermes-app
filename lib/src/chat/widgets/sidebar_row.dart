import 'package:flutter/material.dart';

/// The rounded, tappable shell of a sidebar row, filled when [selected].
class SidebarRow extends StatelessWidget {
  const SidebarRow({
    super.key,
    required this.selected,
    required this.onTap,
    required this.padding,
    required this.child,
    this.onLongPress,
    this.onSecondaryTap,
  });

  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;
  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(8);
    return Material(
      color: selected
          ? Theme.of(context).colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.7)
          : Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        onLongPress: onLongPress,
        onSecondaryTap: onSecondaryTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
