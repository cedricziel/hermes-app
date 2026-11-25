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
