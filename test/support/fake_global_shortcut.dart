import 'dart:async';

import 'package:hermes_app/src/quick_panel/global_shortcut.dart';

/// Stands in for the native shortcut: a test presses it and records or
/// clears it.
class FakeGlobalShortcut implements GlobalShortcut {
  FakeGlobalShortcut({this.recorded = false});

  bool recorded;

  /// When set, [isSet] answers only once this completes, like a channel
  /// reply that is still on its way.
  Completer<bool>? pendingIsSet;
  final _presses = StreamController<void>.broadcast(sync: true);
  final _changes = StreamController<bool>.broadcast(sync: true);

  @override
  Stream<void> get presses => _presses.stream;

  @override
  Stream<bool> get changes => _changes.stream;

  @override
  Future<bool> isSet() async => pendingIsSet?.future ?? recorded;

  void press() => _presses.add(null);

  void change({required bool set}) {
    recorded = set;
    _changes.add(set);
  }

  void dispose() {
    _presses.close();
    _changes.close();
  }
}
