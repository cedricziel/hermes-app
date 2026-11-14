import 'dart:async';
import 'dart:typed_data';

import 'package:hermes_app/src/voice/calls/call_agent.dart';
import 'package:hermes_app/src/voice/calls/call_bridge.dart';

class FakeCallBridge implements CallBridge {
  /// Holds `mute` until completed, like a bridge that confirms later.
  Completer<void>? muteGate;
  final controller = StreamController<Map<String, Object?>>.broadcast(
    sync: true,
  );
  final played = <(List<int>, int)>[];
  int starts = 0, ends = 0, stops = 0, connections = 0;
  int pauses = 0, resumes = 0, captureStops = 0;
  Completer<void>? drainGate;

  /// Every bridge call in order, for teardown-order tests. A test may point
  /// [FakeCallAgent.log] at the same list.
  final log = <String>[];

  /// Holds `start` until completed, like CallKit and the microphone opening.
  Completer<void>? startGate;

  /// Holds `stopCapture` (a hang) or makes it throw.
  Completer<void>? stopCaptureGate;
  Object? stopCaptureError;
  Object? endError, stopPlaybackError, muteError;
  Completer<void>? endGate;
  @override
  bool bargeIn = true;
  @override
  Stream<Map<String, Object?>> get events => controller.stream;
  void emit(String type, [Map<String, Object?> data = const {}]) =>
      controller.add({'type': type, ...data});
  @override
  Future<void> start(String id, String name) async {
    starts++;
    log.add('start');
    await startGate?.future;
  }

  @override
  Future<void> connected() async {
    connections++;
  }

  @override
  Future<void> end() async {
    ends++;
    log.add('end');
    await endGate?.future;
    if (endError != null) await Future<void>.error(endError!);
  }

  @override
  Future<void> mute(bool muted) async {
    await muteGate?.future;
    if (muteError != null) await Future<void>.error(muteError!);
    emit('muted', {'muted': muted});
  }

  @override
  Future<void> speaker(bool enabled) async {
    emit('route', {'name': 'Speaker', 'speaker': enabled});
  }

  @override
  Future<void> play(Uint8List pcm, int sampleRate) async {
    log.add('play');
    played.add((pcm.toList(), sampleRate));
  }

  @override
  Future<void> drain() async {
    await drainGate?.future;
  }

  @override
  Future<void> stopPlayback() async {
    stops++;
    log.add('stopPlayback');
    if (stopPlaybackError != null) await Future<void>.error(stopPlaybackError!);
  }

  @override
  Future<void> pauseCapture() async {
    pauses++;
    log.add('pauseCapture');
    emit('capturePaused', {'paused': true, 'reason': 'request'});
  }

  @override
  Future<void> resumeCapture() async {
    resumes++;
    log.add('resumeCapture');
    emit('capturePaused', {'paused': false, 'reason': 'request'});
  }

  @override
  Future<void> stopCapture() async {
    captureStops++;
    log.add('stopCapture');
    await stopCaptureGate?.future;
    if (stopCaptureError != null) await Future<void>.error(stopCaptureError!);
  }
}

class FakeCallAgent implements CallAgent {
  final prompts = <String>[];
  int interrupts = 0;

  /// Shares [FakeCallBridge.log] when a test sets it.
  List<String>? log;
  Completer<void>? interruptGate;
  Object? interruptError;

  /// Makes `reply` fail at once, like a chat that refuses the turn.
  Object? replyError;

  /// What the thread says, whoever raised it (typed and queued replies too).
  @override
  bool attention = false;
  void Function(bool)? _watcher;
  @override
  void watchAttention(void Function(bool waiting) listener) =>
      _watcher = listener;
  void setThreadAttention(bool waiting) {
    attention = waiting;
    _watcher?.call(waiting);
  }

  void Function(String)? text;
  void Function(bool)? replyAttention;
  Completer<void>? pending;

  /// Keeps `onSubmitted` back until the test calls [submitted].
  bool holdSubmit = false;
  void Function()? onSubmitted;
  void submitted() => onSubmitted?.call();
  @override
  Future<void> reply(
    String prompt, {
    required void Function(String) onText,
    required void Function(bool) onAttention,
    void Function()? onSubmitted,
  }) {
    prompts.add(prompt);
    if (replyError != null) return Future.error(replyError!);
    this.onSubmitted = onSubmitted;
    if (!holdSubmit) onSubmitted?.call();
    text = onText;
    replyAttention = onAttention;
    return (pending = Completer<void>()).future;
  }

  @override
  Future<void> interrupt() async {
    interrupts++;
    log?.add('interrupt');
    if (pending?.isCompleted == false) pending!.complete();
    await interruptGate?.future;
    if (interruptError != null) await Future<void>.error(interruptError!);
  }

  @override
  void dispose() {}
}

Uint8List pcm({int amplitude = 10000, int milliseconds = 100}) {
  final bytes = Uint8List(milliseconds * 16 * 2);
  final view = ByteData.sublistView(bytes);
  for (var i = 0; i < bytes.length; i += 2) {
    view.setInt16(i, (i % 4 == 0 ? 1 : -1) * amplitude, Endian.little);
  }
  return bytes;
}
