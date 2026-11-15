import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

import 'voice_audio_focus.dart';
import 'voice_audio_session.dart';

/// The microphone, as a stream of 16-bit little-endian mono PCM.
abstract interface class VoiceRecorder {
  /// Whether the app may use the microphone, asking the user the first time.
  Future<bool> requestPermission();

  /// Starts capturing at [sampleRate]; the stream ends when [stop] is called.
  Future<Stream<Uint8List>> start({required int sampleRate});

  Future<void> stop();

  Future<void> dispose();
}

/// [VoiceRecorder] on the `record` plugin, which captures on every platform
/// the app runs on. The plugin is only reached once dictation is used.
class RecordVoiceRecorder implements VoiceRecorder {
  RecordVoiceRecorder({VoiceAudioSession? session})
    : _session = session ?? VoiceAudioSession.shared;

  final VoiceAudioSession _session;
  AudioRecorder? _plugin;

  AudioRecorder get _recorder => _plugin ??= AudioRecorder();

  @override
  Future<bool> requestPermission() => _recorder.hasPermission();

  // The plugin never deactivates the session it activates, which would leave
  // other apps' audio paused for good; the session is given back on every way
  // a recording ends (stop, a failed start, dispose). During a call CallKit
  // owns the session and is left alone.
  @override
  Future<Stream<Uint8List>> start({required int sampleRate}) async {
    final inCall = VoiceAudioFocus.shared.inCall;
    if (!inCall) {
      await _session.acquire(this, voiceRecordingSession, reconfigure: true);
    }
    try {
      return await _recorder.startStream(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: sampleRate,
          numChannels: 1,
          noiseSuppress: true,
        ),
      );
    } on Object {
      await _session.release(this);
      rethrow;
    }
  }

  @override
  Future<void> stop() async {
    try {
      final recorder = _plugin;
      if (recorder != null && await recorder.isRecording()) {
        await recorder.stop();
      }
    } finally {
      await _session.release(this);
    }
  }

  @override
  Future<void> dispose() async {
    try {
      await _plugin?.dispose();
    } finally {
      await _session.release(this);
    }
  }
}
