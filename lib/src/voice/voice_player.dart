import 'dart:async';
import 'dart:io';

import 'package:media_kit/media_kit.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';

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
  NativeVoicePlayer({Player? player}) {
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
          unawaited(_session?.setActive(false).catchError((Object _) => false));
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
  }

  // The bundled audio-only libmpv/FFmpeg decoder handles Ogg/Vorbis and
  // Ogg/Opus on Apple platforms too, where AVPlayer cannot play them.
  late final Player _player;
  final _subscriptions = <StreamSubscription<dynamic>>[];
  bool _playing = false;
  bool _disposed = false;
  int _intent = 0;
  AudioSession? _session;
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
    if (_disposed || intent != _intent) return;
    if (!await _session!.setActive(true)) {
      throw StateError('Audio focus unavailable');
    }
    if (_disposed || intent != _intent) {
      await _session?.setActive(false);
      return;
    }
    await _player.play();
  }

  Future<void> _prepareSession() async {
    final session = await AudioSession.instance;
    if (_disposed) return;
    _session = session;
    await session.configure(const AudioSessionConfiguration.speech());
    if (_disposed) return;
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
    await _player.pause();
    await _session?.setActive(false);
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
    unawaited(_session?.setActive(false).catchError((Object _) => false));
    super.dispose();
  }
}
