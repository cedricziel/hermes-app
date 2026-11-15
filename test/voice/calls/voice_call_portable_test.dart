import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/voice/calls/echo_guard.dart';
import 'package:hermes_app/src/voice/calls/voice_call.dart';

import 'call_harness.dart';

void main() {
  late CallHarness h;

  setUp(() => h = CallHarness());
  tearDown(() => h.dispose());

  /// Hermes speaks [reply] after the user said [first].
  Future<void> speaks(String first, String reply) async {
    await h.say(first);
    h.agent.text!(reply);
    h.socket.foreign.sink
      ..add(jsonEncode({'type': 'start', 'sample_rate': 24000, 'channels': 1}))
      ..add([0, 1, 2, 3]);
    await pumpEventQueue();
    expect(h.call.phase, CallPhase.speaking);
  }

  group('echo guard', () {
    test('an echoed "Goodbye." does not end the call', () async {
      await h.rebuild(echo: EchoGuard());
      await h.activate();
      await speaks('Say goodbye', 'Goodbye.');
      await h.say('Goodbye.');
      expect(h.call.ended, isFalse);
      expect(h.agent.prompts, ['Say goodbye']);
      expect(h.call.phase, CallPhase.listening);
    });

    test('"Goodbye." that is not the reply still ends it', () async {
      await h.rebuild(echo: EchoGuard());
      await h.activate();
      await speaks('Say hello', 'Hello there, how can I help?');
      await h.say('Goodbye.');
      expect(h.call.ended, isTrue);
      expect(h.call.endReason, 'stop_phrase');
    });

    test('the echo of a long reply is dropped, then speech is sent', () async {
      await h.rebuild(echo: EchoGuard());
      await h.activate();
      await speaks(
        'Weather',
        'The weather in Berlin is cloudy today with a chance of rain.',
      );
      await h.say('weather in Berlin is cloudy today');
      expect(h.agent.prompts, ['Weather']);
      await h.say('Remind me at five');
      expect(h.agent.prompts, ['Weather', 'Remind me at five']);
    });

    test('the guard is spent by the first transcript', () async {
      await h.rebuild(echo: EchoGuard());
      await h.activate();
      await speaks('Weather', 'Goodbye.');
      await h.say('Something else entirely');
      expect(h.agent.prompts, ['Weather', 'Something else entirely']);
      // Said again later, it is a real stop phrase.
      await h.say('Goodbye.');
      expect(h.call.ended, isTrue);
    });
  });

  group('without barge-in', () {
    setUp(() => h.bridge.bargeIn = false);

    test(
      'the microphone is closed after a turn is spoken, until listening',
      () async {
        await h.activate();
        expect(h.bridge.pauses, 0, reason: 'open while listening');
        await h.say('First');
        expect(h.call.phase, CallPhase.thinking);
        expect(h.bridge.pauses, 1);
        expect(h.bridge.resumes, 0);
        h.agent.text!('A meeting.');
        h.agent.pending!.complete();
        h.socket.foreign.sink
          ..add(
            jsonEncode({'type': 'start', 'sample_rate': 24000, 'channels': 1}),
          )
          ..add([0, 1, 2, 3]);
        await pumpEventQueue();
        expect(h.call.phase, CallPhase.speaking);
        expect(h.bridge.pauses, 1, reason: 'still closed while speaking');
        h.socket.foreign.sink.add(jsonEncode({'type': 'end'}));
        await pumpEventQueue();
        expect(h.call.phase, CallPhase.listening);
        expect(h.bridge.resumes, 1);
      },
    );

    test('the closed microphone is not a stalled one', () async {
      await h.activate();
      await h.say('First');
      expect(h.call.phase, CallPhase.thinking);
      h.advance(const Duration(seconds: 20), mic: false);
      expect(h.call.ended, isFalse);
    });
  });

  group('with barge-in', () {
    test('the microphone stays open through a turn', () async {
      await h.activate();
      await h.say('First');
      expect(h.bridge.pauses, 0);
    });
  });

  group('route', () {
    test('only iOS starts with a named route', () async {
      expect(h.call.route, 'iPhone');
      await h.rebuild(platform: TargetPlatform.macOS);
      expect(h.call.route, isEmpty);
      await h.activate();
      h.bridge.emit('route', {'name': 'Speaker', 'speaker': true});
      await pumpEventQueue();
      expect(h.call.route, 'Speaker');
      expect(h.call.speaker, isTrue);
    });
  });
}
