import 'dart:async';

import 'package:flutter/services.dart';

/// The macOS application as a whole, as opposed to one of its windows
/// ([MacWindow]). The runner's `AppDelegate` answers the channel.
abstract final class MacApp {
  static const _channel = MethodChannel('hermes_app/app');
  static final _windowless = StreamController<bool>.broadcast();
  static var _listening = false;

  /// Quits the app as Cmd-Q does, for callers that have no menu item to
  /// trigger it: closing the last window no longer ends the app.
  static Future<void> terminate() => _channel.invokeMethod<void>('terminate');

  /// Whether the app runs with no window on screen or in the Dock, as the
  /// runner sees it, emitted when that changes. Covered, hidden or
  /// full-screen windows on another Space do not count.
  static Stream<bool> get windowlessChanges {
    if (!_listening) {
      _listening = true;
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'windowless' && call.arguments is bool) {
          _windowless.add(call.arguments as bool);
        }
      });
    }
    return _windowless.stream;
  }
}
