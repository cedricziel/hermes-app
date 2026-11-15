import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/voice/calls/call_config.dart';
import 'package:hermes_app/src/voice/calls/call_speech_stream.dart';
import 'package:hermes_app/src/voice/calls/echo_guard.dart';
import 'package:hermes_app/src/voice/calls/call_tones.dart';
import 'package:hermes_app/src/voice/calls/voice_call.dart';
import 'package:stream_channel/stream_channel.dart';

import 'fakes.dart';

/// Records tones and haptics in the bridge's log, so a test can say what came
/// before what.
class FakeCallTones implements CallTones {
  FakeCallTones(this.log);
  final List<String> log;
  final played = <CallTone>[];
  Completer<void>? gate;
  @override
  Future<void> play(CallTone tone) async {
    log.add('tone:${tone.name}');
    played.add(tone);
    await gate?.future;
  }
}

class FakeCallHaptics implements CallHaptics {
  final calls = <String>[];
  @override
  void submit() => calls.add('submit');
  @override
  void stop() => calls.add('stop');
}

/// One call with fakes for everything around it.
class CallHarness {
  CallHarness() {
    bridge = FakeCallBridge();
    agent = FakeCallAgent()..log = bridge.log;
    tones = FakeCallTones(bridge.log);
    socket = StreamChannelController<Object?>();
    socket.foreign.stream.listen((_) {});
    call = build();
  }

  late FakeCallBridge bridge;
  late FakeCallAgent agent;
  late FakeCallTones tones;
  final haptics = FakeCallHaptics();
  late StreamChannelController<Object?> socket;
  late VoiceCall call;
  final transcripts = <String>[];
  final logged = <(String, Map<String, Object>)>[];
  Future<StreamChannel<Object?>> Function()? openSocket;
  DateTime clock = DateTime(2026, 11, 14, 12);
  int uploads = 0, sockets = 0;

  VoiceCall build({
    bool consented = true,
    VoiceCallConfig? config,
    TargetPlatform platform = TargetPlatform.iOS,
    bool withTones = false,
    Future<void> Function()? releaseLease,
    CallSpeechFallback? fallback,
    bool Function(String)? echoGuard,
    EchoGuard? echo,
  }) => VoiceCall(
    bridge: bridge,
    agent: agent,
    consented: consented,
    platform: platform,
    now: () => clock,
    tones: withTones ? tones : null,
    haptics: withTones ? haptics : null,
    releaseLease: releaseLease,
    loadConfig: config == null ? null : () async => config,
    echoGuard: echo?.isEcho ?? echoGuard,
    replySpoken: echo?.spoken,
    speechFallback: fallback,
    connect: ([_ = const {}]) {
      if (openSocket != null) return openSocket!();
      // Each reply gets its own socket, the latest one in [socket].
      if (sockets++ > 0) {
        socket = StreamChannelController<Object?>();
        socket.foreign.stream.listen((_) {});
      }
      return Future.value(socket.local);
    },
    prepare: () async {},
    events: (name, [attributes = const {}]) => logged.add((name, attributes)),
    transcribe: (_) async {
      uploads++;
      if (transcripts.isEmpty) throw StateError('no transcript queued');
      final next = transcripts.removeAt(0);
      if (next == '!fail') throw StateError('recognizer down');
      return next;
    },
  );

  /// Replaces [call] with one built differently.
  Future<VoiceCall> rebuild({
    VoiceCallConfig? config,
    TargetPlatform platform = TargetPlatform.iOS,
    bool withTones = false,
    Future<void> Function()? releaseLease,
    CallSpeechFallback? fallback,
    bool Function(String)? echoGuard,
    EchoGuard? echo,
  }) async {
    await call.end();
    call.dispose();
    logged.clear();
    agent.interrupts = 0;
    bridge.log.clear();
    return call = build(
      config: config,
      platform: platform,
      withTones: withTones,
      releaseLease: releaseLease,
      fallback: fallback,
      echoGuard: echoGuard,
      echo: echo,
    );
  }

  void utterance({int quiet = 9}) {
    bridge.emit('pcm', {'data': pcm()});
    for (var i = 0; i < quiet; i++) {
      bridge.emit('pcm', {'data': pcm(amplitude: 0)});
    }
  }

  Future<void> activate() async {
    await call.start();
    bridge.emit('activated');
    await pumpEventQueue();
  }

  Future<void> say(String text) async {
    transcripts.add(text);
    utterance();
    await pumpEventQueue();
  }

  /// Moves the call's clock and runs its once-a-second check. The microphone
  /// keeps sending silence unless [mic] is false.
  void advance(Duration by, {bool mic = true}) {
    clock = clock.add(by);
    if (mic) bridge.emit('pcm', {'data': silence()});
    call.tick();
  }

  Map<String, Object> ended() =>
      logged.singleWhere((e) => e.$1 == 'voice_call.ended').$2;

  Future<void> dispose() async {
    // A widget test may have ended the call in its fake time; a future made
    // there never completes once the test is over, so it is not awaited.
    if (!call.ended) await call.end();
    call.dispose();
    unawaited(bridge.controller.close());
  }
}

/// A [Uint8List] of silence, [milliseconds] long at 16 kHz.
Uint8List silence([int milliseconds = 100]) =>
    pcm(amplitude: 0, milliseconds: milliseconds);
