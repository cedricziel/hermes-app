import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/voice/calls/voice_call.dart';

import 'call_harness.dart';

void main() {
  late CallHarness h;

  setUp(() => h = CallHarness());
  tearDown(() => h.dispose());

  /// Each exit of a call, the reason it logs and how a test causes it.
  final exits = <String, Future<void> Function(CallHarness)>{
    'hang_up': (h) async => h.bridge.emit('ended'),
    'stop_phrase': (h) => h.say('stop'),
    'voice_stopped': (h) => h.call.voiceStopped(),
    'background': (h) async {
      h.call.lifecycleChanged(AppLifecycleState.hidden);
    },
    'idle': (h) async => h.advance(const Duration(minutes: 5, seconds: 1)),
    'transcription': (h) async {
      await h.say('!fail');
      await h.say('!fail');
    },
    'interrupted': (h) async => h.bridge.emit('deactivated'),
    'focus_lost': (h) async =>
        h.bridge.emit('deactivated', {'reason': 'focus'}),
    'microphone_stalled': (h) async =>
        h.advance(const Duration(seconds: 16), mic: false),
    'speech': (h) async {
      h.openSocket = () => Future.error(StateError('no socket'));
      await h.say('Hello');
    },
    'mute': (h) async {
      h.bridge.muteError = StateError('mute failed');
      await h.call.setMuted(true);
    },
    'app': (h) => h.call.end(),
    'app_failure': (h) => h.call.end('The chat changed.'),
    'turn': (h) async {
      h.agent.replyError = StateError('refused');
      await h.say('Hello');
    },
    'native_error': (h) async =>
        h.bridge.emit('error', {'code': 'audio_start'}),
  };

  group('every exit tears the call down in order', () {
    for (final MapEntry(key: reason, value: cause) in exits.entries) {
      test(reason, () async {
        await h.rebuild(platform: TargetPlatform.android, withTones: true);
        await h.activate();
        h.bridge.log.clear();
        await cause(h);
        await pumpEventQueue();
        expect(h.call.ended, isTrue);
        expect(h.ended()['reason'], reason);
        final log = h.bridge.log;
        int at(String step) => log.indexOf(step);
        expect(h.bridge.captureStops, 1, reason: '$log');
        expect(at('stopCapture'), 0, reason: 'capture is closed first: $log');
        expect(at('stopPlayback'), greaterThan(at('stopCapture')));
        expect(at('end'), greaterThan(at('stopPlayback')));
        expect(at('interrupt'), greaterThan(at('end')));
        expect(h.bridge.ends, 1);
        expect(h.agent.interrupts, 1);
        expect(h.logged.where((e) => e.$1 == 'voice_call.ended'), hasLength(1));
      });
    }
  });

  group('teardown', () {
    test('a step that throws or hangs skips nothing and runs once', () async {
      var leases = 0;
      await h.rebuild(releaseLease: () async => leases++);
      await h.activate();
      h.bridge.stopCaptureError = StateError('boom');
      h.bridge.stopPlaybackError = PlatformException(code: 'x');
      h.bridge.endError = StateError('boom');
      h.agent.interruptError = StateError('boom');
      await h.call.end();
      expect(h.bridge.captureStops, 1);
      expect(h.bridge.stops, 1);
      expect(h.bridge.ends, 1);
      expect(h.agent.interrupts, 1);
      expect(leases, 1);
      expect(h.call.ended, isTrue);
    });

    test('a hang costs two seconds and nothing after it', () {
      fakeAsync((async) {
        final harness = CallHarness();
        harness.bridge.stopCaptureGate = Completer<void>();
        harness.bridge.endGate = Completer<void>();
        var leases = 0;
        harness.call = harness.build(releaseLease: () async => leases++);
        unawaited(harness.call.start());
        async.flushMicrotasks();
        harness.bridge.emit('activated');
        async.flushMicrotasks();
        var done = false;
        unawaited(harness.call.end().then((_) => done = true));
        async.flushMicrotasks();
        expect(done, isFalse);
        expect(harness.bridge.stops, 0, reason: 'still waiting for capture');
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();
        expect(harness.bridge.stops, 1);
        async.elapse(const Duration(seconds: 10));
        async.flushMicrotasks();
        expect(harness.bridge.ends, 1);
        expect(leases, 1);
        expect(harness.agent.interrupts, 1);
        expect(done, isTrue);
      });
    });

    test('the speech socket closes only after the capture did', () async {
      await h.activate();
      await h.say('First');
      h.agent.text!('An answer. ');
      var closed = false;
      unawaited(h.socket.local.sink.done.then((_) => closed = true));
      h.bridge.stopCaptureGate = Completer<void>();
      unawaited(h.call.end());
      await pumpEventQueue();
      expect(closed, isFalse, reason: 'capture is still closing');
      h.bridge.stopCaptureGate!.complete();
      await pumpEventQueue();
      expect(closed, isTrue);
    });

    test('ending twice runs the steps once', () async {
      await h.activate();
      await Future.wait([h.call.end(), h.call.end(), h.call.end('x')]);
      expect(h.bridge.captureStops, 1);
      expect(h.bridge.ends, 1);
      expect(h.agent.interrupts, 1);
    });

    test('a call that never reached native has nothing to close', () async {
      await h.rebuild();
      h.call.dispose();
      h.call = h.build(consented: false);
      await h.call.start();
      expect(h.bridge.captureStops, 0);
      expect(h.bridge.ends, 0);
    });

    test(
      'End during a pending start closes capture when it resolves',
      () async {
        h.bridge.startGate = Completer<void>();
        final starting = h.call.start();
        await pumpEventQueue();
        await h.call.end();
        expect(h.bridge.captureStops, 1);
        h.bridge.startGate!.complete();
        await starting;
        await pumpEventQueue();
        expect(h.bridge.captureStops, 2, reason: 'closed again on resolve');
        expect(h.bridge.log.last, 'stopCapture');
        expect(h.bridge.ends, 1);
      },
    );

    test('stopCapture carries the id the call started with', () async {
      await h.activate();
      await h.call.end();
      expect(h.bridge.startIds, hasLength(1));
      expect(h.bridge.captureStopIds, [h.bridge.startIds.single]);
    });

    test('a late stopCapture names its own call, not a later one', () async {
      h.bridge.startGate = Completer<void>();
      final starting = h.call.start();
      await pumpEventQueue();
      await h.call.end();
      h.bridge.startGate!.complete();
      await starting;
      await pumpEventQueue();
      final first = h.bridge.startIds.single;
      expect(h.bridge.captureStopIds, [first, first]);
      await h.rebuild();
      await h.activate();
      expect(h.bridge.startIds.last, isNot(first));
      expect(h.bridge.captureStopIds, [first, first]);
    });

    test('the lease is released between audio and the agent', () async {
      final order = <String>[];
      await h.rebuild(releaseLease: () async => h.bridge.log.add('lease'));
      await h.activate();
      h.bridge.log.clear();
      await h.call.end();
      order.addAll(h.bridge.log);
      expect(order, [
        'stopCapture',
        'stopPlayback',
        'end',
        'lease',
        'interrupt',
      ]);
    });

    test('a timed-out stopCapture says the microphone may still be open', () {
      fakeAsync((async) {
        final harness = CallHarness();
        harness.bridge.stopCaptureGate = Completer<void>();
        unawaited(harness.call.start());
        async.flushMicrotasks();
        harness.bridge.emit('activated');
        async.flushMicrotasks();
        unawaited(harness.call.end());
        async.flushMicrotasks();
        expect(
          harness.call.ended,
          isFalse,
          reason: 'not before capture closes',
        );
        async.elapse(const Duration(seconds: 3));
        async.flushMicrotasks();
        expect(harness.call.ended, isTrue);
        expect(harness.call.microphoneUnconfirmed, isTrue);
        expect(harness.call.notice, CallNotice.microphoneMayBeOpen);
        expect(harness.call.error, contains('microphone may still be open'));
        expect(harness.logged.last.$2, containsPair('capture', 'unconfirmed'));
      });
    });

    test('a confirmed close shows no such notice', () async {
      await h.activate();
      await h.call.end();
      expect(h.call.microphoneUnconfirmed, isFalse);
      expect(h.call.notice, isNull);
    });
  });

  group('route change', () {
    test('drops the turn and speech, keeps the reply and the call', () async {
      await h.activate();
      await h.say('Hello');
      expect(h.call.phase, CallPhase.thinking);
      h.bridge.emit('audioReset');
      await pumpEventQueue();
      expect(h.call.phase, CallPhase.listening);
      expect(h.agent.interrupts, 0, reason: 'the reply keeps running');
      expect(h.bridge.stops, 1, reason: 'the speech is dropped');
      expect(h.call.ended, isFalse);
      expect(
        h.call.notice,
        CallNotice.routeChangedNeutral,
        reason: 'a turn was already submitted, so no "nothing was sent"',
      );
    });

    test('keeps Waiting for you and pauses capture again', () async {
      await h.activate();
      await h.say('Hello');
      h.agent.setThreadAttention(true);
      expect(h.call.phase, CallPhase.attention);
      h.bridge.pauses = 0;
      h.bridge.emit('audioReset');
      await pumpEventQueue();
      expect(h.call.phase, CallPhase.attention);
      expect(h.agent.interrupts, 0);
      expect(h.bridge.pauses, 1, reason: 'the native reset reopened capture');
    });
  });
}
