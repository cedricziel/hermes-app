import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../files/widgets/safe_path_text.dart';
import '../../theme/app_icons.dart';
import '../../widgets/install_parts.dart';
import '../../widgets/state_message.dart';
import 'pairing_buttons.dart';

/// How a setup ended without a link.
enum PairingEndKind {
  /// The bridge or the server gave up; the server's own text is shown.
  error,

  /// The setup's ten minutes ran out.
  expired,

  /// Another setup on the same server replaced this one.
  superseded,

  /// The server no longer knows the setup (a poll or an apply got 404).
  gone,

  /// The server is too old to offer the routes. No retry.
  unsupported,

  /// The chat's profile was deleted. No retry.
  profileDeleted,
}

/// [text] as it may be shown: line breaks stay and every other control or bidi
/// character is drawn as a visible `<U+202E>`, so the server's words cannot
/// reorder or hide what the user reads. Only the display changes.
String whatsAppSafeServerText(String text) => safeContentText(text);

/// An ended setup: an icon, a fixed title, a line of detail, the server's own
/// text when there is one (in a selectable surface-high box that wraps), and
/// one button: the filled "Start again", or the outlined "Back" where no retry
/// exists (old server, deleted profile). [duringApply] says a [gone] end was
/// found while saving: the settings may not be saved.
class PairingEnd extends StatelessWidget {
  const PairingEnd({
    super.key,
    required this.kind,
    this.serverText,
    this.duringApply = false,
    this.handset = true,
    this.onStartAgain,
    this.onBack,
  });

  final PairingEndKind kind;

  /// The server's text, for [PairingEndKind.error]. Display only: never log
  /// or store it.
  final String? serverText;
  final bool duringApply;
  final bool handset;
  final VoidCallback? onStartAgain;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (icon, title, detail) = switch (kind) {
      PairingEndKind.error => (
        AppIcons.error,
        l10n.messagingWhatsappEndErrorTitle,
        serverText == null ? l10n.messagingWhatsappEndErrorNoText : null,
      ),
      PairingEndKind.expired => (
        AppIcons.schedule,
        l10n.messagingWhatsappEndExpiredTitle,
        l10n.messagingWhatsappEndExpiredDetail,
      ),
      PairingEndKind.superseded => (
        AppIcons.swap,
        l10n.messagingWhatsappEndSupersededTitle,
        l10n.messagingWhatsappEndSupersededDetail,
      ),
      PairingEndKind.gone => (
        AppIcons.cloud,
        l10n.messagingWhatsappEndGoneTitle,
        duringApply
            ? l10n.messagingWhatsappEndGoneApplyDetail
            : l10n.messagingWhatsappEndGoneDetail,
      ),
      PairingEndKind.unsupported => (
        AppIcons.server,
        l10n.messagingWhatsappEndUnsupportedTitle,
        l10n.messagingWhatsappEndUnsupportedDetail,
      ),
      PairingEndKind.profileDeleted => (
        AppIcons.person,
        l10n.messagingWhatsappEndProfileTitle,
        l10n.messagingWhatsappEndProfileDetail,
      ),
    };
    final retry =
        kind != PairingEndKind.unsupported &&
        kind != PairingEndKind.profileDeleted;
    final text = serverText;
    return StateMessage(
      icon: icon,
      title: title,
      detail: detail,
      action: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          if (kind == PairingEndKind.error && text != null)
            Semantics(
              container: true,
              label: l10n.messagingWhatsappServerTextLabel,
              child: InstallCodeBox(
                child: SelectableText(
                  whatsAppSafeServerText(text),
                  style: kInstallMono,
                ),
              ),
            ),
          PairingActions(
            handset: handset,
            alignment: WrapAlignment.center,
            children: [
              if (retry)
                PairingButton.filled(
                  label: l10n.messagingWhatsappStartAgain,
                  onPressed: onStartAgain,
                )
              else
                PairingButton.outlined(
                  label: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: onBack,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
