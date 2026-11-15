import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../theme/hermes_theme.dart';
import '../../widgets/app_banner.dart';
import 'pairing_buttons.dart';

/// What a phone says before it draws the code: the code has to be scanned by
/// the phone that holds the WhatsApp account, and a phone cannot scan its own
/// screen. A neutral banner with a phone icon (not an error) and the filled
/// "Show QR code". After the tap ([revealed]) the notice shrinks to one muted
/// line above the code, so the tap does not hide the instruction.
class HandsetQrNotice extends StatelessWidget {
  const HandsetQrNotice({
    super.key,
    required this.revealed,
    required this.onShow,
  });

  final bool revealed;
  final VoidCallback onShow;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (revealed) {
      return Text(
        l10n.messagingWhatsappHandsetTitle,
        style: TextStyle(color: context.hermesColors.subtleText),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        AppBanner(
          tone: AppBannerTone.neutral,
          icon: AppIcons.call,
          title: l10n.messagingWhatsappHandsetTitle,
          detail: l10n.messagingWhatsappHandsetDetail,
        ),
        PairingButton.filled(
          label: l10n.messagingWhatsappShowQr,
          onPressed: onShow,
        ),
      ],
    );
  }
}
