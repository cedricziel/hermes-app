import 'package:flutter/widgets.dart';

import '../../../l10n/l10n.dart';
import '../../widgets/adaptive_dialog.dart';

/// Asks before the app connects to [host] over `http://` across the
/// internet, where the password, tokens and chats travel unencrypted.
/// Cancel is the default answer; true only when the user chose to connect.
Future<bool> confirmCleartextServer(
  BuildContext context, {
  required String host,
}) => showConfirmDialog(
  context,
  title: 'Connect without encryption?',
  message:
      '$host is not on your local network or a VPN, and http:// sends your '
      'password, sign-in tokens and chats to it unencrypted. Anyone on the '
      'way can read them.\n\nUse its https:// address if the server has one.',
  confirmLabel: 'Connect Anyway',
  destructive: true,
  filled: false,
);

/// Asks about [host], a server the app already connects to over `http://`
/// across the internet, saved before it asked. True keeps `http://`, false
/// chooses `https://` (the default answer), null means the dialog was closed
/// without a choice.
Future<bool?> confirmSavedCleartextServer(
  BuildContext context, {
  required String host,
}) {
  final l10n = context.l10n;
  return showConfirmDialogOrDismissed(
    context,
    title: l10n.screensCleartextSavedTitle,
    message: l10n.screensCleartextSavedBody(host),
    confirmLabel: l10n.screensCleartextKeepAction,
    cancelLabel: l10n.screensCleartextUseHttpsAction,
    destructive: true,
    filled: false,
    cancelIsDefault: true,
  );
}
