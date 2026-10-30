import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/account_key.dart';
import 'package:hermes_app/src/bot_screen/takeover_setting.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  late SharedPreferencesAsync prefs;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    prefs = SharedPreferencesAsync();
  });

  test('asks by default', () async {
    final setting = TakeoverSetting(accountKey: 'a', prefs: prefs);

    expect(await setting.skipsConfirmation(), isFalse);
  });

  test('stops asking once told, for that account only', () async {
    final mine = TakeoverSetting(accountKey: 'mine', prefs: prefs);
    final other = TakeoverSetting(accountKey: 'other', prefs: prefs);

    await mine.skipConfirmation();

    expect(await mine.skipsConfirmation(), isTrue);
    expect(await other.skipsConfirmation(), isFalse);
    expect(
      await TakeoverSetting(
        accountKey: 'mine',
        prefs: prefs,
      ).skipsConfirmation(),
      isTrue,
    );
  });

  test(
    'is one boolean under the account key, never the server address',
    () async {
      final key = accountKeyFor('https://hermes.example.org', null);

      await TakeoverSetting(accountKey: key, prefs: prefs).skipConfirmation();

      final saved = await prefs.getKeys();
      expect(saved, {'bot_screen.takeover.skip_confirm.$key'});
      expect(saved.join(), isNot(contains('example.org')));
      expect(await prefs.getBool(saved.single), isTrue);
    },
  );

  test('storage that cannot be read means asking', () async {
    final setting = TakeoverSetting(accountKey: 'a', prefs: _Broken());

    expect(await setting.skipsConfirmation(), isFalse);
    await setting.skipConfirmation();
  });
}

/// Preferences that throw whatever they are asked.
class _Broken implements SharedPreferencesAsync {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError('broken');
}
