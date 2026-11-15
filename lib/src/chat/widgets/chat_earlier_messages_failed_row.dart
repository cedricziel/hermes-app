import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../widgets/app_banner.dart';
import '../../widgets/motion_spinner.dart';
import '../chat_models.dart';

/// The row at the top of a chat's transcript when its newest messages are on
/// screen but the older ones could not be read: a warning with a Retry, or the
/// same row while Retry reads again. Plain values only; the transcript shows it
/// as its first item, so it scrolls away with the messages.
class ChatEarlierMessagesFailedRow extends StatelessWidget {
  const ChatEarlierMessagesFailedRow({
    super.key,
    required this.status,
    this.onRetry,
  });

  final ChatEarlierMessagesStatus status;

  /// Reads the earlier messages again; without it a failure offers no button.
  /// A retrying row never has one.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final touch = switch (Theme.of(context).platform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.fuchsia => true,
      _ => false,
    };
    // One height for both states, so Retry turning into the spinner and back
    // never moves the messages below the row. The banner gives a button
    // action its platform target, so the retrying content takes the same.
    final height = math.max(
      AppBanner.minActionTarget(context),
      touch ? 44.0 : 32.0,
    );
    final retrying = status == ChatEarlierMessagesStatus.retrying;
    // Both states are the same button frame (padding, minimum size, text), so
    // the row has one height at every text size and in every language; while
    // retrying the button is off and shows the spinner and "Retrying…".
    final Widget? action = !retrying && onRetry == null
        ? null
        : Semantics(
            // Its own node, so the banner's live label stays the title.
            container: retrying,
            child: TextButton.icon(
              onPressed: retrying ? null : onRetry,
              icon: retrying
                  ? const MotionSpinner()
                  : const AppIcon(AppIcons.refresh, size: 16),
              label: Text(
                retrying
                    ? l10n.chatWidgetsHistoryEarlierRetrying
                    : l10n.commonRetry,
                semanticsLabel: retrying
                    ? null
                    : l10n.chatWidgetsHistoryEarlierRetryLabel,
              ),
              style: TextButton.styleFrom(
                minimumSize: Size(0, height),
                visualDensity: VisualDensity.standard,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                disabledForegroundColor: context.hermesColors.subtleText,
              ),
            ),
          );
    return AppBanner(
      tone: AppBannerTone.warning,
      title: l10n.chatWidgetsHistoryEarlierFailedTitle,
      action: action,
    );
  }
}
