import 'dart:io';

import 'package:flutter/foundation.dart';

import '../chat/media/media_source.dart';
import 'voice_player.dart';
import 'voice_audio_focus.dart';

/// Owns the single player in a transcript. Fetches only on Play, serializes
/// actions, and never resumes a download after leaving the app or the thread.
class VoicePlayback extends ChangeNotifier {
  VoicePlayback({VoicePlayer Function()? createPlayer})
    : _createPlayer = createPlayer ?? NativeVoicePlayer.new {
    VoiceAudioFocus.shared.register(pause);
    VoiceAudioFocus.shared.addListener(_focusChanged);
  }

  bool get blocked => VoiceAudioFocus.shared.inCall;
  void _focusChanged() {
    if (!_disposed) notifyListeners();
  }

  final VoicePlayer Function() _createPlayer;
  VoicePlayer? _player;
  String? _active;
  bool _loading = false;
  bool _loaded = false;
  bool _disposed = false;
  int _generation = 0;
  MediaFailure? _fetchFailure;
  String? _error;

  String? get active => _active;
  bool get loading => _loading;
  bool get playing => _player?.playing == true && _error == null;
  Duration get position => _loaded ? _player!.position : Duration.zero;
  Duration get duration => _loaded ? _player!.duration : Duration.zero;
  String? get error => _error;
  bool get canRetry =>
      _fetchFailure == null || _fetchFailure == MediaFailure.failed;

  void _changed() {
    if (_disposed) return;
    if (_player?.failed == true) {
      _loaded = false;
      _error = 'Could not play this audio. Try again or save the file.';
    }
    notifyListeners();
  }

  Future<void> toggle(String id, Future<File> Function() fetch) async {
    if (_disposed || _loading || blocked) return;
    final generation = ++_generation;
    final needsLoad = _active != id || !_loaded;
    _active = id;
    if (needsLoad) _loaded = false;
    _loading = true;
    _error = null;
    _fetchFailure = null;
    notifyListeners();
    bool current() => !_disposed && !blocked && generation == _generation;
    try {
      final player = _player ??= (_createPlayer()..addListener(_changed));
      if (needsLoad) {
        await player.pause();
        if (!current()) return;
        final file = await fetch();
        if (!current()) return;
        await player.load(file.path);
        if (!current()) return;
        if (player.failed) throw StateError('Audio load failed');
        _loaded = true;
        _error = null;
        await player.play();
      } else if (player.playing) {
        await player.pause();
      } else {
        if (player.completed) await player.seek(Duration.zero);
        if (!current()) return;
        await player.play();
      }
    } on MediaFetchException catch (e) {
      if (!current()) return;
      _fetchFailure = e.reason;
      _error = switch (e.reason) {
        MediaFailure.missing => 'This file is no longer available.',
        MediaFailure.refused => "This file can't be opened from here.",
        MediaFailure.tooLarge => 'This file is too large to download.',
        MediaFailure.failed =>
          'Could not download the audio. Tap to try again.',
      };
    } on Object {
      if (!current()) return;
      _loaded = false;
      _error = 'Could not play this audio. Try again or save the file.';
    } finally {
      if (!_disposed) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> seek(Duration position) async {
    if (_disposed || blocked || !_loaded || _loading) return;
    try {
      final end = duration.inMilliseconds;
      await _player!.seek(
        Duration(milliseconds: position.inMilliseconds.clamp(0, end)),
      );
    } on Object {
      if (_disposed) return;
      _loaded = false;
      _error = 'Could not seek in this audio. Try again.';
      notifyListeners();
    }
  }

  Future<void> pause() async {
    if (_disposed) return;
    ++_generation;
    try {
      await _player?.pause();
    } on Object {
      // The OS may already have suspended its audio session.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    VoiceAudioFocus.shared.unregister(pause);
    VoiceAudioFocus.shared.removeListener(_focusChanged);
    ++_generation;
    _player?.removeListener(_changed);
    _player?.dispose();
    super.dispose();
  }
}
