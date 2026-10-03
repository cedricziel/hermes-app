import 'package:flutter/material.dart';

/// An [IconButton] whose [label] is its accessible name and, unless [tooltip]
/// is given, its tooltip.
///
/// `IconButton.tooltip` alone leaves the button unnamed on macOS, whose
/// accessibility bridge reads only a node's label, and setting both a label
/// and a tooltip makes iOS read the name twice.
class NamedIconButton extends StatelessWidget {
  const NamedIconButton({
    super.key,
    required this.label,
    this.tooltip,
    required this.icon,
    required this.onPressed,
    this.color,
    this.style,
    this.filled = false,
    this.iconSize,
    this.visualDensity,
    this.padding,
    this.constraints,
  });

  final String label;

  /// A shorter hover text than [label], which screen readers never get.
  final String? tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final ButtonStyle? style;
  final bool filled;
  final double? iconSize;
  final VisualDensity? visualDensity;
  final EdgeInsetsGeometry? padding;
  final BoxConstraints? constraints;

  @override
  Widget build(BuildContext context) {
    final named = Icon(icon, semanticLabel: label);
    return Tooltip(
      message: tooltip ?? label,
      excludeFromSemantics: true,
      child: filled
          ? IconButton.filled(
              icon: named,
              color: color,
              style: style,
              iconSize: iconSize,
              visualDensity: visualDensity,
              padding: padding,
              constraints: constraints,
              onPressed: onPressed,
            )
          : IconButton(
              icon: named,
              color: color,
              style: style,
              iconSize: iconSize,
              visualDensity: visualDensity,
              padding: padding,
              constraints: constraints,
              onPressed: onPressed,
            ),
    );
  }
}
