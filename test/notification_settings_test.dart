import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:hermes_app/src/notifications/notification_settings.dart';

/// Reads preferences like the real thing, but runs [onDenied] while the
/// permission flags are read and always reports the scheduled task values as
/// not yet stored, so a test can see whether an edit made meanwhile survives.
class _HookedPrefs extends SharedPreferencesAsync {
  _HookedPrefs(this.onDenied);

  final void Function() onDenied;

  @override
  Future<bool?> getBool(String key) async {
    if (key == 'hermes.notifications_permission_denied') onDenied();
    if (key == 'hermes.notifications_schedules') return null;
    return super.getBool(key);
  }

  @override
  Future<List<String>?> getStringList(String key) async => null;
}

NotificationSettings? hooked;

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

  test('is not loaded until load completes', () async {
    final settings = NotificationSettings();
    expect(settings.loaded, isFalse);

    final loading = settings.load();
    expect(settings.loaded, isFalse);
    await loading;

    expect(settings.loaded, isTrue);
  });

  test('load tells listeners it finished', () async {
    final settings = NotificationSettings();
    var heard = 0;
    settings.addListener(() => heard++);

    await settings.load();

    expect(heard, 1);
  });

  test('is loaded after a load that lost every race to an edit', () async {
    final settings = NotificationSettings();

    final loading = settings.load();
    await settings.setEnabled(false);
    await settings.recordPermission(granted: false);
    await loading;

    expect(settings.loaded, isTrue);
  });

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

  group('scheduled tasks', () {
    test(
      'alerts are on by default and the choice survives a restart',
      () async {
        final settings = await relaunch();
        expect(settings.scheduleAlerts, isTrue);

        await settings.setScheduleAlerts(false);

        expect((await relaunch()).scheduleAlerts, isFalse);
      },
    );

    test('a mute survives a restart and can be lifted', () async {
      final settings = await relaunch();

      await settings.setMuted('work/job1', true);
      expect((await relaunch()).isMuted('work/job1'), isTrue);
      expect((await relaunch()).isMuted('home/job1'), isFalse);

      await settings.setMuted('work/job1', false);
      expect((await relaunch()).isMuted('work/job1'), isFalse);
    });

    test('forgets the mutes of jobs that are gone', () async {
      final settings = await relaunch();
      await settings.setMuted('work/job1', true);
      await settings.setMuted('work/job2', true);

      await settings.forgetMutes({'work/job2'});

      final again = await relaunch();
      expect(again.isMuted('work/job1'), isFalse);
      expect(again.isMuted('work/job2'), isTrue);
    });

    test('a mute made while loading is not lost', () async {
      final settings = NotificationSettings();

      final loading = settings.load();
      await settings.setMuted('work/job1', true);
      await loading;

      expect(settings.isMuted('work/job1'), isTrue);
    });

    test(
      'a switch changed while an early value is read is not undone',
      () async {
        // The stored value is what the write had not reached yet.
        final settings = NotificationSettings(
          prefs: _HookedPrefs(() {
            // Runs while the permission flags are read, before the scheduled
            // task values are.
            hooked?.setScheduleAlerts(false);
          }),
        );
        hooked = settings;

        await settings.load();

        expect(settings.scheduleAlerts, isFalse);
      },
    );

    test('a mute made while an early value is read is not undone', () async {
      final settings = NotificationSettings(
        prefs: _HookedPrefs(() => hooked?.setMuted('work/job1', true)),
      );
      hooked = settings;

      await settings.load();

      expect(settings.isMuted('work/job1'), isTrue);
    });

    test('tells listeners about a mute', () async {
      final settings = await relaunch();
      var heard = 0;
      settings.addListener(() => heard++);

      await settings.setMuted('work/job1', true);
      await settings.setMuted('work/job1', true);

      expect(heard, 1);
    });
  });
}
