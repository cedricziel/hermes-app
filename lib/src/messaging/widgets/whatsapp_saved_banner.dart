import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../tools/widgets/tools_target.dart';
import '../../widgets/app_banner.dart';
import '../../widgets/named_icon_button.dart';
import 'pairing_end.dart';

/// What the Messaging list says after Finish saved the setup.
enum WhatsAppSavedKind {
  /// A restart was asked for and the server does not say it is still needed.
  restartRequested,

  /// `restart_started` was not true.
  noRestart,

  /// A restart was asked for, but `needs_restart` is true.
  restartMayBeNeeded,

  /// Check confirmed the save: whether a restart happened is not known.
  unknownRestart,
}

/// The banner at the top of the Messaging list after the screens closed:
/// success when a restart was requested, a warning otherwise. It never says
/// the gateway restarted. [restartError], the server's own text, is appended
/// to the detail as given (control characters shown visibly). "Open Server"
/// shows only where [onOpenServer] is given; the close button is always there.
class WhatsAppSavedBanner extends StatelessWidget {
  const WhatsAppSavedBanner({
    super.key,
    required this.kind,
    this.restartError,
    this.onOpenServer,
    required this.onClose,
  });

  final WhatsAppSavedKind kind;
  final String? restartError;
  final VoidCallback? onOpenServer;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final success = kind == WhatsAppSavedKind.restartRequested;
    final detail = switch (kind) {
      WhatsAppSavedKind.restartRequested => l10n.messagingWhatsappSavedDetail,
      WhatsAppSavedKind.noRestart => l10n.messagingWhatsappSavedNoRestartDetail,
      WhatsAppSavedKind.restartMayBeNeeded =>
        l10n.messagingWhatsappSavedMaybeRestartDetail,
      WhatsAppSavedKind.unknownRestart =>
        l10n.messagingWhatsappSavedUnknownRestartDetail,
    };
    final error = restartError;
    final target = toolsTarget(context);
    return AppBanner(
      tone: success ? AppBannerTone.success : AppBannerTone.warning,
      title: success
          ? l10n.messagingWhatsappSavedTitle
          : l10n.messagingWhatsappSavedWarningTitle,
      detail: error == null || error.isEmpty
          ? detail
          : '$detail ${whatsAppSafeServerText(error)}',
      action: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (onOpenServer != null)
            TextButton(
              onPressed: onOpenServer,
              style: toolsButtonStyle(context),
              child: Text(l10n.messagingWhatsappOpenServer),
            ),
          NamedIconButton(
            label: MaterialLocalizations.of(context).closeButtonLabel,
            icon: AppIcons.close,
            onPressed: onClose,
            style: IconButton.styleFrom(
              minimumSize: Size.square(target),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}
