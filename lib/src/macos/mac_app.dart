import 'package:flutter/services.dart';

/// The macOS application as a whole, as opposed to one of its windows
/// ([MacWindow]). The runner's `AppDelegate` answers the channel.
abstract final class MacApp {
  static const _channel = MethodChannel('hermes_app/app');

  /// Quits the app as Cmd-Q does, for callers that have no menu item to
  /// trigger it: closing the last window no longer ends the app.
  static Future<void> terminate() => _channel.invokeMethod<void>('terminate');
}
