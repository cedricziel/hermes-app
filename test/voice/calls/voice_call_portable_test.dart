import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/voice/calls/echo_guard.dart';
import 'package:hermes_app/src/voice/calls/voice_call.dart';

import 'call_harness.dart';
import 'fakes.dart' show pcm;

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
    test('every call has one, without being given any', () async {
      await h.activate();
      await speaks('Say goodbye', 'Goodbye.');
      await h.say('goodbye');
      expect(h.call.ended, isFalse);
      expect(h.agent.prompts, ['Say goodbye']);
    });

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

    test('an answer that repeats the question is sent, not dropped', () async {
      await h.rebuild(echo: EchoGuard());
      await h.activate();
      await speaks('Mail Anna', 'Shall I send the email to Anna?');
      await h.say('Yes, send the email to Anna');
      expect(h.agent.prompts, ['Mail Anna', 'Yes, send the email to Anna']);
    });

    test('"yes, goodbye" after a reply ending in Goodbye. is sent', () async {
      await h.rebuild(echo: EchoGuard());
      await h.activate();
      await speaks('Say bye', 'The reminder is set. Goodbye.');
      await h.say('Yes, goodbye');
      expect(h.agent.prompts, ['Say bye', 'Yes, goodbye']);
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

  group('echo guard timing', () {
    /// Hermes finishes speaking [reply] after the user said [first].
    Future<void> spokenThrough(String first, String reply) async {
      await speaks(first, reply);
      h.agent.pending!.complete();
      h.socket.foreign.sink.add(jsonEncode({'type': 'end'}));
      await pumpEventQueue();
      expect(h.call.phase, CallPhase.listening);
    }

    /// The user speaks [text]: it starts [after] the playback ended and the
    /// pause that closes it comes [lasting] later.
    Future<void> saysAfter(
      String text,
      Duration after, {
      Duration lasting = Duration.zero,
    }) async {
      h.clock = h.clock.add(after);
      h.transcripts.add(text);
      h.bridge.emit('pcm', {'data': pcm()});
      h.clock = h.clock.add(lasting);
      for (var i = 0; i < 9; i++) {
        h.bridge.emit('pcm', {'data': pcm(amplitude: 0)});
      }
      await pumpEventQueue();
    }

    setUp(() async => h.rebuild(echo: EchoGuard()));

    test('"Goodbye." heard right after the reply is dropped', () async {
      await h.activate();
      await spokenThrough('Say bye', 'Goodbye.');
      await saysAfter('Goodbye.', const Duration(milliseconds: 600));
      expect(h.call.ended, isFalse);
      expect(h.agent.prompts, ['Say bye']);
    });

    test('"goodbye" said 3 s later ends the call', () async {
      await h.activate();
      await spokenThrough('Say bye', 'Goodbye.');
      await saysAfter('goodbye', const Duration(seconds: 3));
      expect(h.call.endReason, 'stop_phrase');
    });

    test('an echo while the reply is still playing is dropped', () async {
      await h.activate();
      await speaks('Say bye', 'Goodbye.');
      await saysAfter('Goodbye.', const Duration(seconds: 20));
      expect(h.call.ended, isFalse);
      expect(h.agent.prompts, ['Say bye']);
    });

    test('the window is 1.5 s after the audio drained', () async {
      await h.activate();
      await spokenThrough('Say bye', 'Goodbye.');
      await saysAfter('Goodbye.', const Duration(milliseconds: 1400));
      expect(h.call.ended, isFalse);
      await h.rebuild(echo: EchoGuard());
      await h.activate();
      await spokenThrough('Say bye', 'Goodbye.');
      await saysAfter('Goodbye.', const Duration(milliseconds: 1600));
      expect(h.call.endReason, 'stop_phrase');
    });

    test('what counts is when the speech began, not when it ended', () async {
      await h.activate();
      await spokenThrough('Say bye', 'Goodbye.');
      await saysAfter(
        'Goodbye.',
        const Duration(milliseconds: 500),
        lasting: const Duration(seconds: 4),
      );
      expect(h.call.ended, isFalse, reason: 'began inside the window');
      await h.rebuild(echo: EchoGuard());
      await h.activate();
      await spokenThrough('Say bye', 'Goodbye.');
      await saysAfter(
        'goodbye',
        const Duration(milliseconds: 1700),
        lasting: Duration.zero,
      );
      expect(h.call.endReason, 'stop_phrase', reason: 'began outside it');
    });

    const answers = [
      ('Should I turn the lights on or off?', 'turn the lights on'),
      (
        'Should I book the table for Peter or Petra?',
        'book the table for Petra',
      ),
      ('Shall I send the email to Anna?', 'send the email to Anna'),
      ('Should I move the meeting to Tuesday?', 'move the meeting to Thursday'),
      ('Is the meeting on Sunday?', 'the meeting is on Monday'),
    ];
    for (final (reply, answer) in answers) {
      test(
        '"$answer" after "$reply" is sent when said after the window',
        () async {
          await h.activate();
          await spokenThrough('Ask me', reply);
          await saysAfter(answer, const Duration(seconds: 3));
          expect(h.agent.prompts, ['Ask me', answer]);
        },
      );

      test('"$answer" said 0.5 s after "$reply" is dropped', () async {
        await h.activate();
        await spokenThrough('Ask me', reply);
        await saysAfter(answer, const Duration(milliseconds: 500));
        expect(h.agent.prompts, ['Ask me']);
      });
    }

    test('an empty transcript does not use up the guard', () async {
      await h.activate();
      await spokenThrough('Say bye', 'Goodbye.');
      await saysAfter('', const Duration(milliseconds: 200));
      await saysAfter('Goodbye.', const Duration(milliseconds: 300));
      expect(h.call.ended, isFalse);
      expect(h.agent.prompts, ['Say bye']);
    });

    test('a reply cut off by speech that makes no transcript closes the '
        'window', () async {
      await h.activate();
      await speaks('Say bye', 'Goodbye.');
      // The user starts talking over it, then mutes before the pause.
      h.bridge.emit('pcm', {'data': pcm()});
      await pumpEventQueue();
      await h.call.setMuted(true);
      h.clock = h.clock.add(const Duration(seconds: 3));
      await h.call.setMuted(false);
      await saysAfter('goodbye', const Duration(milliseconds: 100));
      expect(h.call.endReason, 'stop_phrase');
    });

    test('an answer that is not the reply is sent inside the window', () async {
      await h.activate();
      await spokenThrough('Ask me', 'Shall I send the email to Anna?');
      await saysAfter('Yes, send the email', const Duration(milliseconds: 500));
      expect(h.agent.prompts, ['Ask me', 'Yes, send the email']);
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

  group('connecting', () {
    test('a bridge that never activates ends the call with an error', () {
      fakeAsync((async) {
        final h = CallHarness();
        h.call.start();
        async.flushMicrotasks();
        async.elapse(callConnectTimeout - const Duration(seconds: 1));
        expect(h.call.ended, isFalse);
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();
        expect(h.call.phase, CallPhase.failed);
        expect(h.ended()['step'], 'activation_timeout');
      });
    });

    test('an activated call is not ended by it', () {
      fakeAsync((async) {
        final h = CallHarness();
        h.call.start();
        async.flushMicrotasks();
        h.bridge.emit('activated');
        async.elapse(const Duration(seconds: 30));
        expect(h.call.ended, isFalse);
      });
    });
  });
}
