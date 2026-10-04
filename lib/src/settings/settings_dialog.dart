import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_lock/app_lock_dialog.dart';
import '../auth/auth_controller.dart';
import '../notifications/notifications_dialog.dart';
import 'about_dialog.dart';
import 'appearance_dialog.dart';

enum _Setting {
  appearance('Appearance…'),
  notifications('Notifications…'),
  appLock('App Lock…'),
  about('About Hermes'),
  changeServer('Change Server…');

  const _Setting(this.label);

  final String label;
}

/// The app's settings in one place, for the Mac account menu's "Settings…":
/// each entry opens the dialog the sidebar's account menu opens elsewhere.
Future<void> showSettingsDialog(BuildContext context) async {
  final picked = await showDialog<_Setting>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Settings'),
      children: [
        for (final setting in _Setting.values)
          SimpleDialogOption(
            key: ValueKey('setting-${setting.name}'),
            onPressed: () => Navigator.of(context).pop(setting),
            child: Text(setting.label),
          ),
      ],
    ),
  );
  if (picked == null || !context.mounted) return;
  switch (picked) {
    case _Setting.appearance:
      await showAppearanceDialog(context);
    case _Setting.notifications:
      await showNotificationsDialog(context);
    case _Setting.appLock:
      await showAppLockDialog(context);
    case _Setting.about:
      await showAppAboutDialog(context);
    case _Setting.changeServer:
      await context.read<AuthController>().changeServer();
  }
}
