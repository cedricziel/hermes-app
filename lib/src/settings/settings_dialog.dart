import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_lock/app_lock_controller.dart';
import '../app_lock/app_lock_dialog.dart';
import '../auth/auth_controller.dart';
import '../notifications/notification_settings.dart';
import '../notifications/notifications_dialog.dart';
import '../voice/dictation_dialog.dart';
import '../voice/dictation_settings.dart';
import '../widgets/grouped_dialog.dart';
import '../widgets/grouped_list.dart';
import 'about_dialog.dart';
import 'appearance_dialog.dart';
import 'theme_controller.dart';

enum _Setting {
  appearance('Appearance'),
  notifications('Notifications'),
  dictation('Dictation'),
  appLock('App Lock'),
  about('About Hermes'),
  changeServer('Change Server');

  const _Setting(this.label);

  final String label;
}

/// The app's settings in one place, for the Mac account menu's "Settings…":
/// each entry opens the dialog the sidebar's account menu opens elsewhere.
Future<void> showSettingsDialog(BuildContext context) async {
  final values = {
    _Setting.appearance: _read<ThemeController>(
      context,
      (theme) => themeModeLabels[theme.mode]!,
    ),
    _Setting.notifications: _read<NotificationSettings>(
      context,
      (settings) => _onOff(settings.enabled),
    ),
    _Setting.dictation: _read<DictationSettings>(
      context,
      (settings) => switch (settings.engine) {
        DictationEngine.hermes => 'Hermes',
        DictationEngine.device => 'On this device',
      },
    ),
    _Setting.appLock: _read<AppLockController>(
      context,
      (lock) => _onOff(lock.enabled),
    ),
  };
  final picked = await showDialog<_Setting>(
    context: context,
    builder: (context) {
      GroupedRow row(_Setting setting) => GroupedRow(
        key: ValueKey('setting-${setting.name}'),
        title: setting.label,
        value: values[setting],
        onTap: () => Navigator.of(context).pop(setting),
      );
      return GroupedDialog(
        title: 'Settings',
        children: [
          GroupedSection(
            children: [
              row(_Setting.appearance),
              row(_Setting.notifications),
              if (DictationSettings.offered) row(_Setting.dictation),
              row(_Setting.appLock),
            ],
          ),
          GroupedSection(
            children: [row(_Setting.about), row(_Setting.changeServer)],
          ),
        ],
      );
    },
  );
  if (picked == null || !context.mounted) return;
  switch (picked) {
    case _Setting.appearance:
      await showAppearanceDialog(context);
    case _Setting.notifications:
      await showNotificationsDialog(context);
    case _Setting.dictation:
      await showDictationDialog(context);
    case _Setting.appLock:
      await showAppLockDialog(context);
    case _Setting.about:
      await showAppAboutDialog(context);
    case _Setting.changeServer:
      await context.read<AuthController>().changeServer();
  }
}

String _onOff(bool on) => on ? 'On' : 'Off';

/// What [describe] says about the provided [T], or null where there is none.
String? _read<T>(BuildContext context, String Function(T value) describe) {
  try {
    return describe(context.read<T>());
  } on ProviderNotFoundException {
    return null;
  }
}
