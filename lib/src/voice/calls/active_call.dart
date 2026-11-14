import 'package:flutter/foundation.dart';

import '../widgets/hands_free_strip.dart';
import 'voice_call.dart';

/// The call that is running, for places outside the chat that must show it
/// (the App Lock cover, the shell's Hands-free strip). One per app.
///
/// It tells only what the strip shows (a fixed state, never words) and offers
/// End. It notifies when that changes, not on every tick of the call.
class ActiveCallRegistry extends ChangeNotifier {
  VoiceCall? _call;
  bool _active = false;
  HandsFreeMicrophone _microphone = HandsFreeMicrophone.opening;

  VoiceCall? get call => _call;

  /// Whether a call is running, so its microphone may be open.
  bool get active => _active;

  /// Whether the call ended without confirming that the microphone closed,
  /// which the strip says rather than hiding.
  bool get microphoneMayBeOpen =>
      _call != null && _call!.ended && _call!.microphoneUnconfirmed;

  /// What the microphone is doing. Meaningful while [active].
  HandsFreeMicrophone get microphone => _microphone;

  void attach(VoiceCall call) {
    if (identical(_call, call)) return;
    _call?.removeListener(_changed);
    _call = call;
    call.addListener(_changed);
    _active = false;
    _changed(force: true);
  }

  /// Ends the running call. The same End the call screen has.
  Future<void> end() => _call?.end() ?? Future.value();

  void _changed({bool force = false}) {
    final call = _call;
    final active = call != null && !call.ended;
    final microphone = call == null || call.phase == CallPhase.connecting
        ? HandsFreeMicrophone.opening
        : call.muted
        ? HandsFreeMicrophone.muted
        : call.capturePaused
        ? HandsFreeMicrophone.paused
        : HandsFreeMicrophone.open;
    if (!force && active == _active && microphone == _microphone) return;
    _active = active;
    _microphone = microphone;
    notifyListeners();
  }

  @override
  void dispose() {
    _call?.removeListener(_changed);
    super.dispose();
  }
}
