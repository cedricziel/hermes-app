import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import '../../../theme/app_icons.dart';
import '../../../theme/hermes_theme.dart';
import '../../../widgets/app_banner.dart';
import '../../../widgets/grouped_list.dart';
import 'soul_line_metrics.dart';

/// What the line under the editor says about the last save.
enum SoulStatusKind {
  /// The text is on the server.
  saved,

  /// A check found that the server still has the earlier text.
  earlierText,

  /// A read or a write runs.
  saving,
}

/// One line under the count: a check icon and "Saved. New chats use it.", a
/// warning icon and "The server still has the earlier text. Your text is
/// still here.", or a spinner and "Saving". The icon and the words carry the
/// status, never the colour alone. It is a polite live region, so a screen
/// reader announces a change without taking focus.
///
/// It takes plain values only. The icon (or spinner) scales with the text and
/// the line is laid out like [SoulInfoLine], so the text starts at
/// [SoulLineMetrics.textInset] and a Revert button below lines up with it.
class SoulStatusLine extends StatelessWidget {
  const SoulStatusLine({super.key, required this.kind});

  final SoulStatusKind kind;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final metrics = GroupedMetrics.of(context);
    final colors = context.hermesColors;
    final (text, color) = switch (kind) {
      SoulStatusKind.saved => (l10n.profilesSoulStatusSaved, colors.success),
      SoulStatusKind.earlierText => (
        l10n.profilesSoulStatusEarlierText,
        colors.warning,
      ),
      SoulStatusKind.saving => (l10n.profilesSoulSaving, colors.subtleText),
    };
    final size = SoulLineMetrics.iconExtent(context);
    return Semantics(
      container: true,
      liveRegion: true,
      label: text,
      child: ExcludeSemantics(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            metrics.rowPadding,
            6,
            metrics.rowPadding,
            0,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: kind == SoulStatusKind.saving
                    ? SoulLineMetrics.spinner(context)
                    : AppIcon(
                        switch (kind) {
                          SoulStatusKind.saved => AppIcons.checkCircle,
                          _ => AppIcons.warning,
                        },
                        size: size,
                        color: color,
                      ),
              ),
              const SizedBox(width: SoulLineMetrics.gap),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(fontSize: metrics.footerSize, color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The states that need more than a line: a banner above the editor.
enum SoulBannerKind {
  /// The server refused the text (400, 422, 500). Nothing changed there.
  saveFailed,

  /// The save got no answer: it may have gone through. Offers Check.
  lostAnswer,

  /// A check read runs. The action is a spinner and "Checking…".
  checking,

  /// The check got no answer either. Offers Check again.
  checkFailed,

  /// The read before a save failed, so nothing was sent. Offers Try again.
  saveCheckFailed,

  /// Loading failed; no editor is shown. Offers Try again.
  readFailed,

  /// Loading got no answer because the device is offline. Offers Try again.
  offline,
}

/// An [AppBanner] for one of the [SoulBannerKind] states, worded from the
/// ARB files. [onAction] is Check, Check again or Try again, whichever the
/// state offers; it is ignored for [SoulBannerKind.saveFailed] and
/// [SoulBannerKind.checking], which have none to press.
///
/// The action stacks under the text at large text sizes and in German, and
/// has the platform's minimum target, both by [AppBanner].
class SoulStatusBanner extends StatelessWidget {
  const SoulStatusBanner({super.key, required this.kind, this.onAction});

  final SoulBannerKind kind;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Widget button(String label) =>
        TextButton(onPressed: onAction, child: Text(label));
    return switch (kind) {
      SoulBannerKind.saveFailed => AppBanner(
        tone: AppBannerTone.error,
        title: l10n.profilesSoulBannerSaveFailedTitle,
        detail: l10n.profilesSoulBannerSaveFailedDetail,
      ),
      SoulBannerKind.lostAnswer => AppBanner(
        tone: AppBannerTone.warning,
        icon: AppIcons.questionCircleFilled,
        title: l10n.profilesSoulBannerLostTitle,
        detail: l10n.profilesSoulBannerLostDetail,
        action: button(l10n.profilesSoulBannerCheck),
      ),
      SoulBannerKind.checking => AppBanner(
        tone: AppBannerTone.warning,
        icon: AppIcons.questionCircleFilled,
        title: l10n.profilesSoulBannerLostTitle,
        detail: l10n.profilesSoulBannerLostDetail,
        action: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SoulLineMetrics.spinner(context),
              const SizedBox(width: 8),
              Text(l10n.profilesSoulBannerChecking),
            ],
          ),
        ),
      ),
      SoulBannerKind.checkFailed => AppBanner(
        tone: AppBannerTone.warning,
        icon: AppIcons.questionCircleFilled,
        title: l10n.profilesSoulBannerCheckFailedTitle,
        detail: l10n.profilesSoulBannerLostDetail,
        action: button(l10n.profilesSoulBannerCheckAgain),
      ),
      SoulBannerKind.saveCheckFailed => AppBanner(
        tone: AppBannerTone.error,
        title: l10n.profilesSoulBannerNothingSent,
        action: button(l10n.profilesSoulBannerTryAgain),
      ),
      SoulBannerKind.readFailed => AppBanner(
        tone: AppBannerTone.error,
        title: l10n.profilesSoulBannerReadFailed,
        action: button(l10n.profilesSoulBannerTryAgain),
      ),
      SoulBannerKind.offline => AppBanner(
        tone: AppBannerTone.warning,
        title: l10n.profilesSoulBannerOfflineTitle,
        detail: l10n.profilesSoulBannerOfflineDetail,
        action: button(l10n.profilesSoulBannerTryAgain),
      ),
    };
  }
}
