import 'dart:async';

import 'package:audio_session/audio_session.dart';

import 'voice_audio_focus.dart';

/// What [VoiceAudioSession] needs of the platform audio session; replaceable
/// in tests, where the plugin's own platform checks cannot be faked.
abstract interface class AudioSessionPort {
  Future<void> configure(AudioSessionConfiguration configuration);

  /// Takes (iOS: activates, Android: requests focus) or gives back the
  /// session; [options] go with an iOS deactivation.
  Future<bool> setActive(
    bool active, {
    AVAudioSessionSetActiveOptions? options,
  });
}

/// [AudioSessionPort] on the `audio_session` plugin.
class PluginAudioSessionPort implements AudioSessionPort {
  const PluginAudioSessionPort();

  @override
  Future<void> configure(AudioSessionConfiguration configuration) async =>
      (await AudioSession.instance).configure(configuration);

  @override
  Future<bool> setActive(
    bool active, {
    AVAudioSessionSetActiveOptions? options,
  }) async => (await AudioSession.instance).setActive(
    active,
    avAudioSessionSetActiveOptions: options,
  );
}

/// What a recording asks of the session. The `record` plugin sets its own
/// category and activates, but never deactivates, so the app configures and
/// deactivates around it: other apps' audio pauses while recording and
/// resumes when it ends.
final AudioSessionConfiguration voiceRecordingSession =
    AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions:
          AVAudioSessionCategoryOptions.defaultToSpeaker |
          AVAudioSessionCategoryOptions.allowBluetooth,
      avAudioSessionSetActiveOptions:
          AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation,
      androidAudioAttributes: const AndroidAudioAttributes(
        contentType: AndroidAudioContentType.speech,
        usage: AndroidAudioUsage.media,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransient,
    );

/// The one owner of the platform audio session for dictation, voice-message
/// recording, voice-message playback and read-aloud. Each takes it with
/// [acquire] and gives it back with [release]; the session is configured when
/// the first owner arrives and deactivated, telling other apps to resume, when
/// the last one leaves (after a short grace, so an owner that pauses just
/// before another one starts does not make other apps resume for a moment),
/// so a later owner starts from its own category. CallKit owns the session
/// during a call; nobody acquires it then, and an owner that is still held
/// when a call starts is dropped with [forget], without a deactivation.
///
/// Nothing here runs before a user action: no acquire at launch or resume.
class VoiceAudioSession {
  VoiceAudioSession({
    this._port = const PluginAudioSessionPort(),
    this.deactivationDelay = const Duration(milliseconds: 250),
    this.callTimeout = const Duration(seconds: 3),
  }) {
    VoiceAudioFocus.shared.addListener(_focusChanged);
  }

  static final shared = VoiceAudioSession();

  final AudioSessionPort _port;

  /// How long the last owner's departure waits for a new owner before the
  /// session is deactivated.
  final Duration deactivationDelay;

  /// Bounds each platform call, so one that never answers cannot block every
  /// later acquire and release.
  final Duration callTimeout;
  final _owners = <Object>{};
  Future<void> _tail = Future.value();
  Timer? _pending;
  bool _active = false;

  /// Whether any owner holds the session.
  bool get held => _owners.isNotEmpty;

  /// True once [owner] holds the session; false when the platform refused it
  /// (nothing stays active then, except for an owner that [reconfigure]s: a
  /// recording, which also applies its configuration over a playback's).
  Future<bool> acquire(
    Object owner,
    AudioSessionConfiguration configuration, {
    bool reconfigure = false,
  }) => _serial(() async {
    _pending?.cancel();
    _pending = null;
    final first = _owners.isEmpty;
    final joined = !_owners.add(owner);
    if (!first && (joined || !reconfigure)) return true;
    try {
      await _port.configure(configuration).timeout(callTimeout);
      if (await _port.setActive(true).timeout(callTimeout)) {
        _active = true;
        return true;
      }
    } on Object {
      // Falls through to the refusal below.
    }
    if (!first) return true;
    // A recording is activated by its plugin whatever the answer, so it stays
    // an owner and gives the session back when it ends.
    if (reconfigure) {
      _active = true;
      return false;
    }
    _owners.remove(owner);
    await _deactivate();
    return false;
  });

  /// Gives the session back; does nothing for an owner that does not hold it.
  Future<void> release(Object owner) => _serial(() async {
    if (!_owners.remove(owner) || _owners.isNotEmpty) return;
    if (deactivationDelay == Duration.zero) return _settle();
    _pending?.cancel();
    _pending = Timer(deactivationDelay, () => unawaited(_serial(_settle)));
  });

  /// Drops [owner] without deactivating: a call has taken the session. When the
  /// call's focus is released with nobody holding the session, it is
  /// deactivated then (a recording that took it meanwhile keeps it).
  Future<void> forget(Object owner) => _serial(() async {
    _owners.remove(owner);
  });

  /// A call that ended (or never got going) while a player it had taken the
  /// session from was forgotten: nobody holds the session and it may still be
  /// active, so the other apps are told now.
  void _focusChanged() {
    if (VoiceAudioFocus.shared.inCall) return;
    unawaited(
      _serial(() async {
        if (_owners.isEmpty && _active && !VoiceAudioFocus.shared.inCall) {
          _pending?.cancel();
          _pending = null;
          await _deactivate();
        }
      }),
    );
  }

  /// Stops listening to the call focus; tests that make their own sessions.
  void dispose() {
    VoiceAudioFocus.shared.removeListener(_focusChanged);
    _pending?.cancel();
  }

  Future<void> _settle() async {
    _pending = null;
    // CallKit owns the session during a call, whoever released before it.
    if (_owners.isNotEmpty || VoiceAudioFocus.shared.inCall) return;
    await _deactivate();
  }

  Future<void> _deactivate() async {
    _active = false;
    try {
      await _port
          .setActive(
            false,
            options: AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation,
          )
          .timeout(callTimeout);
    } on Object {
      // The session may already be gone; there is nothing to retry.
    }
  }

  Future<T> _serial<T>(Future<T> Function() body) {
    final run = _tail.then((_) => body());
    _tail = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }
}
