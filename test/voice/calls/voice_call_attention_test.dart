import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/voice/calls/call_config.dart';
import 'package:hermes_app/src/voice/calls/voice_call.dart';
import 'package:stream_channel/stream_channel.dart';

import 'call_harness.dart';
import 'fakes.dart';

void main() {
  late CallHarness h;

  setUp(() => h = CallHarness());
  tearDown(() => h.dispose());

  /// A reply is running and Hermes has started to speak it.
  Future<void> speaking() async {
    await h.activate();
    await h.say('First');
    h.agent.text!('A long answer. ');
    h.socket.foreign.sink
      ..add(jsonEncode({'type': 'start', 'sample_rate': 24000, 'channels': 1}))
      ..add([0, 1, 2, 3]);
    await pumpEventQueue();
    expect(h.call.phase, CallPhase.speaking);
  }

  group('Waiting for you', () {
    test('onset while waiting interrupts nothing and sends nothing', () async {
      await speaking();
      h.agent.setThreadAttention(true);
      expect(h.call.phase, CallPhase.attention);
      final prompts = h.agent.prompts.length;
      await h.say('Yes, go ahead');
      expect(h.agent.interrupts, 0);
      expect(h.agent.prompts, hasLength(prompts));
      expect(h.uploads, 1, reason: 'nothing was even transcribed');
      expect(h.call.phase, CallPhase.attention);
    });

    test('capture pauses while waiting and resumes when it closes', () async {
      await h.activate();
      h.bridge.pauses = h.bridge.resumes = 0;
      h.agent.setThreadAttention(true);
      expect(h.bridge.pauses, 1);
      expect(h.call.capturePaused, isTrue);
      h.agent.setThreadAttention(false);
      expect(h.bridge.resumes, 1);
      expect(h.call.capturePaused, isFalse);
      expect(h.call.phase, CallPhase.listening);
    });

    test(
      'a pause sent before activation is sent again once activated',
      () async {
        h.bridge.startGate = Completer<void>();
        final starting = h.call.start();
        await pumpEventQueue();
        h.agent.setThreadAttention(true);
        expect(h.bridge.pauses, 1, reason: 'the native start may clear it');
        h.bridge.startGate!.complete();
        await starting;
        h.bridge.emit('activated');
        await pumpEventQueue();
        expect(h.bridge.pauses, 2);
        expect(h.call.capturePaused, isTrue);
      },
    );

    test('pausing resets the speech detector', () async {
      await h.activate();
      // Half an utterance is heard, then the approval arrives.
      h.bridge.emit('pcm', {'data': pcm()});
      h.agent.setThreadAttention(true);
      h.agent.setThreadAttention(false);
      // The rest of the old utterance must not complete it.
      for (var i = 0; i < 9; i++) {
        h.bridge.emit('pcm', {'data': pcm(amplitude: 0)});
      }
      await pumpEventQueue();
      expect(h.uploads, 0);
    });

    test('a typed or queued reply that waits counts too', () async {
      await h.activate();
      // No reply of this call is running; the thread still waits.
      h.agent.setThreadAttention(true);
      expect(h.call.waitingForYou, isTrue);
      expect(h.call.phase, CallPhase.attention);
    });

    test(
      'is tracked per call: a reply left running after barge-in counts',
      () async {
        await speaking();
        // The user speaks over the reply, so its epoch is stale.
        h.transcripts.add('');
        h.utterance();
        await pumpEventQueue();
        expect(h.call.phase, CallPhase.listening);
        h.agent.setThreadAttention(true);
        expect(h.call.phase, CallPhase.attention);
        expect(h.call.capturePaused, isTrue);
        h.agent.setThreadAttention(false);
        expect(h.call.phase, CallPhase.listening);
      },
    );

    test(
      'the reply-level callback counts as well, and clears at its end',
      () async {
        await h.activate();
        await h.say('Hello');
        h.agent.replyAttention!(true);
        expect(h.call.phase, CallPhase.attention);
        h.agent.replyAttention!(false);
        expect(h.call.phase, CallPhase.thinking);
      },
    );

    test('a turn in Sending when the approval arrives is dropped', () async {
      final gate = Completer<StreamChannel<Object?>>();
      h.openSocket = () => gate.future;
      await h.activate();
      await h.say('Hello');
      expect(h.call.phase, CallPhase.sending);
      h.agent.setThreadAttention(true);
      expect(h.call.phase, CallPhase.attention);
      h.agent.setThreadAttention(false);
      gate.complete(h.socket.local);
      await pumpEventQueue();
      expect(h.agent.prompts, isEmpty);
      expect(h.call.phase, CallPhase.listening);
    });

    test(
      'is re-checked before the reply is interrupted and before the send',
      () async {
        await speaking();
        // A second utterance whose transcription is slow.
        h.transcripts.add('Second');
        h.utterance();
        // The approval arrives while it is transcribed.
        h.agent.setThreadAttention(true);
        await pumpEventQueue();
        expect(h.agent.interrupts, 0);
        expect(h.agent.prompts, ['First']);
      },
    );

    test(
      'an approval that arrives while the reply is stopped stops the send',
      () async {
        await speaking();
        final gate = h.agent.interruptGate = Completer<void>();
        await h.say('Second');
        expect(h.agent.interrupts, 1);
        h.agent.setThreadAttention(true);
        gate.complete();
        await pumpEventQueue();
        expect(h.agent.prompts, [
          'First',
        ], reason: 'checked again before submit');
      },
    );

    test(
      'an approval that arrives while playback stops interrupts nothing',
      () async {
        await speaking();
        final gate = h.bridge.stopPlaybackGate = Completer<void>();
        await h.say('Second');
        expect(h.agent.interrupts, 0, reason: 'still stopping playback');
        h.agent.setThreadAttention(true);
        gate.complete();
        await pumpEventQueue();
        expect(h.agent.interrupts, 0, reason: 'checked again before it');
        expect(h.agent.prompts, ['First']);
      },
    );

    test(
      'the stall watchdog sleeps while paused and still catches a stall',
      () async {
        await h.activate();
        h.agent.setThreadAttention(true);
        h.advance(const Duration(seconds: 60), mic: false);
        expect(h.call.ended, isFalse, reason: 'paused by design');
        h.agent.setThreadAttention(false);
        h.advance(const Duration(seconds: 10), mic: false);
        expect(h.call.ended, isFalse);
        h.advance(const Duration(seconds: 16), mic: false);
        await pumpEventQueue();
        expect(h.call.ended, isTrue);
        expect(h.call.endReason, 'microphone_stalled');
      },
    );
  });

  group('barge-in', () {
    test('onset stops playback and the socket only', () async {
      await speaking();
      h.bridge.stops = 0;
      h.bridge.emit('pcm', {'data': pcm()});
      await pumpEventQueue();
      expect(h.bridge.stops, 1);
      expect(h.agent.interrupts, 0);
      expect(h.call.phase, CallPhase.listening);
    });

    test('a real turn stops the reply before it is sent', () async {
      await speaking();
      await h.say('Second');
      expect(h.agent.interrupts, 1);
      expect(h.agent.prompts, ['First', 'Second']);
      // The reply was stopped before the new prompt.
      expect(h.bridge.log.indexOf('interrupt'), greaterThanOrEqualTo(0));
    });

    test(
      'an empty, hallucinated or echoed transcript leaves the reply',
      () async {
        await h.rebuild(echoGuard: (text) => text == 'echo of the reply');
        await speaking();
        for (final text in ['', 'Thank you.', 'echo of the reply']) {
          await h.say(text);
        }
        expect(h.agent.interrupts, 0);
        expect(h.agent.prompts, ['First']);
        expect(h.call.ended, isFalse);
      },
    );

    test('the orb tap interrupts the reply and listens', () async {
      await speaking();
      final gate = h.agent.interruptGate = Completer<void>();
      var done = false;
      unawaited(h.call.interruptReply().then((_) => done = true));
      await pumpEventQueue();
      expect(h.agent.interrupts, 1);
      expect(h.call.phase, CallPhase.listening);
      expect(done, isFalse, reason: 'awaited until the reply settled');
      gate.complete();
      await pumpEventQueue();
      expect(done, isTrue);
    });

    test(
      'after an orb tap the next turn waits for the reply to settle',
      () async {
        await speaking();
        final gate = h.agent.interruptGate = Completer<void>();
        unawaited(h.call.interruptReply());
        await pumpEventQueue();
        await h.say('Next');
        expect(h.agent.prompts, [
          'First',
        ], reason: 'not before the reply stops');
        gate.complete();
        await pumpEventQueue();
        expect(h.agent.prompts, ['First', 'Next']);
      },
    );

    test('the orb does nothing unless Hermes is speaking', () async {
      await h.activate();
      await h.call.interruptReply();
      expect(h.agent.interrupts, 0);
    });

    test(
      'a profile with barge_in false is not interrupted by speech',
      () async {
        await h.rebuild(config: const VoiceCallConfig(bargeIn: false));
        await speaking();
        h.bridge.stops = 0;
        await h.say('Second');
        expect(h.bridge.stops, 0);
        expect(h.agent.prompts, ['First']);
        expect(h.call.phase, CallPhase.speaking);
        expect(h.call.bargeInActive, isFalse);
      },
    );

    test('a bridge without echo cancellation has no barge-in', () async {
      h.bridge.bargeIn = false;
      await speaking();
      await h.say('Second');
      expect(h.agent.prompts, ['First']);
      expect(h.call.bargeInActive, isFalse);
    });

    test(
      'with no barge-in the stall watchdog sleeps outside Listening',
      () async {
        h.bridge.bargeIn = false;
        await speaking();
        h.advance(const Duration(seconds: 60), mic: false);
        expect(h.call.ended, isFalse);
      },
    );
  });
}
