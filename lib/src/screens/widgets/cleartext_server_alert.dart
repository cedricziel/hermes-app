import 'package:flutter/widgets.dart';

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
