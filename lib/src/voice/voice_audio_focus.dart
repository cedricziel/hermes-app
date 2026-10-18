import 'package:flutter/foundation.dart';

/// Coordinates audio inside this engine. CallKit still owns system audio
/// activation: ordinary players must neither activate nor deactivate it during
/// a call. Acquisition waits for pending player configuration and pause work.
class VoiceAudioFocus extends ChangeNotifier {
  static final shared = VoiceAudioFocus();
  Object? _owner;
  final _players = <Future<void> Function()>{};
  bool get inCall => _owner != null;

  void register(Future<void> Function() pause) => _players.add(pause);
  void unregister(Future<void> Function() pause) => _players.remove(pause);

  Future<void> acquire(Object owner) async {
    if (_owner != null && !identical(_owner, owner)) {
      throw StateError('Another call owns audio.');
    }
    _owner = owner;
    notifyListeners();
    await Future.wait(_players.toList().map((pause) => pause()))
        .timeout(const Duration(seconds: 10));
  }

  void release(Object owner) {
    if (!identical(_owner, owner)) return;
    _owner = null;
    notifyListeners();
  }
}
