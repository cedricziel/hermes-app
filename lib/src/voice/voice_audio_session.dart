import 'dart:async';

import 'package:audio_session/audio_session.dart';

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
/// the last one leaves, so a later owner starts from its own category. CallKit
/// owns the session during a call; nobody acquires it then.
///
/// Nothing here runs before a user action: no acquire at launch or resume.
class VoiceAudioSession {
  VoiceAudioSession({this._port = const PluginAudioSessionPort()});

  static final shared = VoiceAudioSession();

  final AudioSessionPort _port;
  final _owners = <Object>{};
  Future<void> _tail = Future.value();

  /// Whether any owner holds the session.
  bool get held => _owners.isNotEmpty;

  /// True once [owner] holds the session; false when the platform refused it
  /// (nothing stays active then).
  Future<bool> acquire(Object owner, AudioSessionConfiguration configuration) =>
      _serial(() async {
        if (_owners.contains(owner)) return true;
        final first = _owners.isEmpty;
        _owners.add(owner);
        if (!first) return true;
        try {
          await _port.configure(configuration);
          if (await _port.setActive(true)) return true;
        } on Object {
          // Falls through to the refusal below.
        }
        _owners.remove(owner);
        await _deactivate();
        return false;
      });

  /// Gives the session back; does nothing for an owner that does not hold it.
  Future<void> release(Object owner) => _serial(() async {
    if (!_owners.remove(owner) || _owners.isNotEmpty) return;
    await _deactivate();
  });

  Future<void> _deactivate() async {
    try {
      await _port.setActive(
        false,
        options: AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation,
      );
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
