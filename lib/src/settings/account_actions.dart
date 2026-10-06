import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../screens/home_screen.dart';
import '../widgets/adaptive_dialog.dart';

/// Shows the connection details page.
Future<void> showConnectionDetails(BuildContext context) =>
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const HomeScreen()));

/// Signs out of the dashboard once the user confirms.
Future<void> confirmSignOut(BuildContext context, AuthController auth) async {
  final confirmed = await showConfirmDialog(
    context,
    title: 'Sign out of the dashboard?',
    message: 'You will need to sign in again to see your chats.',
    confirmLabel: 'Sign Out',
  );
  if (confirmed) await auth.signOut();
}
