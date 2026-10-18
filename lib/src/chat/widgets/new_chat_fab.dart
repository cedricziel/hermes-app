import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';

/// A thumb-reachable shortcut to the chat list's existing new-chat action.
class NewChatFab extends StatelessWidget {
  const NewChatFab({super.key, required this.onPressed});

  /// The 56-point control plus 16 points of breathing room on either side.
  static const double listBottomPadding = 88;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'New chat',
      excludeFromSemantics: true,
      child: FloatingActionButton(
        heroTag: null,
        onPressed: onPressed,
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kHermesRadius),
        ),
        elevation: 2,
        focusElevation: 3,
        hoverElevation: 3,
        highlightElevation: 4,
        child: const AppIcon(
          AppIcons.compose,
          size: 26,
          semanticLabel: 'New chat',
        ),
      ),
    );
  }
}
