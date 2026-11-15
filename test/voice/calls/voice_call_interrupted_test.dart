import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_controller.dart' show VoiceTurnRefusal;
import 'package:hermes_app/src/voice/calls/call_agent.dart';
import 'package:hermes_app/src/voice/calls/voice_call.dart';

import 'call_harness.dart';

void main() {
  late CallHarness h;

  setUp(() => h = CallHarness());
  tearDown(() => h.dispose());

  /// A reply is running and Hermes is speaking it.
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

  Future<void> orbTap() async {
    await h.call.interruptReply();
    await pumpEventQueue();
  }

  /// The user spoke over the reply: the utterance is heard while it speaks.
  Future<void> speakOver(String text) => h.say(text);

  test('a first turn is not interrupted', () async {
    await h.activate();
    await h.say('First');
    expect(h.agent.interruptedAsked, [false]);
  });

  test('the first turn after an orb tap is interrupted', () async {
    await speaking();
    await orbTap();
    await h.say('Next');
    expect(h.agent.interruptedAsked, [false, true]);
  });

  test('the first turn after speaking over the reply is interrupted', () async {
    await speaking();
    await speakOver('Next');
    expect(h.agent.interruptedAsked, [false, true]);
  });

  test(
    'it is cleared by the first submit that reaches the transport',
    () async {
      await speaking();
      await orbTap();
      await h.say('Next');
      h.agent.pending!.complete();
      await pumpEventQueue();
      await h.say('After');
      expect(h.agent.interruptedAsked, [false, true, false]);
    },
  );

  test('a refused turn keeps it for the next one', () async {
    await speaking();
    await orbTap();
    h.agent.replyError = const CallTurnRefused(VoiceTurnRefusal.busy);
    await h.say('Refused');
    h.agent.replyError = null;
    await h.say('Again');
    expect(h.agent.interruptedAsked, [false, true, true]);
    expect(h.agent.written, ['First', 'Again']);
  });

  test('a turn withdrawn before the write keeps it', () async {
    await speaking();
    await orbTap();
    h.agent.holdSubmit = true;
    await h.say('Dropped');
    // An approval arrives before the prompt is written: the turn is withdrawn.
    h.agent.setThreadAttention(true);
    h.agent.submitted();
    await pumpEventQueue();
    expect(h.agent.written, ['First']);
    h.agent.setThreadAttention(false);
    h.agent.holdSubmit = false;
    await h.say('Later');
    expect(h.agent.interruptedAsked, [false, true, true]);
    expect(h.agent.written, ['First', 'Later']);
  });

  test('an echoed turn keeps it for the next one', () async {
    await h.rebuild(echoGuard: (text) => text == 'echo');
    await speaking();
    await orbTap();
    await h.say('echo');
    expect(h.agent.prompts, ['First']);
    await h.say('Real');
    expect(h.agent.interruptedAsked, [false, true]);
  });

  test('a mute clears it', () async {
    await speaking();
    await orbTap();
    await h.call.setMuted(true);
    await h.call.setMuted(false);
    await h.say('Next');
    expect(h.agent.interruptedAsked, [false, false]);
  });

  test('a mute the bridge has not confirmed yet clears it', () async {
    await speaking();
    await orbTap();
    h.bridge.muteGate = Completer<void>();
    unawaited(h.call.setMuted(true));
    unawaited(h.call.setMuted(false));
    await pumpEventQueue();
    await h.say('Next');
    expect(h.agent.interruptedAsked, [false, false]);
    h.bridge.muteGate!.complete();
    await pumpEventQueue();
  });

  test('a system mute clears it', () async {
    await speaking();
    await orbTap();
    h.bridge.emit('muted', {'muted': true});
    h.bridge.emit('muted', {'muted': false});
    await pumpEventQueue();
    await h.say('Next');
    expect(h.agent.interruptedAsked, [false, false]);
  });

  test('a route change clears it', () async {
    await speaking();
    await orbTap();
    h.bridge.emit('audioReset');
    await pumpEventQueue();
    await h.say('Next');
    expect(h.agent.interruptedAsked, [false, false]);
  });

  test('a typed message clears it', () async {
    await speaking();
    await orbTap();
    h.agent.typed();
    await h.say('Next');
    expect(h.agent.interruptedAsked, [false, false]);
  });

  group('after 120 seconds', () {
    test('a cut-off that is 119 seconds old still counts', () async {
      await speaking();
      await orbTap();
      h.clock = h.clock.add(const Duration(seconds: 119));
      await h.say('Next');
      expect(h.agent.interruptedAsked, [false, true]);
    });

    test('a cut-off that is 120 seconds old is forgotten', () async {
      await speaking();
      await orbTap();
      h.clock = h.clock.add(const Duration(seconds: 120));
      await h.say('Next');
      expect(h.agent.interruptedAsked, [false, false]);
    });
  });
}
