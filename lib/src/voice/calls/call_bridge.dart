import 'package:flutter/services.dart';

/// What the platform's call audio does for [VoiceCall]. Its `events` carry
/// `activated`, `pcm`, `muted`, `route`, `audioReset`, `deactivated` (with
/// `reason: focus` when the system took audio focus away), `ended`, `error`
/// and `capturePaused` (`paused`, and a fixed `reason`), which the bridge also
/// sends for a pause it makes itself.
abstract interface class CallBridge {
  Stream<Map<String, Object?>> get events;

  /// Whether the user can speak over the reply: true only where the platform
  /// cancels the echo of what the call plays (Apple's voice processing).
  bool get bargeIn;
  Future<void> start(String id, String name);
  Future<void> connected();
  Future<void> end();
  Future<void> mute(bool muted);
  Future<void> speaker(bool enabled);
  Future<void> play(Uint8List pcm, int sampleRate);
  Future<void> drain();
  Future<void> stopPlayback();

  /// Stops feeding microphone audio, without CallKit's mute: Waiting for you
  /// and the tones use it. Idempotent.
  Future<void> pauseCapture();
  Future<void> resumeCapture();

  /// Ends the capture and nothing else (no playback, no session). The first
  /// step of every teardown. [id] is the call's id from [start]: a stop of an
  /// earlier call does nothing to a later one.
  Future<void> stopCapture(String id);
}

/// Only CallKit's activated audio session opens the microphone. The Dart
/// conversation never activates or configures an AVAudioSession itself.
class AppleCallBridge implements CallBridge {
  static const _methods = MethodChannel('hermes_app/calls');
  static const _events = EventChannel('hermes_app/calls/events');

  @override
  bool get bargeIn => true;

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
  @override
  Future<void> pauseCapture() => _methods.invokeMethod('pauseCapture');
  @override
  Future<void> resumeCapture() => _methods.invokeMethod('resumeCapture');
  @override
  Future<void> stopCapture(String id) =>
      _methods.invokeMethod('stopCapture', {'id': id});
}
