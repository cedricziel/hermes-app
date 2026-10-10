import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/voice/dictation_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Runs [onRead] while the saved engine is being read.
class _HookedPrefs extends SharedPreferencesAsync {
  _HookedPrefs(this.onRead);

  final void Function() onRead;

  @override
  Future<String?> getString(String key) async {
    onRead();
    return super.getString(key);
  }
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('is not loaded until load completes, and tells listeners', () async {
    final settings = DictationSettings();
    var told = 0;
    settings.addListener(() => told++);
    expect(settings.loaded, isFalse);

    await settings.load();

    expect(settings.loaded, isTrue);
    expect(told, 1);
  });

  for (final (platform, engine) in [
    (TargetPlatform.iOS, DictationEngine.device),
    (TargetPlatform.macOS, DictationEngine.device),
    (TargetPlatform.android, DictationEngine.hermes),
    (TargetPlatform.windows, DictationEngine.hermes),
    (TargetPlatform.linux, DictationEngine.hermes),
  ]) {
    test(
      'on ${platform.name} dictates with $engine until the user picks',
      () async {
        debugDefaultTargetPlatformOverride = platform;
        try {
          final settings = DictationSettings();
          await settings.load();

          expect(settings.engine, engine);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  }

  test('a saved Hermes pick wins over the on-device default', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await DictationSettings().setEngine(DictationEngine.hermes);
      final relaunched = DictationSettings();
      await relaunched.load();

      expect(relaunched.engine, DictationEngine.hermes);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  test('keeps the pick across launches', () async {
    await DictationSettings().setEngine(DictationEngine.device);

    final relaunched = DictationSettings();
    await relaunched.load();

    expect(relaunched.engine, DictationEngine.device);
  });

  test('a pick made while loading wins over the saved one', () async {
    await DictationSettings().setEngine(DictationEngine.device);
    late DictationSettings settings;
    settings = DictationSettings(
      prefs: _HookedPrefs(() => settings.setEngine(DictationEngine.hermes)),
    );

    await settings.load();

    expect(settings.engine, DictationEngine.hermes);
  });

  test('an unknown saved value falls back to the default', () async {
    await SharedPreferencesAsync().setString(
      'hermes.dictation_engine',
      'cloud',
    );
    final settings = DictationSettings();
    await settings.load();

    expect(settings.engine, DictationEngine.hermes);
  });
}
