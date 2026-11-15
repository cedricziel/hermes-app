import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/voice/calls/portable_call_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('the default is off', () {
    expect(kPortableCallsDefault, isFalse);
  });

  test('off before it loaded, and after loading nothing saved', () async {
    final settings = PortableCallSettings();
    expect(settings.enabled, isFalse);
    expect(settings.loaded, isFalse);
    await settings.load();
    expect(settings.loaded, isTrue);
    expect(settings.enabled, isFalse);
  });

  test('a saved choice survives a restart, on and off', () async {
    final first = PortableCallSettings();
    await first.load();
    await first.setEnabled(true);
    final second = PortableCallSettings();
    await second.load();
    expect(second.enabled, isTrue);
    await second.setEnabled(false);
    final third = PortableCallSettings();
    await third.load();
    expect(third.enabled, isFalse);
  });

  test('a choice made while loading is not undone by the load', () async {
    final settings = PortableCallSettings();
    final loading = settings.load();
    await settings.setEnabled(true);
    await loading;
    expect(settings.enabled, isTrue);
  });

  test('it is a plain preference, not a secret', () async {
    final settings = PortableCallSettings();
    await settings.setEnabled(true);
    expect(
      await SharedPreferencesAsync().getBool('hermes.portable_calls'),
      isTrue,
    );
  });

  test('it notifies when it changes', () async {
    final settings = PortableCallSettings();
    await settings.load();
    var notified = 0;
    settings.addListener(() => notified++);
    await settings.setEnabled(true);
    await settings.setEnabled(true);
    expect(notified, 1);
  });

  group('callsAvailable', () {
    Future<PortableCallSettings> settings(bool on) async {
      final value = PortableCallSettings();
      await value.setEnabled(on);
      return value;
    }

    test('iOS always, whatever the switch says', () async {
      expect(callsAvailable(TargetPlatform.iOS, null), isTrue);
      expect(callsAvailable(TargetPlatform.iOS, await settings(false)), isTrue);
    });

    for (final platform in [
      TargetPlatform.android,
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
    ]) {
      test('$platform only with the switch on', () async {
        expect(callsAvailable(platform, null), isFalse);
        expect(callsAvailable(platform, await settings(false)), isFalse);
        expect(callsAvailable(platform, PortableCallSettings()), isFalse);
        expect(callsAvailable(platform, await settings(true)), isTrue);
      });
    }

    test('the switch is not shown on iOS, shown elsewhere', () {
      expect(PortableCallSettings.offeredOn(TargetPlatform.iOS), isFalse);
      expect(PortableCallSettings.offeredOn(TargetPlatform.android), isTrue);
      expect(PortableCallSettings.offeredOn(TargetPlatform.macOS), isTrue);
      expect(PortableCallSettings.offeredOn(TargetPlatform.windows), isTrue);
      expect(PortableCallSettings.offeredOn(TargetPlatform.linux), isTrue);
    });
  });
}
