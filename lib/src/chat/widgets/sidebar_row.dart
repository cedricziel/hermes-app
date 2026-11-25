import 'package:material_ui/material_ui.dart';

import '../../theme/focus_ring.dart';

/// The rounded, tappable shell of a sidebar row, filled when [selected]. The
/// keyboard focus ring is 2 px inside its edge (the list clips a ring outside)
/// and follows the row's own ink well only, so a button in the row, such as a
/// thread's More, draws its own ring and not the row's as well.
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
      child: FocusRing(
        radius: 6,
        ownFocus: true,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          onLongPress: onLongPress,
          onSecondaryTap: onSecondaryTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
