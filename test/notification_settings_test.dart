import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:hermes_app/src/notifications/notification_settings.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  Future<NotificationSettings> relaunch() async {
    final settings = NotificationSettings();
    await settings.load();
    return settings;
  }

  test('starts on, not asked, not denied', () async {
    final settings = await relaunch();

    expect(settings.enabled, isTrue);
    expect(settings.permissionAsked, isFalse);
    expect(settings.permissionDenied, isFalse);
  });

  test('keeps the switch across launches', () async {
    await NotificationSettings().setEnabled(false);

    expect((await relaunch()).enabled, isFalse);
  });

  test('turning it back on is remembered too', () async {
    final settings = NotificationSettings();
    await settings.setEnabled(false);
    await settings.setEnabled(true);

    expect((await relaunch()).enabled, isTrue);
  });

  test('a granted permission is remembered as asked, not denied', () async {
    await NotificationSettings().recordPermission(granted: true);

    final settings = await relaunch();
    expect(settings.permissionAsked, isTrue);
    expect(settings.permissionDenied, isFalse);
  });

  test('a denied permission is remembered as asked and denied', () async {
    await NotificationSettings().recordPermission(granted: false);

    final settings = await relaunch();
    expect(settings.permissionAsked, isTrue);
    expect(settings.permissionDenied, isTrue);
  });

  test('a later grant clears an earlier denial', () async {
    final settings = NotificationSettings();
    await settings.recordPermission(granted: false);
    await settings.recordPermission(granted: true);

    expect((await relaunch()).permissionDenied, isFalse);
  });

  test('listeners hear about a change', () async {
    final settings = NotificationSettings();
    var heard = 0;
    settings.addListener(() => heard++);

    await settings.setEnabled(false);

    expect(heard, 1);
  });

  test('loading does not undo a change made while it was reading', () async {
    await NotificationSettings().setEnabled(true);
    final settings = NotificationSettings();

    final loading = settings.load();
    await settings.setEnabled(false);
    await loading;

    expect(settings.enabled, isFalse);
  });

  test('a permission recorded while loading keeps the saved switch', () async {
    await NotificationSettings().setEnabled(false);
    final settings = NotificationSettings();

    final loading = settings.load();
    await settings.recordPermission(granted: true);
    await loading;

    expect(settings.enabled, isFalse);
    expect(settings.permissionAsked, isTrue);
    expect(settings.permissionDenied, isFalse);
  });

  test('a switch flipped while loading keeps the saved permission', () async {
    await NotificationSettings().recordPermission(granted: false);
    final settings = NotificationSettings();

    final loading = settings.load();
    await settings.setEnabled(false);
    await loading;

    expect(settings.enabled, isFalse);
    expect(settings.permissionAsked, isTrue);
    expect(settings.permissionDenied, isTrue);
  });
}
