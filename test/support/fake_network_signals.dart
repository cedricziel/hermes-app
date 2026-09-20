import 'dart:async';

import 'package:hermes_app/src/network/network_signals.dart';

class FakeNetworkSignals implements NetworkSignals {
  final _changes = StreamController<void>.broadcast();

  @override
  bool? vpnActive;

  @override
  Stream<void> get changes => _changes.stream;

  /// The connection changed, or the app came back to the foreground.
  void change() => _changes.add(null);

  Future<void> close() => _changes.close();
}
