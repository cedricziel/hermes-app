import 'package:flutter/material.dart';

/// An icon [PopupMenuButton] whose [label] is its accessible name and its
/// tooltip, for the same reason as `NamedIconButton`.
class NamedPopupMenuButton<T> extends StatelessWidget {
  const NamedPopupMenuButton({
    super.key,
    this.menuKey,
    required this.label,
    required this.icon,
    required this.itemBuilder,
    this.onSelected,
    this.color,
    this.iconSize,
    this.padding = const EdgeInsets.all(8),
    this.style,
  });

  /// The key of the menu itself, to open it from outside.
  final GlobalKey<PopupMenuButtonState<T>>? menuKey;
  final String label;
  final IconData icon;
  final PopupMenuItemBuilder<T> itemBuilder;
  final PopupMenuItemSelected<T>? onSelected;
  final Color? color;
  final double? iconSize;
  final EdgeInsetsGeometry padding;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    excludeFromSemantics: true,
    child: PopupMenuButton<T>(
      key: menuKey,
      // An empty tooltip adds no semantics; the name comes from the icon.
      tooltip: '',
      icon: Icon(icon, color: color, semanticLabel: label),
      iconSize: iconSize,
      padding: padding,
      style: style,
      onSelected: onSelected,
      itemBuilder: itemBuilder,
    ),
  );
}
