import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../app_lock/app_lock_controller.dart';
import '../app_lock/app_lock_dialog.dart';
import '../auth/auth_controller.dart';
import '../macos/menu_bar_extra/menu_bar_extra_settings.dart';
import '../macos/menu_bar_extra/widgets/menu_bar_item_section.dart';
import '../notifications/notification_settings.dart';
import '../notifications/notifications_dialog.dart';
import '../quick_panel/global_shortcut.dart';
import '../quick_panel/widgets/quick_panel_shortcut_row.dart';
import '../spotlight/spotlight_dialog.dart';
import '../spotlight/spotlight_settings.dart';
import '../voice/dictation_dialog.dart';
import '../voice/dictation_settings.dart';
import '../widgets/grouped_dialog.dart';
import '../widgets/grouped_list.dart';
import 'about_dialog.dart';
import 'appearance_dialog.dart';
import 'theme_controller.dart';

enum _Setting {
  appearance,
  notifications,
  dictation,
  spotlight,
  appLock,
  about,
  changeServer;

  String label(AppLocalizations l10n) => switch (this) {
    appearance => l10n.settingsAppearanceTitle,
    notifications => l10n.settingsNotifications,
    dictation => l10n.settingsDictation,
    spotlight => l10n.settingsSpotlight,
    appLock => l10n.settingsAppLock,
    about => l10n.settingsAboutHermes,
    changeServer => l10n.settingsChangeServer,
  };
}

/// The app's settings in one place, for the Mac account menu's "Settings…":
/// each entry opens the dialog the sidebar's account menu opens elsewhere.
Future<void> showSettingsDialog(BuildContext context) async {
  final l10n = context.l10n;
  String onOff(bool on) => on ? l10n.commonOn : l10n.commonOff;
  final values = {
    _Setting.appearance: _read<ThemeController>(
      context,
      (theme) => themeModeLabel(l10n, theme.mode),
    ),
    _Setting.notifications: _read<NotificationSettings>(
      context,
      (settings) => onOff(settings.enabled),
    ),
    _Setting.dictation: _read<DictationSettings>(
      context,
      (settings) => switch (settings.engine) {
        DictationEngine.hermes => l10n.settingsDictationEngineHermes,
        DictationEngine.device => l10n.settingsDictationEngineDevice,
      },
    ),
    _Setting.spotlight: _read<SpotlightSettings>(
      context,
      (settings) => onOff(settings.enabled),
    ),
    _Setting.appLock: _read<AppLockController>(
      context,
      (lock) => onOff(lock.enabled),
    ),
  };
  // Provided only on a Mac, where the shortcut exists.
  final shortcut = _maybeRead<GlobalShortcut?>(context);
  final menuBar = MenuBarExtraSettings.offered
      ? _maybeRead<MenuBarExtraSettings>(context)
      : null;
  final picked = await showDialog<_Setting>(
    context: context,
    builder: (context) {
      GroupedRow row(_Setting setting) => GroupedRow(
        wrapWhenStacked: true,
        key: ValueKey('setting-${setting.name}'),
        title: setting.label(l10n),
        value: values[setting],
        onTap: () => Navigator.of(context).pop(setting),
      );
      return GroupedDialog(
        title: l10n.settingsTitle,
        children: [
          GroupedSection(
            children: [
              row(_Setting.appearance),
              row(_Setting.notifications),
              if (DictationSettings.offered) row(_Setting.dictation),
              if (shortcut != null) QuickPanelShortcutRow(shortcut: shortcut),
              if (SpotlightSettings.offered) row(_Setting.spotlight),
              row(_Setting.appLock),
            ],
          ),
          if (menuBar != null)
            ListenableBuilder(
              listenable: menuBar,
              builder: (context, _) => MenuBarItemSection(
                value: menuBar.enabled,
                onChanged: menuBar.setEnabled,
              ),
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
    case _Setting.spotlight:
      await showSpotlightDialog(context);
    case _Setting.appLock:
      await showAppLockDialog(context);
    case _Setting.about:
      await showAppAboutDialog(context);
    case _Setting.changeServer:
      await context.read<AuthController>().changeServer();
  }
}

/// What [describe] says about the provided [T], or null where there is none.
String? _read<T>(BuildContext context, String Function(T value) describe) =>
    switch (_maybeRead<T>(context)) {
      final T value? => describe(value),
      _ => null,
    };

T? _maybeRead<T>(BuildContext context) {
  try {
    return context.read<T>();
  } on ProviderNotFoundException {
    return null;
  }
}
