import 'package:flutter/material.dart';

import '../../theme/hermes_theme.dart';

/// The mark for a server that needs attention: a 10 pt filled circle in the
/// warning colour inside a 2 pt ring in the colour it sits on, so it reads on
/// both themes. It is decorative and not a target; the words beside it
/// ("Server · needs attention") carry the meaning.
class ServerAttentionDot extends StatelessWidget {
  const ServerAttentionDot({super.key, this.ringColor});

  /// The colour of what the dot sits on; the surface colour when null.
  final Color? ringColor;

  static const double dotSize = 10;
  static const double ringWidth = 2;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: dotSize + 2 * ringWidth,
      height: dotSize + 2 * ringWidth,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.hermesColors.warning,
        border: Border.all(
          color: ringColor ?? Theme.of(context).colorScheme.surface,
          width: ringWidth,
        ),
      ),
    ),
  );
}

/// [child] with a [ServerAttentionDot] at its bottom right while [show] is
/// true, such as the account avatar. The caller's own label for [child] says
/// the server needs attention.
class ServerAttentionBadge extends StatelessWidget {
  const ServerAttentionBadge({
    super.key,
    required this.child,
    required this.show,
    this.ringColor,
  });

  final Widget child;
  final bool show;
  final Color? ringColor;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      child,
      if (show)
        PositionedDirectional(
          end: -ServerAttentionDot.ringWidth,
          bottom: -ServerAttentionDot.ringWidth,
          child: ServerAttentionDot(ringColor: ringColor),
        ),
    ],
  );
}

/// The label of the account menu's Server item: "Server", or "Server · needs
/// attention" ending in the dot.
class ServerMenuItemLabel extends StatelessWidget {
  const ServerMenuItemLabel({
    super.key,
    required this.label,
    required this.needsAttention,
  });

  /// "Server", or "Server · needs attention", already in the reader's
  /// language.
  final String label;
  final bool needsAttention;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Flexible(child: Text(label)),
      if (needsAttention) ...[
        const SizedBox(width: 8),
        const ServerAttentionDot(),
      ],
    ],
  );
}
