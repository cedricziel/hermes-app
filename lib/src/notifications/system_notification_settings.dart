import 'package:app_settings/app_settings.dart';
import 'package:flutter/foundation.dart';

/// Opens the system screen where the user can allow notifications for the
/// app. Injected so a test can stand in for the platform.
typedef OpenNotificationSettings = Future<void> Function();

/// Whether [openSystemNotificationSettings] can do anything on [platform]:
/// `app_settings` has no Windows or Linux implementation, and neither has a
/// notification permission to turn back on.
bool canOpenNotificationSettings(TargetPlatform platform) =>
    platform == TargetPlatform.android ||
    platform == TargetPlatform.iOS ||
    platform == TargetPlatform.macOS;

/// The app's notification settings on Android 8 and later and on iOS 16 and
/// later, the system's general Notifications pane on macOS (where the user
/// picks Hermes from the list). A failure is swallowed: the user is left
/// where they were and can still open system settings by hand.
Future<void> openSystemNotificationSettings() async {
  try {
    await AppSettings.openAppSettings(type: AppSettingsType.notification);
  } on Exception catch (_) {}
}
