// ignore_for_file: close_sinks, cancel_subscriptions

import 'dart:async';
import 'dart:typed_data';

import 'package:audio_session/audio_session.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/voice/calls/portable_call_bridge.dart';

class FakeRecorder implements CallRecorder {
  FakeRecorder(this.log);
  final List<String> log;
  int starts = 0, stops = 0, disposes = 0;
  Completer<void>? startGate, stopGate;
  Object? startError;
  StreamController<Uint8List>? _stream;

  /// Whether a capture is open as far as the fake knows.
  bool get open => _stream != null;

  @override
  Future<Stream<Uint8List>> start() async {
    starts++;
    log.add('recorder.start');
    await startGate?.future;
    if (startError != null) await Future<void>.error(startError!);
    final controller = _stream = StreamController<Uint8List>();
    return controller.stream;
  }

  void add(List<int> bytes) => _stream?.add(Uint8List.fromList(bytes));
  void fail(Object error) => _stream?.addError(error);
  void endStream() {
    unawaited(_stream?.close());
    _stream = null;
  }

  @override
  Future<void> stop() async {
    stops++;
    log.add('recorder.stop');
    await stopGate?.future;
    final stream = _stream;
    _stream = null;
    if (stream != null) unawaited(stream.close());
  }

  @override
  Future<void> dispose() async {
    disposes++;
    log.add('recorder.dispose');
  }
}

class FakePlayer implements CallPlayer {
  FakePlayer(this.log);
  final List<String> log;
  final played = <List<Object>>[];
  int inits = 0, stops = 0, drains = 0, disposes = 0;
  Completer<void>? drainGate, initGate;

  @override
  Future<void> init() async {
    inits++;
    await initGate?.future;
    log.add('player.init');
  }

  @override
  Future<void> play(Uint8List pcm, int rate) async {
    log.add('player.play');
    played.add([pcm.toList(), rate]);
  }

  @override
  Future<void> drain() async {
    drains++;
    log.add('player.drain');
    await drainGate?.future;
  }

  @override
  Future<void> stop() async {
    stops++;
    log.add('player.stop');
  }

  @override
  Future<void> dispose() async {
    disposes++;
    log.add('player.dispose');
  }
}

class FakeSession implements CallAudioSession {
  FakeSession(this.log);
  final List<String> log;
  final interruptionsController = StreamController<AudioInterruptionEvent>();
  final routesController = StreamController<void>();
  final speakerCalls = <bool>[];
  int activations = 0, deactivations = 0;
  Object? activateError;
  Completer<void>? activateGate;

  @override
  Stream<AudioInterruptionEvent> get interruptions =>
      interruptionsController.stream;
  @override
  Stream<void> get routeChanges => routesController.stream;
  @override
  Future<void> activate() async {
    activations++;
    await activateGate?.future;
    log.add('session.activate');
    if (activateError != null) await Future<void>.error(activateError!);
  }

  @override
  Future<void> deactivate() async {
    deactivations++;
    log.add('session.deactivate');
  }

  @override
  Future<void> setSpeaker(bool enabled) async => speakerCalls.add(enabled);
}

class Rig {
  Rig({bool bargeIn = false, bool session = false}) {
    recorder = FakeRecorder(log);
    player = FakePlayer(log);
    audioSession = session ? FakeSession(log) : null;
    bridge = PortableCallBridge(
      recorder: recorder,
      player: player,
      session: audioSession,
      bargeIn: bargeIn,
    );
    sub = bridge.events.listen(events.add);
  }

  final log = <String>[];
  final events = <Map<String, Object?>>[];
  late final FakeRecorder recorder;
  late final FakePlayer player;
  late final FakeSession? audioSession;
  late final PortableCallBridge bridge;
  late final StreamSubscription<Map<String, Object?>> sub;

  List<String> get types => [for (final e in events) e['type']! as String];
  Iterable<Map<String, Object?>> of(String type) =>
      events.where((e) => e['type'] == type);

  Future<void> started([String id = 'call-1']) async {
    await bridge.start(id, 'Hermes');
    await pump();
  }

