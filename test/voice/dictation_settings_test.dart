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

  test('dictates through Hermes until the user picks otherwise', () async {
    final settings = DictationSettings();
    await settings.load();

    expect(settings.engine, DictationEngine.hermes);
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

  test('an unknown saved value falls back to Hermes', () async {
    await SharedPreferencesAsync().setString(
      'hermes.dictation_engine',
      'cloud',
    );
    final settings = DictationSettings();
    await settings.load();

    expect(settings.engine, DictationEngine.hermes);
  });
}
