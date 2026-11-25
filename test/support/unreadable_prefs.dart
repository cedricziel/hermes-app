import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/types.dart';

/// A preferences store whose reads fail the way `shared_preferences_android`
/// did in the 0.1.75 release build: a [PlatformException] from the JNI lookup.
base class UnreadablePrefs extends InMemorySharedPreferencesAsync {
  UnreadablePrefs() : super.empty();

  /// Reads fail while true; set it false to read what was written meanwhile.
  var unreadable = true;

  static PlatformException get _failure => PlatformException(
    code: 'channel-error',
    message:
        'java.lang.NoSuchMethodError: no non-static method '
        'SharedPreferencesAsyncApiRegistrar.getString',
  );

  @override
  Future<String?> getString(String key, SharedPreferencesOptions options) =>
      unreadable ? Future.error(_failure) : super.getString(key, options);

  @override
  Future<bool?> getBool(String key, SharedPreferencesOptions options) =>
      unreadable ? Future.error(_failure) : super.getBool(key, options);

  @override
  Future<int?> getInt(String key, SharedPreferencesOptions options) =>
      unreadable ? Future.error(_failure) : super.getInt(key, options);

  @override
  Future<double?> getDouble(String key, SharedPreferencesOptions options) =>
      unreadable ? Future.error(_failure) : super.getDouble(key, options);

  @override
  Future<List<String>?> getStringList(
    String key,
    SharedPreferencesOptions options,
  ) => unreadable ? Future.error(_failure) : super.getStringList(key, options);
}

/// Runs [body] and returns the errors it handed to `FlutterError.reportError`.
Future<List<FlutterErrorDetails>> reportedErrors(
  Future<void> Function() body,
) async {
  final reported = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = reported.add;
  try {
    await body();
  } finally {
    FlutterError.onError = previous;
  }
  return reported;
}
