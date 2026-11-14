import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../auth/auth_controller.dart';
import '../screens/home_screen.dart';
import '../widgets/adaptive_dialog.dart';

/// Shows the connection details page.
Future<void> showConnectionDetails(BuildContext context) =>
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const HomeScreen()));

/// Signs out of the dashboard once the user confirms.
Future<void> confirmSignOut(BuildContext context, AuthController auth) async {
  final l10n = context.l10n;
  final confirmed = await showConfirmDialog(
    context,
    title: l10n.settingsSignOutTitle,
    message: l10n.settingsSignOutMessage,
    confirmLabel: l10n.settingsSignOut,
  );
  if (confirmed) await auth.signOut();
}