  Future<void> pump() async {
    for (var i = 0; i < 6; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }
}

Uint8List _pcm(int length, [int value = 1]) =>
    Uint8List.fromList(List.filled(length, value));

void main() {
  test('constructing a bridge opens no microphone and no audio', () async {
    final rig = Rig(session: true);
    await rig.pump();
    expect(rig.recorder.starts, 0);
    expect(rig.player.inits, 0);
    expect(rig.audioSession!.activations, 0);
    expect(rig.events, isEmpty);
  });

  test('start emits activated once the capture has started', () async {
    final rig = Rig();
    final gate = rig.recorder.startGate = Completer<void>();
    final start = rig.bridge.start('call-1', 'Hermes');
    await rig.pump();
    expect(rig.recorder.starts, 1);
    expect(rig.types, isNot(contains('activated')));
    gate.complete();
    await start;
    await rig.pump();
    expect(rig.types, ['activated']);
    expect(rig.player.inits, 1);
  });

  test('pcm from the recorder becomes pcm events, odd bytes carried', () async {
    final rig = Rig();
    await rig.started();
    rig.recorder.add([1, 2, 3]);
    await rig.pump();
    rig.recorder.add([4, 5]);
    await rig.pump();
    final chunks = [
      for (final e in rig.of('pcm')) (e['data']! as Uint8List).toList(),
    ];
    expect(chunks, [
      [1, 2],
      [3, 4],
    ]);
    // The fifth byte waits for its partner.
    rig.recorder.add([6]);
    await rig.pump();
    expect(rig.of('pcm').last['data'], Uint8List.fromList([5, 6]));
  });

  test(
    'pauseCapture closes the microphone and says why, resume reopens',
    () async {
      final rig = Rig();
      await rig.started();
      await rig.bridge.pauseCapture();
      await rig.pump();
      expect(rig.recorder.open, isFalse);
      expect(rig.of('capturePaused').single, {
        'type': 'capturePaused',
        'paused': true,
        'reason': 'request',
      });
      await rig.bridge.pauseCapture();
      expect(rig.of('capturePaused'), hasLength(1), reason: 'idempotent');
      await rig.bridge.resumeCapture();
      await rig.pump();
      expect(rig.recorder.open, isTrue);
      expect(rig.of('capturePaused').last['paused'], false);
      // No second `activated` for a reopened capture.
      expect(rig.of('activated'), hasLength(1));
    },
  );

  test('mute closes the microphone and reports muted', () async {
    final rig = Rig();
    await rig.started();
    await rig.bridge.mute(true);
    await rig.pump();
    expect(rig.recorder.open, isFalse);
    expect(rig.of('muted').single['muted'], true);
    await rig.bridge.mute(false);
    await rig.pump();
    expect(rig.recorder.open, isTrue);
    expect(rig.of('muted').last['muted'], false);
  });

  test(
    'a pause while muted does not reopen the microphone on resume',
    () async {
      final rig = Rig();
      await rig.started();
      await rig.bridge.mute(true);
      await rig.bridge.pauseCapture();
      await rig.bridge.resumeCapture();
      await rig.pump();
      expect(rig.recorder.open, isFalse);
    },
  );

  test('stopCapture closes the capture; a stale id changes nothing', () async {
    final rig = Rig();
    await rig.started('call-2');
    await rig.bridge.stopCapture('call-1');
    await rig.pump();
    expect(rig.recorder.open, isTrue, reason: 'stale id');
    await rig.bridge.stopCapture('call-2');
    await rig.pump();
    expect(rig.recorder.open, isFalse);
    // Nothing reopens it afterwards.
    await rig.bridge.resumeCapture();
    await rig.bridge.mute(false);
    await rig.pump();
    expect(rig.recorder.open, isFalse);
  });

  test('play hands even bytes to the player at the start rate', () async {
    final rig = Rig();
    await rig.started();
    await rig.bridge.play(Uint8List.fromList([1, 2, 3]), 22050);
    await rig.bridge.play(Uint8List.fromList([4, 5, 6]), 22050);
    expect(rig.player.played, [
      [
        [1, 2],
        22050,
      ],
      [
        [3, 4, 5, 6],
        22050,
      ],
    ]);
  });

  test('a changed rate drops the carried byte', () async {
    final rig = Rig();
    await rig.started();
    await rig.bridge.play(Uint8List.fromList([1, 2, 3]), 22050);
    await rig.bridge.play(Uint8List.fromList([4, 5]), 24000);
    expect(rig.player.played.last, [
      [4, 5],
      24000,
    ]);
  });

  test('drain waits for the player; stopPlayback stops it', () async {
    final rig = Rig();
    await rig.started();
    final gate = rig.player.drainGate = Completer<void>();
    var drained = false;
    final drain = rig.bridge.drain().then((_) => drained = true);
    await rig.pump();
    expect(drained, isFalse);
    gate.complete();
    await drain;
    expect(drained, isTrue);
    await rig.bridge.stopPlayback();
    expect(rig.player.stops, 1);
  });

  group('without echo cancellation', () {
    test(
      'capture closes while audio plays and reopens 400 ms after the drain',
      () {
        fakeAsync((async) {
          final rig = Rig();
          rig.bridge.start('call-1', 'Hermes');
          async.flushMicrotasks();
          expect(rig.recorder.open, isTrue);
          // One second of audio at 16 kHz.
          rig.bridge.play(_pcm(32000), 16000);
          async.flushMicrotasks();
          expect(rig.recorder.open, isFalse);
          expect(rig.of('capturePaused').last, {
            'type': 'capturePaused',
            'paused': true,
            'reason': 'playback',
          });
          rig.bridge.drain();
          async.flushMicrotasks();
          async.elapse(const Duration(milliseconds: 399));
          expect(rig.recorder.open, isFalse);
          async.elapse(const Duration(milliseconds: 2));
          async.flushMicrotasks();
          expect(rig.recorder.open, isTrue);
          expect(rig.of('capturePaused').last['paused'], false);
          // Closed and opened by the bridge only: no second activation.
          expect(rig.of('activated'), hasLength(1));
        });
      },
    );

    test(
      'a tone with no drain still releases the microphone after its length',
      () {
        fakeAsync((async) {
          final rig = Rig();
          rig.bridge.start('call-1', 'Hermes');
          async.flushMicrotasks();
          // 200 ms at 24 kHz.
          rig.bridge.play(_pcm(9600), 24000);
          async.flushMicrotasks();
          expect(rig.recorder.open, isFalse);
          async.elapse(const Duration(milliseconds: 590));
          expect(rig.recorder.open, isFalse);
          async.elapse(const Duration(milliseconds: 20));
          async.flushMicrotasks();
          expect(rig.recorder.open, isTrue);
        });
      },
    );

    test('more audio before the tail ends extends the block', () {
      fakeAsync((async) {
        final rig = Rig();
        rig.bridge.start('call-1', 'Hermes');
        async.flushMicrotasks();
        rig.bridge.play(_pcm(3200), 16000); // 100 ms
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 450));
        rig.bridge.play(_pcm(3200), 16000);
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 400));
        expect(rig.recorder.open, isFalse);
        async.elapse(const Duration(milliseconds: 200));
        async.flushMicrotasks();
        expect(rig.recorder.open, isTrue);
      });
    });

    test('the call stays paused by request after the playback block ends', () {
      fakeAsync((async) {
        final rig = Rig();
        rig.bridge.start('call-1', 'Hermes');
        async.flushMicrotasks();
        rig.bridge.pauseCapture();
        rig.bridge.play(_pcm(3200), 16000);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();
        expect(rig.recorder.open, isFalse);
        rig.bridge.resumeCapture();
        async.flushMicrotasks();
        expect(rig.recorder.open, isTrue);
      });
    });

    test('stopPlayback starts the tail at once', () {
      fakeAsync((async) {
        final rig = Rig();
        rig.bridge.start('call-1', 'Hermes');
        async.flushMicrotasks();
        rig.bridge.play(_pcm(320000), 16000); // ten seconds
        async.flushMicrotasks();
        rig.bridge.stopPlayback();
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 410));
        async.flushMicrotasks();
        expect(rig.recorder.open, isTrue);
      });
    });
  });

  test('with echo cancellation capture stays open while audio plays', () async {
    final rig = Rig(bargeIn: true);
    await rig.started();
    await rig.bridge.play(_pcm(32000), 16000);
    await rig.pump();
    expect(rig.recorder.open, isTrue);
    expect(rig.of('capturePaused'), isEmpty);
  });

  group('audio focus', () {
    test('a permanent loss deactivates the call with reason focus', () async {
      final rig = Rig(session: true);
      await rig.started();
      rig.audioSession!.interruptionsController.add(
        AudioInterruptionEvent(true, AudioInterruptionType.unknown),
      );
      await rig.pump();
      expect(rig.of('deactivated').single['reason'], 'focus');
    });

    test('a transient loss deactivates it too', () async {
      final rig = Rig(session: true);
      await rig.started();
      rig.audioSession!.interruptionsController.add(
        AudioInterruptionEvent(true, AudioInterruptionType.pause),
      );
      await rig.pump();
      expect(rig.of('deactivated'), hasLength(1));
    });

    test('ducking does not, and neither does getting focus back', () async {
      final rig = Rig(session: true);
      await rig.started();
      rig.audioSession!.interruptionsController
        ..add(AudioInterruptionEvent(true, AudioInterruptionType.duck))
        ..add(AudioInterruptionEvent(false, AudioInterruptionType.duck))
        ..add(AudioInterruptionEvent(false, AudioInterruptionType.pause));
      await rig.pump();
      expect(rig.of('deactivated'), isEmpty);
    });
  });

  test('a route change resets the audio and reopens the capture', () async {
    final rig = Rig(session: true);
    await rig.started();
    final before = rig.recorder.starts;
    rig.audioSession!.routesController.add(null);
    await rig.pump();
    expect(rig.of('audioReset'), hasLength(1));
    expect(rig.recorder.starts, before + 1);
    expect(rig.recorder.open, isTrue);
  });

  test('a route change while paused leaves the microphone closed', () async {
    final rig = Rig(session: true);
    await rig.started();
    await rig.bridge.pauseCapture();
    rig.audioSession!.routesController.add(null);
    await rig.pump();
    expect(rig.of('audioReset'), hasLength(1));
    expect(rig.recorder.open, isFalse);
  });

  group('End during the start releases what it acquired', () {
    test(
      'a player whose init finishes after End is disposed after it',
      () async {
        final rig = Rig();
        final gate = rig.player.initGate = Completer<void>();
        final start = rig.bridge.start('call-1', 'Hermes');
        await rig.pump();
        await rig.bridge.end();
        gate.complete();
        await start;
        await rig.pump();
        expect(rig.log.last, 'player.dispose');
        expect(
          rig.log.lastIndexOf('player.dispose'),
          greaterThan(rig.log.indexOf('player.init')),
        );
        expect(rig.recorder.starts, 0);
      },
    );

    test('audio focus taken after End is given back', () async {
      final rig = Rig(session: true);
      final gate = rig.audioSession!.activateGate = Completer<void>();
      final start = rig.bridge.start('call-1', 'Hermes');
      await rig.pump();
      await rig.bridge.end();
      gate.complete();
      await start;
      await rig.pump();
      expect(rig.log.last, 'session.deactivate');
      expect(
        rig.log.lastIndexOf('session.deactivate'),
        greaterThan(rig.log.indexOf('session.activate')),
      );
      expect(rig.player.inits, 0);
    });
  });

  test('End does not wait for a recorder that hangs on stop', () {
    fakeAsync((async) {
      final rig = Rig();
      rig.bridge.start('call-1', 'Hermes');
      async.flushMicrotasks();
      rig.recorder.stopGate = Completer<void>();
      var done = false;
      rig.bridge.end().then((_) => done = true);
      async.flushMicrotasks();
      expect(done, isFalse);
      async.elapse(const Duration(seconds: 3));
      async.flushMicrotasks();
      expect(done, isTrue);
      expect(rig.log, containsAll(['player.dispose', 'recorder.dispose']));
    });
  });

  group('cancellable start', () {
    test('a pause and resume during the start do not cancel it', () async {
      final rig = Rig();
      final gate = rig.recorder.startGate = Completer<void>();
      final start = rig.bridge.start('call-1', 'Hermes');
      await rig.pump();
      await rig.bridge.pauseCapture();
      await rig.bridge.resumeCapture();
      gate.complete();
      await start;
      await rig.pump();
      expect(rig.types, contains('activated'));
      expect(rig.log, ['player.init', 'recorder.start']);
    });

    test(
      'a pause during the start leaves the microphone closed after it',
      () async {
        final rig = Rig();
        final gate = rig.recorder.startGate = Completer<void>();
        final start = rig.bridge.start('call-1', 'Hermes');
        await rig.pump();
        await rig.bridge.pauseCapture();
        gate.complete();
        await start;
        await rig.pump();
        expect(rig.types, contains('activated'));
        expect(rig.recorder.open, isFalse);
        await rig.bridge.resumeCapture();
        await rig.pump();
        expect(rig.recorder.open, isTrue);
      },
    );

    test(
      'End during the pending recorder start closes it when it resolves',
      () async {
        final rig = Rig();
        final gate = rig.recorder.startGate = Completer<void>();
        final start = rig.bridge.start('call-1', 'Hermes');
        await rig.pump();
        await rig.bridge.stopCapture('call-1');
        await rig.bridge.end();
        gate.complete();
        await start;
        await rig.pump();
        expect(rig.recorder.open, isFalse);
        expect(rig.recorder.stops, greaterThanOrEqualTo(1));
        // The stop that follows the late resolve comes after the start.
        final lastStart = rig.log.lastIndexOf('recorder.start');
        expect(rig.log.sublist(lastStart + 1), contains('recorder.stop'));
        expect(rig.types, isNot(contains('activated')));
        rig.recorder.add([1, 2]);
        await rig.pump();
        expect(rig.of('pcm'), isEmpty);
      },
    );

    test('a start that fails after End raises nothing', () async {
      final rig = Rig();
      final gate = rig.recorder.startGate = Completer<void>();
      rig.recorder.startError = StateError('mic');
      final start = rig.bridge.start('call-1', 'Hermes');
      await rig.pump();
      await rig.bridge.end();
      gate.complete();
      await start;
    });
  });

  test('a microphone that cannot start fails the start', () async {
    final rig = Rig(session: true);
    rig.recorder.startError = StateError('no microphone');
    await expectLater(rig.bridge.start('call-1', 'Hermes'), throwsStateError);
    await rig.pump();
    expect(rig.types, isNot(contains('activated')));
    // Whatever was acquired is let go again.
    expect(rig.audioSession!.deactivations, 1);
    expect(rig.player.disposes, 1);
  });

  test('a recorder stream that fails mid-call sends an error event', () async {
    final rig = Rig();
    await rig.started();
    rig.recorder.fail(StateError('device gone'));
    await rig.pump();
    expect(rig.of('error').single['code'], 'audio_start');
  });

  test('a recorder stream that ends by itself sends an error event', () async {
    final rig = Rig();
    await rig.started();
    rig.recorder.endStream();
    await rig.pump();
    expect(rig.of('error'), hasLength(1));
  });

  test('a stream that ends because the bridge closed it is no error', () async {
    final rig = Rig();
    await rig.started();
    await rig.bridge.pauseCapture();
    await rig.pump();
    expect(rig.of('error'), isEmpty);
  });

  group('speaker', () {
    test('routes through the audio session and reports the route', () async {
      final rig = Rig(session: true);
      await rig.started();
      await rig.bridge.speaker(true);
      expect(rig.audioSession!.speakerCalls, [true]);
      await rig.pump();
      expect(rig.of('route').single, {
        'type': 'route',
        'name': 'Speaker',
        'speaker': true,
      });
      await rig.bridge.speaker(false);
      await rig.pump();
      expect(rig.of('route').last['speaker'], false);
    });

    test('its own route change is not a route reset', () {
      fakeAsync((async) {
        final rig = Rig(session: true);
        rig.bridge.start('call-1', 'Hermes');
        async.flushMicrotasks();
        rig.bridge.speaker(true);
        async.flushMicrotasks();
        rig.audioSession!.routesController.add(null);
        async.flushMicrotasks();
        expect(rig.of('audioReset'), isEmpty);
        async.elapse(const Duration(seconds: 1));
        rig.audioSession!.routesController.add(null);
        async.flushMicrotasks();
        expect(rig.of('audioReset'), hasLength(1));
      });
    });

    test('is a no-op without an audio session', () async {
      final rig = Rig();
      await rig.started();
      await rig.bridge.speaker(true);
      expect(rig.of('route'), isEmpty);
    });
  });

  test('connected does nothing', () async {
    final rig = Rig();
    await rig.started();
    final count = rig.events.length;
    await rig.bridge.connected();
    await rig.pump();
    expect(rig.events.length, count);
  });

  test(
    'end closes the capture first, then playback, then the session',
    () async {
      final rig = Rig(session: true);
      await rig.started();
      rig.log.clear();
      await rig.bridge.end();
      expect(rig.log.first, 'recorder.stop');
      expect(
        rig.log.indexOf('recorder.stop'),
        lessThan(rig.log.indexOf('player.stop')),
      );
      expect(
        rig.log.indexOf('player.stop'),
        lessThan(rig.log.indexOf('session.deactivate')),
      );
      expect(rig.recorder.disposes, 1);
      expect(rig.player.disposes, 1);
      // A second end changes nothing.
      final count = rig.log.length;
      await rig.bridge.end();
      expect(rig.log.length, count);
    },
  );

  test('nothing plays or opens after End', () async {
    final rig = Rig();
    await rig.started();
    await rig.bridge.end();
    await rig.bridge.play(_pcm(4), 16000);
    await rig.bridge.resumeCapture();
    await rig.pump();
    expect(rig.player.played, isEmpty);
    expect(rig.recorder.open, isFalse);
  });

  test('the barge-in capability is a constructor choice', () {
    expect(Rig().bridge.bargeIn, isFalse);
    expect(Rig(bargeIn: true).bridge.bargeIn, isTrue);
  });
}
