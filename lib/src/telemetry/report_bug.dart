import 'package:flutter/foundation.dart';

/// For a catch-all that has to keep its screen out of a stuck state: hands an
/// [Error] (a bug, as opposed to a failed request, which is an `Exception`)
/// to the crash reporter and returns, so the caller still shows its failure.
/// Exceptions pass silently; the caller already turns them into state.
///
/// Goes through `FlutterError.reportError`, which `Telemetry.logUncaughtErrors`
/// listens to. [where] is a fixed name for the place, never user data.
void reportBug(Object error, StackTrace stack, String where) {
  if (error is! Error) return;
  FlutterError.reportError(
    FlutterErrorDetails(
      exception: error,
      stack: stack,
      library: 'hermes_app',
      context: ErrorDescription(where),
    ),
  );
}
