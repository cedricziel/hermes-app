import 'dart:async';

import 'package:flutter/services.dart';

/// The macOS application as a whole, as opposed to one of its windows
/// ([MacWindow]). The runner's `AppDelegate` answers the channel.
abstract final class MacApp {
  static const _channel = MethodChannel('hermes_app/app');
  static final _windowless = StreamController<bool>.broadcast();
  static final _dockMenuCalls = StreamController<MethodCall>.broadcast();
  static var _listening = false;

  /// Quits the app as Cmd-Q does, for callers that have no menu item to
  /// trigger it: closing the last window no longer ends the app.
  static Future<void> terminate() => _channel.invokeMethod<void>('terminate');

  /// Whether the app runs with no window on screen or in the Dock, as the
  /// runner sees it, emitted when that changes. Covered, hidden or
  /// full-screen windows on another Space do not count.
  static Stream<bool> get windowlessChanges {
    _listen();
    return _windowless.stream;
  }

  /// Gives the runner what its Dock menu shows. AppKit asks for that menu
  /// synchronously, so the runner keeps this copy in memory.
  static Future<void> setDockMenu(Map<String, Object?> snapshot) =>
      _channel.invokeMethod<void>('dockMenu', snapshot);

  /// The Dock menu choices the runner reports (`dockNewChat`, `dockOpenChat`).
  static Stream<MethodCall> get dockMenuCalls {
    _listen();
    return _dockMenuCalls.stream;
  }

  static void _listen() {
    if (_listening) return;
    _listening = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'windowless' && call.arguments is bool) {
        _windowless.add(call.arguments as bool);
      } else if (call.method.startsWith('dock')) {
        _dockMenuCalls.add(call);
      }
    });
  }
}
