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
  bool _mayBeOpen = false;
  bool _dismissed = false;
  bool _disposed = false;
  Object? _screenOwner;

  VoiceCall? get call => _call;

  /// Whether a call is running, so its microphone may be open.
  bool get active => _active;

  /// Whether the call ended without confirming that the microphone closed,
  /// which the strip says rather than hiding.
  bool get microphoneMayBeOpen =>
      !_dismissed &&
      _call != null &&
      _call!.ended &&
      _call!.microphoneUnconfirmed;

  /// What the strip shows now: the running call's microphone, the unconfirmed
  /// close of a call that ended, or null for no strip.
  HandsFreeMicrophone? get strip => active
      ? microphone
      : microphoneMayBeOpen
      ? HandsFreeMicrophone.mayBeOpen
      : null;

  /// The user has read the "may still be open" mark and closed it. It comes
  /// back with the next call that ends the same way.
  void dismissMayBeOpen() {
    if (_dismissed) return;
    _dismissed = true;
    notifyListeners();
  }

  /// Whether the call screen is open, so the strip leaves End to it.
  bool get screenOpen => _screenOwner != null;

  /// What the microphone is doing. Meaningful while [active].
  HandsFreeMicrophone get microphone => _microphone;

  void attach(VoiceCall call) {
    if (identical(_call, call)) return;
    _call?.removeListener(_changed);
    _call = call;
    call.addListener(_changed);
    _active = false;
    _mayBeOpen = false;
    _dismissed = false;
    _changed(force: true);
  }

  /// The call screen opened for [owner]. Only that owner closes it again, so
  /// a screen replaced by a newer one (the shell is rebuilt for a new account
  /// before the old one is disposed) cannot close the new one's mark.
  void screenOpened(Object owner) {
    if (_disposed || identical(_screenOwner, owner)) return;
    _screenOwner = owner;
    notifyListeners();
  }

  void screenClosed(Object owner) {
    if (_disposed || !identical(_screenOwner, owner)) return;
    _screenOwner = null;
    notifyListeners();
  }

  /// The owner of [call] is going away (its chat is disposed) and will drop
  /// the call right after. A disposed call tells nobody that it ended, so this
  /// ends it first and takes what the strip still has to say from it:
  /// whether its microphone was confirmed closed. A call that is not the
  /// current one is left alone.
  Future<void> release(VoiceCall call) async {
    if (!identical(_call, call)) return;
    call.removeListener(_changed);
    try {
      await call.end();
    } on Object {
      // The call guards each step itself; the state below is read either way.
    }
    if (_disposed || !identical(_call, call)) return;
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
        : call.capturePausedForLong
        ? HandsFreeMicrophone.paused
        : HandsFreeMicrophone.open;
    final mayBeOpen = call != null && call.ended && call.microphoneUnconfirmed;
    if (!force &&
        active == _active &&
        microphone == _microphone &&
        mayBeOpen == _mayBeOpen) {
      return;
    }
    _active = active;
    _microphone = microphone;
    _mayBeOpen = mayBeOpen;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _call?.removeListener(_changed);
    super.dispose();
  }
}
