import 'package:flutter/foundation.dart';

/// For a loader that falls back to its default when the preferences store
/// cannot be read: keeps the failure visible to the crash reporter, which
/// `Telemetry.logUncaughtErrors` feeds from `FlutterError.reportError`, so a
/// broken store (the 0.1.75 Android build's `NoSuchMethodError`) is not lost
/// behind the fallback. [where] is a fixed name for the setting, never a value.
void reportUnreadablePrefs(Object error, StackTrace stack, String where) {
  FlutterError.reportError(
    FlutterErrorDetails(
      exception: error,
      stack: stack,
      library: 'hermes_app',
      context: ErrorDescription('reading $where'),
    ),
  );
}

/// Reads one saved value for a loader that falls back to its default: null
/// when nothing is saved, [ifUnreadable] when the store cannot be read (null
/// unless the safe choice is another). The failure goes through
/// [reportUnreadablePrefs], so a broken store is not lost behind the default.
///
/// A loader that reads several values at once wraps them in one `try` with a
/// catch that calls [reportUnreadablePrefs], to report once.
Future<T?> readSaved<T>(
  Future<T?> Function() read,
  String where, {
  T? ifUnreadable,
}) async {
  try {
    return await read();
  } on Object catch (error, stack) {
    reportUnreadablePrefs(error, stack, where);
    return ifUnreadable;
  }
}
