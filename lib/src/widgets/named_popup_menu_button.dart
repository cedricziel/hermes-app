import 'package:flutter/material.dart';

import '../theme/app_icons.dart';

import 'package:hermes_app/src/widgets/adaptive_popup_menu_button.dart';

/// An icon [AdaptivePopupMenuButton] whose [label] is its accessible name and its
/// tooltip, for the same reason as `NamedIconButton`.
class NamedPopupMenuButton<T> extends StatelessWidget {
  const NamedPopupMenuButton({
    super.key,
    this.controller,
    required this.label,
    this.tooltip,
    required this.icon,
    required this.itemBuilder,
    this.onSelected,
    this.color,
    this.iconSize,
    this.padding = const EdgeInsets.all(8),
    this.style,
  });

  /// Opens the menu from outside.
  final AdaptiveMenuController? controller;
  final String label;

  /// A shorter hover text than [label], which screen readers never get.
  final String? tooltip;
  final AppIconSet icon;
  final PopupMenuItemBuilder<T> itemBuilder;
  final PopupMenuItemSelected<T>? onSelected;
  final Color? color;
  final double? iconSize;
  final EdgeInsetsGeometry padding;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip ?? label,
    excludeFromSemantics: true,
    child: AdaptivePopupMenuButton<T>(
      controller: controller,
      // An empty tooltip adds no semantics; the name comes from the icon.
      tooltip: '',
      icon: AppIcon(icon, color: color, semanticLabel: label),
      iconSize: iconSize,
      padding: padding,
      style: style,
      onSelected: onSelected,
      itemBuilder: itemBuilder,
    ),
  );
}
