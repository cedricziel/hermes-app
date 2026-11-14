import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/voice/calls/voice_call.dart';

import 'call_harness.dart';

void main() {
  late CallHarness h;

  setUp(() => h = CallHarness());
  tearDown(() => h.dispose());

  group('idle', () {
    test('five minutes without speech or a reply end the call', () async {
      await h.activate();
      h.advance(const Duration(minutes: 4, seconds: 59));
      await pumpEventQueue();
      expect(h.call.ended, isFalse);
      h.advance(const Duration(seconds: 2));
      await pumpEventQueue();
      expect(h.call.ended, isTrue);
      expect(h.call.endReason, 'idle');
      expect(h.call.notice, CallNotice.idle);
      expect(h.ended(), containsPair('outcome', 'ended'));
    });

    test('speech starts the five minutes again', () async {
      await h.activate();
      h.advance(const Duration(minutes: 4));
      await h.say('Hello');
      h.advance(const Duration(minutes: 4));
      await pumpEventQueue();
      expect(h.call.ended, isFalse);
    });

    test('a running reply is not idle, and its end starts the count', () async {
      await h.activate();
      await h.say('Hello');
      expect(h.call.phase, CallPhase.thinking);
      h.advance(const Duration(minutes: 20));
      await pumpEventQueue();
      expect(h.call.ended, isFalse);
      h.agent.pending!.complete();
      h.advance(const Duration(seconds: 1));
      await pumpEventQueue();
      h.advance(const Duration(minutes: 4));
      expect(h.call.ended, isFalse);
    });

    test('Waiting for you is not idle', () async {
      await h.activate();
      h.agent.setThreadAttention(true);
      h.advance(const Duration(minutes: 20));
      await pumpEventQueue();
      expect(h.call.ended, isFalse);
    });
  });

  group('background', () {
    for (final platform in [
      TargetPlatform.android,
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
    ]) {
      for (final state in [
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        test('${state.name} ends a call on ${platform.name}', () async {
          await h.rebuild(platform: platform);
          await h.activate();
          h.call.lifecycleChanged(state);
          await pumpEventQueue();
          expect(h.call.endReason, 'background');
          expect(h.call.notice, CallNotice.left);
        });
      }
    }

    test('inactive and resumed do not end a call', () async {
      await h.rebuild(platform: TargetPlatform.android);
      await h.activate();
      h.call.lifecycleChanged(AppLifecycleState.inactive);
      h.call.lifecycleChanged(AppLifecycleState.resumed);
      await pumpEventQueue();
      expect(h.call.ended, isFalse);
    });

    test('iOS keeps the call in the background', () async {
      await h.activate();
      h.call.lifecycleChanged(AppLifecycleState.hidden);
      h.call.lifecycleChanged(AppLifecycleState.paused);
      await pumpEventQueue();
      expect(h.call.ended, isFalse);
    });
  });

  group('telemetry', () {
    test('the new reasons log fixed words and no text', () async {
      const secret = 'my secret account number';
      await h.activate();
      await h.say(secret);
      h.agent.text!('The reply mentions $secret. ');
      h.advance(const Duration(minutes: 1));
      await h.call.end();
      final seen = [
        for (final (name, attributes) in h.logged) ...[
          name,
          for (final MapEntry(:key, :value) in attributes.entries) ...[
            key,
            '$value',
          ],
        ],
      ].join(' ');
      expect(seen, isNot(contains('secret')));
      expect(seen, isNot(contains('account')));
    });

    for (final (reason, cause)
        in <(String, Future<void> Function(CallHarness))>[
          (
            'background',
            (h) async {
              h.call.lifecycleChanged(AppLifecycleState.hidden);
            },
          ),
          ('idle', (h) async => h.advance(const Duration(minutes: 6))),
          (
            'focus_lost',
            (h) async {
              h.bridge.emit('deactivated', {'reason': 'focus'});
            },
          ),
        ]) {
      test('$reason is logged with fixed words only', () async {
        await h.rebuild(platform: TargetPlatform.android);
        await h.activate();
        await cause(h);
        await pumpEventQueue();
        final ended = h.ended();
        expect(ended['reason'], reason);
        expect(ended.keys, containsAll(['outcome', 'reason', 'duration']));
        for (final value in ended.values) {
          expect(
            value,
            anyOf(
              isA<bool>(),
              isA<String>().having((v) => v.length, 'length', lessThan(24)),
            ),
          );
        }
      });
    }
  });
}
