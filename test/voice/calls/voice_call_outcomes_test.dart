import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_controller.dart' show VoiceTurnRefusal;
import 'package:hermes_app/src/voice/calls/call_agent.dart';
import 'package:hermes_app/src/voice/calls/voice_call.dart';

import 'call_harness.dart';

void main() {
  late CallHarness h;

  setUp(() => h = CallHarness());
  tearDown(() => h.dispose());

  group('Sending lasts until the prompt is about to be written', () {
    test('the words are with the agent but not yet written', () async {
      await h.activate();
      h.agent.holdSubmit = true;
      await h.say('What is next?');
      expect(h.agent.prompts, ['What is next?']);
      expect(h.call.phase, CallPhase.sending);
      h.agent.submitted();
      await pumpEventQueue();
      expect(h.agent.written, ['What is next?']);
      expect(h.call.phase, CallPhase.thinking);
    });

    test('End before the write sends nothing', () async {
      await h.activate();
      h.agent.holdSubmit = true;
      await h.say('Do not send');
      await h.call.end();
      h.agent.submitted();
      await pumpEventQueue();
      expect(h.agent.written, isEmpty);
    });

    test('a mute before the write sends nothing and listens', () async {
      await h.activate();
      h.agent.holdSubmit = true;
      await h.say('Do not send');
      expect(h.call.phase, CallPhase.sending);
      await h.call.setMuted(true);
      expect(h.call.phase, CallPhase.listening);
      h.agent.submitted();
      await pumpEventQueue();
      expect(h.agent.written, isEmpty);
      expect(h.call.ended, isFalse);
      expect(h.call.notice, isNull, reason: 'the user asked for it');
    });

    test('an approval raised before the write sends nothing', () async {
      await h.activate();
      h.agent.holdSubmit = true;
      await h.say('Yes');
      h.agent.setThreadAttention(true);
      h.agent.submitted();
      await pumpEventQueue();
      expect(h.agent.written, isEmpty);
      expect(h.call.phase, CallPhase.attention);
    });

    test('the agent is asked whether the turn is still wanted', () async {
      await h.activate();
      h.agent.holdSubmit = true;
      await h.say('Hello');
      expect(h.agent.wanted!(), isTrue);
      await h.call.setMuted(true);
      expect(h.agent.wanted!(), isFalse);
    });
  });

  group('a refused turn', () {
    Future<void> refused(VoiceTurnRefusal reason) async {
      h.agent.replyError = CallTurnRefused(reason);
      await h.activate();
      await h.say('Hello');
    }

    test('busy says so, sends nothing and keeps listening', () async {
      await refused(VoiceTurnRefusal.busy);
      expect(h.call.ended, isFalse);
      expect(h.call.notice, CallNotice.busy);
      expect(h.call.phase, CallPhase.listening);
    });

    for (final reason in [
      VoiceTurnRefusal.queueRestoreFailed,
      VoiceTurnRefusal.modelOrBranchNotAllowed,
    ]) {
      test('$reason says nothing was sent and keeps listening', () async {
        await refused(reason);
        expect(h.call.ended, isFalse);
        expect(h.call.notice, CallNotice.notSent);
        expect(h.call.phase, CallPhase.listening);
      });
    }

    test(
      'a turn that is no longer wanted is dropped without a notice',
      () async {
        await refused(VoiceTurnRefusal.noLongerWanted);
        expect(h.call.ended, isFalse);
        expect(h.call.notice, isNull);
        expect(h.call.phase, CallPhase.listening);
      },
    );

    for (final (reason, kind) in [
      (VoiceTurnRefusal.sessionReclaimed, 'session_reclaimed'),
      (VoiceTurnRefusal.profileNotConfirmed, 'profile_not_confirmed'),
    ]) {
      test('$reason ends the call', () async {
        await refused(reason);
        expect(h.call.ended, isTrue);
        expect(h.ended()['reason'], 'turn');
        expect(h.ended()['error_type'], kind);
      });
    }

    test('a refusal closes the speech socket it had opened', () async {
      await refused(VoiceTurnRefusal.busy);
      expect(h.call.phase, CallPhase.listening);
      // The next turn gets a socket of its own and is heard as usual.
      h.agent.replyError = null;
      await h.say('Again');
      expect(h.agent.written, ['Again']);
    });
  });

  group('what Hermes answers', () {
    for (final (answer, notice) in [
      (CallTurnAnswer.queued, CallNotice.hermesQueued),
      (CallTurnAnswer.steered, CallNotice.hermesSteered),
      (CallTurnAnswer.redirected, CallNotice.hermesRedirected),
    ]) {
      test('$answer ends the wait at once and the call listens', () async {
        await h.activate();
        await h.say('Hello');
        h.agent.answer(answer);
        await pumpEventQueue();
        expect(h.call.ended, isFalse);
        expect(h.call.notice, notice);
        expect(h.call.phase, CallPhase.listening);
        expect(h.agent.interrupts, 0, reason: 'its reply is left running');
      });
    }

    test('voice_stopped ends the call with its own reason', () async {
      await h.activate();
      await h.say('Please stop the music');
      h.agent.answer(CallTurnAnswer.voiceStopped);
      await pumpEventQueue();
      expect(h.call.ended, isTrue);
      expect(h.ended()['reason'], 'voice_stopped');
      expect(h.ended()['outcome'], 'ended');
      expect(h.bridge.captureStops, greaterThan(0));
    });
  });
}
