import 'package:flutter/services.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/types.dart';

/// A preferences store whose reads fail the way `shared_preferences_android`
/// did in the 0.1.75 release build: a [PlatformException] from the JNI lookup.
base class UnreadablePrefs extends InMemorySharedPreferencesAsync {
  UnreadablePrefs() : super.empty();

  static PlatformException get _failure => PlatformException(
    code: 'channel-error',
    message:
        'java.lang.NoSuchMethodError: no non-static method '
        'SharedPreferencesAsyncApiRegistrar.getString',
  );

  @override
  Future<String?> getString(String key, SharedPreferencesOptions options) =>
      Future.error(_failure);

  @override
  Future<bool?> getBool(String key, SharedPreferencesOptions options) =>
      Future.error(_failure);
}
