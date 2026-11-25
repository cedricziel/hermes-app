import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';
import '../../macos/mac_commands.dart';
import '../../navigation/keyboard_shortcuts.dart';
import '../../theme/app_icons.dart';
import '../../theme/focus_ring.dart';
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
      message: withChordHint(
        context,
        context.l10n.chatWidgetsNewChat,
        MacCommand.newChat,
      ),
      excludeFromSemantics: true,
      // A floating button's shape is not state-aware, so the keyboard focus
      // ring is a wrapper, 2 px outside it (nothing clips it).
      child: FocusRing.outside(
        radius: kHermesRadius,
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
          child: AppIcon(
            AppIcons.compose,
            size: 26,
            semanticLabel: context.l10n.chatWidgetsNewChat,
          ),
        ),
      ),
    );
  }
}
