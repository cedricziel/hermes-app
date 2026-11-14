import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/voice/calls/call_config.dart';
import 'package:hermes_app/src/voice/calls/call_speech_stream.dart';
import 'package:hermes_app/src/voice/calls/voice_call.dart';
import 'package:stream_channel/stream_channel.dart';

import 'fakes.dart';

void main() {
  late FakeCallBridge bridge;
  late FakeCallAgent agent;
  late VoiceCall call;
  late StreamChannelController<Object?> socket;
  late List<String> transcripts;
  late List<(String, Map<String, Object>)> logged;
  Future<StreamChannel<Object?>> Function()? openSocket;
  var uploads = 0;

  VoiceCall build({
    bool consented = true,
    Future<VoiceCallConfig> Function()? loadConfig,
    bool Function(String)? echoGuard,
    CallSpeechFallback? fallback,
  }) => VoiceCall(
    bridge: bridge,
    agent: agent,
    consented: consented,
    loadConfig: loadConfig,
    echoGuard: echoGuard,
    connect: ([_ = const {}]) =>
        openSocket != null ? openSocket!() : Future.value(socket.local),
    prepare: () async {},
    speechFallback: fallback,
    events: (name, [attributes = const {}]) => logged.add((name, attributes)),
    transcribe: (_) async {
      uploads++;
      if (transcripts.isEmpty) throw StateError('no transcript queued');
      final next = transcripts.removeAt(0);
      if (next == '!fail') throw StateError('recognizer down');
      return next;
    },
  );

  setUp(() {
    bridge = FakeCallBridge();
    agent = FakeCallAgent();
    socket = StreamChannelController<Object?>();
    socket.foreign.stream.listen((_) {});
    transcripts = [];
    logged = [];
    openSocket = null;
    uploads = 0;
    call = build();
    addTearDown(() async {
      await call.end();
      call.dispose();
      await bridge.controller.close();
    });
  });

  void utterance({int quiet = 9}) {
    bridge.emit('pcm', {'data': pcm()});
    for (var i = 0; i < quiet; i++) {
      bridge.emit('pcm', {'data': pcm(amplitude: 0)});
    }
  }

  Future<void> activate() async {
    await call.start();
    bridge.emit('activated');
  }

  Future<void> say(String text) async {
    transcripts.add(text);
    utterance();
    await pumpEventQueue();
  }

  Map<String, Object> ended() =>
      logged.singleWhere((e) => e.$1 == 'voice_call.ended').$2;

  group('consent', () {
    test('a call without consent never opens capture', () async {
      call.dispose();
      logged.clear();
      call = build(consented: false);
      await call.start();
      bridge.emit('activated');
      utterance();
      await pumpEventQueue();
      expect(bridge.starts, 0);
      expect(bridge.connections, 0);
      expect(uploads, 0);
      expect(call.ended, isTrue);
    });
  });

  group('sending', () {
    test(
      'lasts from the end of speech until the words are handed to the agent',
      () async {
        final gate = Completer<StreamChannel<Object?>>();
        openSocket = () => gate.future;
        await activate();
        await say('What is next?');
        expect(agent.prompts, isEmpty);
        expect(call.phase, CallPhase.sending);
        agent.holdSubmit = true;
        gate.complete(socket.local);
        await pumpEventQueue();
        expect(agent.prompts, ['What is next?']);
        expect(
          call.phase,
          CallPhase.thinking,
          reason: 'a cancel can no longer withdraw them, so no Sending',
        );
      },
    );

    test('a mute after the hand-off does not pretend to cancel', () async {
      agent.holdSubmit = true;
      await activate();
      await say('Already on its way');
      expect(call.phase, CallPhase.thinking);
      unawaited(call.setMuted(true));
      await pumpEventQueue();
      expect(call.phase, CallPhase.thinking);
      expect(call.caption, 'Already on its way');
    });

    test('End while the speech socket opens sends nothing', () async {
      final gate = Completer<StreamChannel<Object?>>();
      openSocket = () => gate.future;
      await activate();
      await say('Do not send');
      expect(call.phase, CallPhase.sending);
      await call.end();
      gate.complete(socket.local);
      await pumpEventQueue();
      expect(agent.prompts, isEmpty);
    });

    test(
      'a mute during the socket wait counts before the bridge confirms it',
      () async {
        final gate = Completer<StreamChannel<Object?>>();
        openSocket = () => gate.future;
        await activate();
        bridge.muteGate = Completer<void>();
        await say('Do not send');
        expect(call.phase, CallPhase.sending);
        unawaited(call.setMuted(true));
        expect(call.muted, isFalse, reason: 'the bridge has not confirmed');
        expect(
          call.phase,
          CallPhase.listening,
          reason: 'Sending is left at once, not when the bridge answers',
        );
        gate.complete(socket.local);
        await pumpEventQueue();
        expect(agent.prompts, isEmpty);
        expect(call.phase, CallPhase.listening);
        bridge.muteGate!.complete();
        await pumpEventQueue();
      },
    );

    test('a mute during transcription sends nothing', () async {
      final text = Completer<String>();
      call.dispose();
      call = VoiceCall(
        bridge: bridge,
        agent: agent,
        consented: true,
        connect: ([_ = const {}]) async => socket.local,
        prepare: () async {},
        transcribe: (_) => text.future,
      );
      await activate();
      bridge.muteGate = Completer<void>();
      utterance();
      await pumpEventQueue();
      unawaited(call.setMuted(true));
      text.complete('Do not send');
      await pumpEventQueue();
      expect(agent.prompts, isEmpty);
      bridge.muteGate!.complete();
    });

    test('an unmute right after lets the next turn through', () async {
      await activate();
      await call.setMuted(true);
      await call.setMuted(false);
      await say('Hello again');
      expect(agent.prompts, ['Hello again']);
    });

    test('after the send End stops this turn\'s reply', () async {
      await activate();
      await say('Hello');
      expect(agent.prompts, ['Hello']);
      expect(call.phase, CallPhase.thinking);
      await call.end();
      expect(agent.interrupts, greaterThan(0));
      expect(call.ended, isTrue);
    });
  });

  group('failed transcription', () {
    test('drops the turn with a notice and listens', () async {
      await activate();
      await say('!fail');
      expect(agent.prompts, isEmpty);
      expect(call.notice, CallNotice.transcription);
      expect(call.phase, CallPhase.listening);
      expect(call.ended, isFalse);
    });

    test('the notice goes when the user speaks again', () async {
      await activate();
      await say('!fail');
      bridge.emit('pcm', {'data': pcm()});
      await pumpEventQueue();
      expect(call.notice, isNull);
    });

    test('two failures in a row end the call', () async {
      await activate();
      await say('!fail');
      await say('!fail');
      expect(agent.prompts, isEmpty);
      expect(call.ended, isTrue);
      expect(call.endReason, 'transcription');
      expect(call.notice, CallNotice.transcription);
      expect(ended()['reason'], 'transcription');
    });

    test('a success in between resets the count', () async {
      await activate();
      await say('!fail');
      await say('');
      await say('!fail');
      expect(call.ended, isFalse);
      expect(call.phase, CallPhase.listening);
    });
  });

  group('which transcripts are sent', () {
    test('an empty transcript is dropped silently', () async {
      await activate();
      await say('   ');
      expect(agent.prompts, isEmpty);
      expect(call.phase, CallPhase.listening);
      expect(call.notice, isNull);
    });

    for (final text in [
      'Thank you.',
      'Bye',
      'bye.',
      'You',
      'Thank you. Thank you. Thank you.',
    ]) {
      test(
        '"$text" is a hallucination, dropped silently, never a stop',
        () async {
          await activate();
          await say(text);
          expect(agent.prompts, isEmpty);
          expect(call.phase, CallPhase.listening);
          expect(call.notice, isNull);
          expect(call.ended, isFalse);
        },
      );
    }

    test(
      'an echo is dropped before the hallucination and stop checks',
      () async {
        call.dispose();
        logged.clear();
        call = build(echoGuard: (text) => text == 'Goodbye.');
        await activate();
        await say('Goodbye.');
        expect(agent.prompts, isEmpty);
        expect(call.ended, isFalse);
        expect(call.phase, CallPhase.listening);
      },
    );

    for (final text in [
      'goodbye',
      'Hang up.',
      'End the call',
      'Hey Hermes, goodbye.',
    ]) {
      test('"$text" ends the call and sends nothing', () async {
        await activate();
        await say(text);
        expect(agent.prompts, isEmpty);
        expect(call.ended, isTrue);
        expect(call.endReason, 'stop_phrase');
        expect(call.phase, CallPhase.ended);
        expect(ended()['reason'], 'stop_phrase');
        expect(ended()['outcome'], 'ended');
      });
    }

    test('anything else is sent', () async {
      await activate();
      await say('Remind me at five');
      expect(agent.prompts, ['Remind me at five']);
    });

    test('a profile list replaces the built-in phrases', () async {
      call.dispose();
      logged.clear();
      call = build(
        loadConfig: () async => VoiceCallConfig.fromJson({
          'voice': {
            'stop_phrases': ['enough'],
          },
        }),
      );
      await activate();
      await say('goodbye');
      expect(agent.prompts, ['goodbye']);
      agent.pending!.complete();
      await pumpEventQueue();
      expect(call.ended, isFalse);
    });

    test('an explicit empty list leaves only End', () async {
      call.dispose();
      logged.clear();
      call = build(
        loadConfig: () async => VoiceCallConfig.fromJson({
          'voice': {'stop_phrases': <Object?>[]},
        }),
      );
      await activate();
      await say('stop');
      expect(agent.prompts, ['stop']);
      expect(call.ended, isFalse);
    });
  });

  group('config', () {
    test('the profile pause ends the utterance, not the default one', () async {
      call.dispose();
      var reads = 0;
      call = build(
        loadConfig: () async {
          reads++;
          return VoiceCallConfig.fromJson({
            'voice': {'silence_duration': 2},
          });
        },
      );
      transcripts.add('Hello');
      await activate();
      utterance(quiet: 12);
      await pumpEventQueue();
      expect(uploads, 0);
      for (var i = 0; i < 8; i++) {
        bridge.emit('pcm', {'data': pcm(amplitude: 0)});
      }
      await pumpEventQueue();
      expect(uploads, 1);
      expect(reads, 1, reason: 'once per call');
    });

    test('a failed read keeps the defaults and the call starts', () async {
      call.dispose();
      logged.clear();
      call = build(loadConfig: () async => throw StateError('offline'));
      await activate();
      await say('Hello');
      expect(agent.prompts, ['Hello']);
      expect(call.ended, isFalse);
    });
  });

  group('speech failure', () {
    Future<void> reach() async {
      await activate();
      await say('Tell me');
      agent.text!('A reply.');
      agent.pending!.complete();
    }

    test(
      'without a fallback the call ends and the reply stays in the chat',
      () async {
        await reach();
        socket.foreign.sink.add(jsonEncode({'type': 'error'}));
        await pumpEventQueue();
        expect(call.ended, isTrue);
        expect(call.phase, CallPhase.failed);
        expect(call.notice, CallNotice.speechFailed);
        expect(call.endReason, 'speech');
        expect(
          call.error,
          'Hermes could not speak this reply. Check your speech provider on the server. The reply is in the chat.',
        );
      },
    );

    test('a failed fallback ends the call', () async {
      call.dispose();
      logged.clear();
      call = build(fallback: (_, _, _) async => throw StateError('down'));
      await reach();
      socket.foreign.sink.add(jsonEncode({'type': 'error'}));
      await pumpEventQueue();
      expect(call.notice, CallNotice.speechFailed);
      expect(ended()['reason'], 'speech');
      expect(ended()['step'], 'speech_fallback');
    });

    test('a working fallback speaks and the call listens again', () async {
      call.dispose();
      logged.clear();
      call = build(
        fallback: (_, _, _) async => Uint8List.fromList([1, 2, 3, 4]),
      );
      await reach();
      socket.foreign.sink.add(jsonEncode({'type': 'error'}));
      await pumpEventQueue();
      expect(call.ended, isFalse);
      expect(call.phase, CallPhase.listening);
      expect(bridge.played, hasLength(1));
    });

    test('a failure after audio counts as finished', () async {
      await reach();
      socket.foreign.sink
        ..add(
          jsonEncode({'type': 'start', 'sample_rate': 24000, 'channels': 1}),
        )
        ..add([1, 2, 3, 4])
        ..add(jsonEncode({'type': 'error'}));
      await pumpEventQueue();
      expect(call.ended, isFalse);
      expect(call.phase, CallPhase.listening);
    });
  });

  group('telemetry', () {
    test('no spoken text reaches an event', () async {
      call.dispose();
      logged.clear();
      call = build();
      await activate();
      await say('my secret passphrase is swordfish');
      agent.pending!.complete();
      await pumpEventQueue();
      await call.end();
      for (final (name, attributes) in logged) {
        expect(name, isNot(contains('swordfish')));
        for (final entry in attributes.entries) {
          expect('${entry.key}=${entry.value}', isNot(contains('swordfish')));
          expect('${entry.value}', isNot(contains('passphrase')));
        }
      }
    });

    test('a transcript that is a stop phrase logs only the reason', () async {
      await activate();
      await say('hang up');
      expect(logged.map((e) => e.$1), [
        'voice_call.connected',
        'voice_call.ended',
      ]);
      expect(ended().keys, isNot(contains('text')));
      expect(ended()['reason'], 'stop_phrase');
      expect(logged.any((e) => '${e.$2}'.contains('voice_hang_up')), isFalse);
    });
  });
}
