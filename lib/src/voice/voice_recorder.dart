import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

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
/// the app runs on.
class RecordVoiceRecorder implements VoiceRecorder {
  final _recorder = AudioRecorder();

  @override
  Future<bool> requestPermission() => _recorder.hasPermission();

  @override
  Future<Stream<Uint8List>> start({required int sampleRate}) =>
      _recorder.startStream(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: sampleRate,
          numChannels: 1,
          noiseSuppress: true,
        ),
      );

  @override
  Future<void> stop() async {
    if (await _recorder.isRecording()) await _recorder.stop();
  }

  @override
  Future<void> dispose() => _recorder.dispose();
}
