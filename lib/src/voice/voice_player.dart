import 'dart:async';
import 'dart:io';

import 'package:media_kit/media_kit.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';

import 'voice_audio_focus.dart';
import 'voice_audio_session.dart';

/// The session a voice message or spoken reply plays in. `setActive(false)`
/// takes its options from here, so every deactivation tells the apps this one
/// interrupted (music, video) to resume, and on Android gives the focus back
/// as a transient grant that may duck instead of taking it for good. Others
/// are paused, not ducked: libmpv's own audio output, not this session, would
/// decide whether a ducking category holds on iOS.
final AudioSessionConfiguration voicePlaybackSession =
    const AudioSessionConfiguration.speech().copyWith(
      avAudioSessionSetActiveOptions:
          AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation,
      androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck,
      androidWillPauseWhenDucked: true,
    );

/// A native player for one downloaded audio file; replaceable in tests.
abstract class VoicePlayer extends ChangeNotifier {
  bool get playing;
  bool get completed;
  bool get failed;
  Duration get position;
  Duration get duration;
  Future<void> load(String path);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
}

class NativeVoicePlayer extends VoicePlayer {
  NativeVoicePlayer({Player? player, VoiceAudioSession? audioSession})
    : _audio = audioSession ?? VoiceAudioSession.shared {
    MediaKit.ensureInitialized();
    _player =
        player ??
        Player(
          configuration: const PlayerConfiguration(
            title: 'Hermes voice message',
            protocolWhitelist: ['file'],
          ),
        );
    _subscriptions.addAll([
      _player.stream.playing.listen((value) {
        _playing = value;
        notifyListeners();
      }, onError: _onError),
      _player.stream.completed.listen((value) {
        _completed = value;
        if (value) {
          _playing = false;
          unawaited(_giveBack());
        }
        notifyListeners();
      }, onError: _onError),
      _player.stream.duration.listen((value) {
        _duration = value;
        notifyListeners();
      }, onError: _onError),
      _player.stream.position.listen((value) {
        _position = value;
        notifyListeners();
      }, onError: _onError),
      _player.stream.error.listen(
        (error) => _onError(error, StackTrace.current),
      ),
    ]);
    VoiceAudioFocus.shared.addListener(_focusChanged);
  }

  // The bundled audio-only libmpv/FFmpeg decoder handles Ogg/Vorbis and
  // Ogg/Opus on Apple platforms too, where AVPlayer cannot play them.
  late final Player _player;
  final VoiceAudioSession _audio;
  final _subscriptions = <StreamSubscription<dynamic>>[];
  bool _playing = false;
  bool _disposed = false;
  int _intent = 0;
  void _focusChanged() {
    if (!VoiceAudioFocus.shared.inCall) _sessionReady = null;
  }

  bool _observesSession = false;
  Future<void>? _sessionReady;
  bool _completed = false;
  bool _failed = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  bool get playing => _playing;
  @override
  bool get completed => _completed;
  @override
  bool get failed => _failed;
  @override
  Duration get position => _position;
  @override
  Duration get duration => _duration;

  void _onError(Object error, StackTrace stack) {
    if (_disposed) return;
    _failed = true;
    _playing = false;
    notifyListeners();
  }

  @override
  Future<void> load(String path) async {
    _failed = false;
    _completed = false;
    _position = _duration = Duration.zero;
    // A file in the app's cache: the native player never receives session
    // tokens or server URLs, and the existing downloader owns token refresh.
    await _player.open(Media(File(path).uri.toString()), play: false);
    if (_disposed) return;
    _duration = _player.state.duration;
    notifyListeners();
  }

  @override
  Future<void> play() async {
    final intent = ++_intent;
    try {
      await (_sessionReady ??= _prepareSession());
    } on Object {
      _sessionReady = null;
      rethrow;
    }
    if (_disposed || intent != _intent || VoiceAudioFocus.shared.inCall) return;
    if (!await _audio.acquire(this, voicePlaybackSession)) {
      throw StateError('Audio focus unavailable');
    }
    if (_disposed || intent != _intent || VoiceAudioFocus.shared.inCall) {
      await _giveBack();
      return;
    }
    await _player.play();
  }

  // A call that has taken the session (it is the focus owner before it pauses
  // the players) is told nothing by this player: it is only dropped from the
  // session's owners, so a later recording finds the session free.
  Future<void> _giveBack() => VoiceAudioFocus.shared.inCall
      ? _audio.forget(this)
      : _audio.release(this);

  Future<void> _prepareSession() async {
    final session = await AudioSession.instance;
    if (_disposed) return;
    if (VoiceAudioFocus.shared.inCall) throw StateError('Call audio is active');
    if (_observesSession) return;
    _observesSession = true;
    void interrupt() => unawaited(pause().catchError((Object _) {}));
    _subscriptions.addAll([
      session.interruptionEventStream.listen((event) {
        if (event.begin) interrupt();
      }),
      session.becomingNoisyEventStream.listen((_) => interrupt()),
    ]);
  }

  @override
  Future<void> pause() async {
    ++_intent;
    await _sessionReady?.catchError((Object _) {});
    await _player.pause();
    await _giveBack();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  void dispose() {
    _disposed = true;
    ++_intent;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_player.dispose().catchError((Object _) {}));
    unawaited(_giveBack());
    VoiceAudioFocus.shared.removeListener(_focusChanged);
    super.dispose();
  }
}
