import 'package:flutter/services.dart';

abstract interface class CallBridge {
  Stream<Map<String, Object?>> get events;
  Future<void> start(String id, String name);
  Future<void> connected();
  Future<void> end();
  Future<void> mute(bool muted);
  Future<void> speaker(bool enabled);
  Future<void> play(Uint8List pcm, int sampleRate);
  Future<void> drain();
  Future<void> stopPlayback();
}

/// Only CallKit's activated audio session opens the microphone. The Dart
/// conversation never activates or configures an AVAudioSession itself.
class AppleCallBridge implements CallBridge {
  static const _methods = MethodChannel('hermes_app/calls');
  static const _events = EventChannel('hermes_app/calls/events');

  @override
  late final events = _events.receiveBroadcastStream().map(
    (event) => Map<String, Object?>.from(event as Map),
  );
  @override
  Future<void> start(String id, String name) =>
      _methods.invokeMethod('start', {'id': id, 'name': name});
  @override
  Future<void> connected() => _methods.invokeMethod('connected');
  @override
  Future<void> end() => _methods.invokeMethod('end');
  @override
  Future<void> mute(bool muted) =>
      _methods.invokeMethod('muted', {'muted': muted});
  @override
  Future<void> speaker(bool enabled) =>
      _methods.invokeMethod('speaker', {'enabled': enabled});
  @override
  Future<void> play(Uint8List pcm, int sampleRate) =>
      _methods.invokeMethod('play', {'pcm': pcm, 'sampleRate': sampleRate});
  @override
  Future<void> drain() => _methods.invokeMethod('drain');
  @override
  Future<void> stopPlayback() => _methods.invokeMethod('stopPlayback');
}
