import 'dart:async';
import 'dart:typed_data';

import 'package:hermes_app/src/voice/calls/call_agent.dart';
import 'package:hermes_app/src/voice/calls/call_bridge.dart';

class FakeCallBridge implements CallBridge {
  final controller = StreamController<Map<String, Object?>>.broadcast(
    sync: true,
  );
  final played = <(List<int>, int)>[];
  int starts = 0, ends = 0, stops = 0, connections = 0;
  Completer<void>? drainGate;
  @override
  Stream<Map<String, Object?>> get events => controller.stream;
  void emit(String type, [Map<String, Object?> data = const {}]) =>
      controller.add({'type': type, ...data});
  @override
  Future<void> start(String id, String name) async {
    starts++;
  }

  @override
  Future<void> connected() async {
    connections++;
  }

  @override
  Future<void> end() async {
    ends++;
  }

  @override
  Future<void> mute(bool muted) async {
    emit('muted', {'muted': muted});
  }

  @override
  Future<void> speaker(bool enabled) async {
    emit('route', {'name': 'Speaker', 'speaker': enabled});
  }

  @override
  Future<void> play(Uint8List pcm, int sampleRate) async {
    played.add((pcm.toList(), sampleRate));
  }

  @override
  Future<void> drain() async {
    await drainGate?.future;
  }

  @override
  Future<void> stopPlayback() async {
    stops++;
  }
}

class FakeCallAgent implements CallAgent {
  final prompts = <String>[];
  int interrupts = 0;
  void Function(String)? text;
  void Function(bool)? attention;
  Completer<void>? pending;
  @override
  Future<void> reply(
    String prompt, {
    required void Function(String) onText,
    required void Function(bool) onAttention,
  }) {
    prompts.add(prompt);
    text = onText;
    attention = onAttention;
    return (pending = Completer<void>()).future;
  }

  @override
  Future<void> interrupt() async {
    interrupts++;
    if (pending?.isCompleted == false) pending!.complete();
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
