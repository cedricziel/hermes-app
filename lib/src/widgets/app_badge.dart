import 'package:flutter/material.dart';

import '../theme/app_icons.dart';

/// A small label in a rounded box: what a row is, where it came from or what
/// state it is in.
///
/// [AppBadge.tinted] tells a state in its own colour, with an optional icon so
/// the colour never carries the meaning alone. [AppBadge.filled] is a neutral
/// tag on a surface colour. The badge reads as its label and is not a button.
/// It takes plain values only: no controller and no lookups beyond the theme.
class AppBadge extends StatelessWidget {
  /// A label and optional icon in [color], on a faint tint of it. Long labels
  /// wrap; [minWidth] keeps short ones from looking cramped in a list.
  const AppBadge.tinted({
    super.key,
    required this.label,
    required Color this.color,
    this.icon,
    this.minWidth = 0,
    this.verticalPadding = 3,
  }) : fill = null;

  /// A label in the theme's small label style on [fill].
  const AppBadge.filled({super.key, required this.label, required this.fill})
    : color = null,
      icon = null,
      minWidth = 0,
      verticalPadding = 1;

  final String label;

  /// The label and icon colour of a tinted badge; null for a filled one.
  final Color? color;

  /// The box colour of a filled badge; null for a tinted one.
  final Color? fill;
  final AppIconSet? icon;
  final double minWidth;
  final double verticalPadding;

  @override
  Widget build(BuildContext context) {
    final tint = color;
    final textStyle = tint == null
        ? Theme.of(context).textTheme.labelSmall
        : TextStyle(color: tint, fontSize: 12, fontWeight: FontWeight.w600);
    final text = Text(label, style: textStyle);
    final content = icon == null
        ? text
        : Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: AppIcon(
                  icon!,
                  size: MediaQuery.textScalerOf(context).scale(14),
                  color: tint,
                ),
              ),
              const SizedBox(width: 4),
              Flexible(child: text),
            ],
          );
    // Not a container, so a row that reads as one element includes it.
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Container(
          constraints: minWidth > 0 ? BoxConstraints(minWidth: minWidth) : null,
          alignment: minWidth > 0 ? Alignment.center : null,
          padding: EdgeInsets.symmetric(
            horizontal: tint == null ? 7 : 8,
            vertical: verticalPadding,
          ),
          decoration: BoxDecoration(
            color: tint?.withValues(alpha: 0.12) ?? fill,
            borderRadius: BorderRadius.circular(6),
          ),
          child: content,
        ),
      ),
    );
  }
}
