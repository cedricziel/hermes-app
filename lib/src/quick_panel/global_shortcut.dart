import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The quick panel's global shortcut, as the main engine sees it (macOS).
/// KeyboardShortcuts registers and stores the chord natively; Dart learns
/// only that it was pressed and whether one is set.
abstract interface class GlobalShortcut {
  /// Each press of the shortcut, in whatever app is in front.
  Stream<void> get presses;

  /// Each time the user records (true) or clears (false) the shortcut.
  Stream<bool> get changes;

  Future<bool> isSet();
}

/// [GlobalShortcut] over the Runner's `hermes_app/quick_panel` channel.
class ChannelGlobalShortcut implements GlobalShortcut {
  ChannelGlobalShortcut() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'pressed':
          _presses.add(null);
        case 'changed' when call.arguments is bool:
          _changes.add(call.arguments as bool);
      }
    });
  }

  static const _channel = MethodChannel('hermes_app/quick_panel');

  final _presses = StreamController<void>.broadcast();
  final _changes = StreamController<bool>.broadcast();

  @override
  Stream<void> get presses => _presses.stream;

  @override
  Stream<bool> get changes => _changes.stream;

  @override
  Future<bool> isSet() async {
    try {
      return await _channel.invokeMethod<bool>('isSet') ?? false;
    } on Object catch (error) {
      debugPrint('Could not read the quick panel shortcut: $error');
      return false;
    }
  }
}
