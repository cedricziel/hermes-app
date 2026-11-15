import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_controller.dart' show VoiceTurnRefusal;
import 'package:hermes_app/src/voice/calls/call_agent.dart';
import 'package:hermes_app/src/voice/calls/call_tones.dart';
import 'package:hermes_app/src/voice/calls/voice_call.dart';

import 'call_harness.dart';

void main() {
  late CallHarness h;
  late int held, released;

  setUp(() {
    h = CallHarness();
    held = released = 0;
  });
  tearDown(() => h.dispose());

  Future<void> withLease() async => h.rebuild(
    holdLease: () async => held++,
    releaseLease: () async => released++,
  );

  /// Hermes' reply arrives and the speech socket plays and ends.
  Future<void> spoken(String reply) async {
    h.agent.text!(reply);
    h.agent.pending!.complete();
    h.socket.foreign.sink
      ..add(jsonEncode({'type': 'start', 'sample_rate': 24000, 'channels': 1}))
      ..add([0, 1, 2, 3])
      ..add(jsonEncode({'type': 'end'}));
    await pumpEventQueue();
  }

  group('the last turn', () {
    test(
      'is what was sent and what Hermes said, and the caption goes',
      () async {
        await h.activate();
        await h.say('What is on today?');
        expect(h.call.caption, 'What is on today?');
        expect(h.call.lastYou, 'What is on today?');
        expect(h.call.lastHermes, isEmpty);
        h.agent.text!('Two ');
        h.agent.text!('meetings.');
        expect(h.call.lastHermes, 'Two meetings.');
        await spoken('');
        expect(h.call.phase, CallPhase.listening);
        expect(h.call.caption, isEmpty, reason: 'the list takes over');
        expect(h.call.lastYou, 'What is on today?');
        expect(h.call.lastHermes, 'Two meetings.');
        expect(h.call.replyInChat, isFalse);
      },
    );

    test('a barge-in keeps what was sent and what was said so far', () async {
      await h.activate();
      await h.say('First');
      h.agent.text!('Long answer ');
      h.utterance();
      await pumpEventQueue();
      expect(h.call.lastYou, 'First');
      expect(h.call.lastHermes, 'Long answer ');
    });

    test('a turn that was never sent leaves the old one', () async {
      await h.activate();
      await h.say('First');
      await spoken('Done.');
      h.agent.holdSubmit = true;
      await h.say('Second');
      expect(h.call.lastYou, 'First', reason: 'not written yet');
      await h.call.setMuted(true);
      expect(h.call.lastYou, 'First');
      expect(h.call.lastHermes, 'Done.');
    });

    test('the words are dropped when the call ends', () async {
      await h.activate();
      await h.say('Private request');
      h.agent.text!('Private answer');
      await h.call.end();
      expect(h.call.lastYou, isEmpty);
      expect(h.call.lastHermes, isEmpty);
    });

    test('no word reaches a log event', () async {
      await h.activate();
      await h.say('Private request');
      await spoken('Private answer');
      await h.call.end();
      expect(
        jsonEncode(h.logged.map((e) => [e.$1, e.$2]).toList()),
        isNot(contains('Private')),
      );
    });
  });

  group('Speak replies', () {
    test('is on by default', () {
      expect(h.call.speakReplies, isTrue);
    });

    test(
      'off opens no speech socket and says the reply is in the chat',
      () async {
        await h.activate();
        h.call.setSpeakReplies(false);
        await h.say('What is on today?');
        expect(h.sockets, 0);
        h.agent.text!('Two meetings.');
        h.agent.pending!.complete();
        await pumpEventQueue();
        expect(h.sockets, 0);
        expect(h.bridge.played, isEmpty);
        expect(h.call.phase, CallPhase.listening);
        expect(h.call.caption, isEmpty);
        expect(h.call.replyInChat, isTrue);
        expect(h.call.lastYou, 'What is on today?');
        expect(h.call.lastHermes, isEmpty, reason: 'the chat has the words');
        expect(h.call.ended, isFalse);
      },
    );

    test('off still plays the tick at submit and counts the turn', () async {
      await h.rebuild(withTones: true);
      await h.activate();
      h.call.setSpeakReplies(false);
      await h.say('Hi');
      expect(h.tones.played, contains(CallTone.sent));
      h.agent.pending!.complete();
      await pumpEventQueue();
      final turn = h.logged.singleWhere((e) => e.$1 == 'voice_call.turn').$2;
      expect(turn['outcome'], 'in_chat');
    });

    test('a tool-only reply says nothing aloud when it is off', () async {
      await h.activate();
      h.call.setSpeakReplies(false);
      await h.say('Run it');
      h.agent.pending!.complete();
      await pumpEventQueue();
      expect(h.sockets, 0);
      expect(h.bridge.played, isEmpty);
      expect(h.call.replyInChat, isTrue);
    });

    test('turned off while a reply is spoken, it stops now', () async {
      await h.activate();
      await h.say('First');
      h.agent.text!('A long answer, ');
      h.socket.foreign.sink
        ..add(
          jsonEncode({'type': 'start', 'sample_rate': 24000, 'channels': 1}),
        )
        ..add([0, 1, 2, 3]);
      await pumpEventQueue();
      expect(h.call.phase, CallPhase.speaking);
      final stops = h.bridge.stops;
      h.call.setSpeakReplies(false);
      await pumpEventQueue();
      expect(h.bridge.stops, greaterThan(stops));
      // The rest of the reply goes on in the chat and is not spoken.
      h.agent.text!('and more.');
      h.agent.pending!.complete();
      await pumpEventQueue();
      expect(h.call.phase, CallPhase.listening);
      expect(h.call.ended, isFalse);
      expect(h.call.replyInChat, isTrue);
      expect(h.sockets, 1, reason: 'no new socket');
    });

    test('turned on again, the next reply is spoken', () async {
      await h.activate();
      h.call.setSpeakReplies(false);
      await h.say('One');
      h.agent.pending!.complete();
      await pumpEventQueue();
      h.call.setSpeakReplies(true);
      await h.say('Two');
      expect(h.sockets, 1);
      await spoken('Spoken.');
      expect(h.call.replyInChat, isFalse);
      expect(h.call.lastHermes, 'Spoken.');
    });

    test('a refused turn leaves no "in the chat" line', () async {
      await h.activate();
      h.call.setSpeakReplies(false);
      h.agent.replyError = const CallTurnRefused(VoiceTurnRefusal.busy);
      await h.say('Too soon');
      expect(h.call.replyInChat, isFalse);
    });
  });

  group('the tts-lease', () {
    test('is held once the call starts and released once on End', () async {
      await withLease();
      await h.activate();
      expect(held, 1);
      expect(released, 0);
      await h.call.end();
      await h.call.end();
      expect(released, 1);
    });

    test('is not held while Speak replies is off, nor released', () async {
      await withLease();
      h.call.setSpeakReplies(false);
      await h.activate();
      expect(held, 0);
      await h.call.end();
      expect(released, 0);
    });

    test('follows the switch during the call', () async {
      await withLease();
      await h.activate();
      h.call.setSpeakReplies(false);
      await pumpEventQueue();
      expect(released, 1);
      h.call.setSpeakReplies(true);
      await pumpEventQueue();
      expect(held, 2);
      await h.call.end();
      expect(released, 2);
    });

    test('a failed hold is ignored and the call goes on', () async {
      await h.rebuild(
        holdLease: () async => throw StateError('no lease on this server'),
        releaseLease: () async => released++,
      );
      await h.activate();
      expect(h.call.phase, CallPhase.listening);
      expect(h.call.ended, isFalse);
      await h.call.end();
      expect(h.call.ended, isTrue);
    });

    test('End before the hold finished releases after it', () async {
      final gate = Completer<void>();
      final order = <String>[];
      await h.rebuild(
        holdLease: () async {
          order.add('hold');
          await gate.future;
          order.add('held');
        },
        releaseLease: () async => order.add('release'),
      );
      await h.activate();
      final ending = h.call.end();
      await pumpEventQueue();
      gate.complete();
      await ending;
      expect(order, ['hold', 'held', 'release']);
    });
  });
}
