import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/navigation/desktop_menu_bar_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// A store whose reads wait for the test to release them.
base class _SlowReads extends InMemorySharedPreferencesAsync {
  _SlowReads() : super.empty();

  final gate = Completer<void>();

  @override
  Future<bool?> getBool(String key, SharedPreferencesOptions options) async {
    final saved = await super.getBool(key, options);
    await gate.future;
    return saved;
  }
}

void main() {
  test('a choice made while the saved one loads is not overwritten', () async {
    final store = _SlowReads();
    SharedPreferencesAsyncPlatform.instance = store;
    // Saved earlier: off. The read is held back.
    final settings = DesktopMenuBarSettings(prefs: SharedPreferencesAsync());
    addTearDown(settings.dispose);
    final loading = settings.load();

    await settings.setEnabled(true);
    store.gate.complete();
    await loading;

    expect(settings.enabled, isTrue);
  });
}
