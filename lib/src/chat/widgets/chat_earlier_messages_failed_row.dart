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
    // never moves the messages below the row.
    final height = touch ? 44.0 : 32.0;
    final Widget? action = switch (status) {
      ChatEarlierMessagesStatus.failed =>
        onRetry == null
            ? null
            : Semantics(
                label: l10n.chatWidgetsHistoryEarlierRetryLabel,
                button: true,
                excludeSemantics: true,
                child: TextButton.icon(
                  onPressed: onRetry,
                  icon: const AppIcon(AppIcons.refresh, size: 16),
                  label: Text(l10n.commonRetry),
                  style: TextButton.styleFrom(
                    minimumSize: Size(0, height),
                    visualDensity: touch ? null : VisualDensity.compact,
                  ),
                ),
              ),
      ChatEarlierMessagesStatus.retrying => ConstrainedBox(
        constraints: BoxConstraints(minHeight: height),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MotionSpinner(),
            const SizedBox(width: 8),
            Text(
              l10n.chatWidgetsHistoryEarlierRetrying,
              style: TextStyle(color: context.hermesColors.subtleText),
            ),
          ],
        ),
      ),
    };
    return AppBanner(
      tone: AppBannerTone.warning,
      title: l10n.chatWidgetsHistoryEarlierFailedTitle,
      action: action,
      actionIsButton: status == ChatEarlierMessagesStatus.failed,
    );
  }
}
