import 'dart:async';
import 'dart:typed_data';

import 'package:hermes_app/src/voice/voice_recorder.dart';

/// A microphone the test speaks into.
class FakeVoiceRecorder implements VoiceRecorder {
  FakeVoiceRecorder({this.permission = true});

  bool permission;
  int? sampleRate;
  var starts = 0;
  var stops = 0;
  StreamController<Uint8List>? _pcm;

  bool get recording => _pcm != null;

  @override
  Future<bool> requestPermission() async => permission;

  @override
  Future<Stream<Uint8List>> start({required int sampleRate}) async {
    this.sampleRate = sampleRate;
    starts++;
    return (_pcm = StreamController()).stream;
  }

  /// Feeds [samples] (16-bit, mono) as one chunk.
  void speak(List<int> samples) {
    final bytes = ByteData(samples.length * 2);
    for (var i = 0; i < samples.length; i++) {
      bytes.setInt16(i * 2, samples[i], Endian.little);
    }
    _pcm?.add(bytes.buffer.asUint8List());
  }

  @override
  Future<void> stop() async {
    stops++;
    final pcm = _pcm;
    _pcm = null;
    await pcm?.close();
  }

  @override
  Future<void> dispose() => stop();
}
