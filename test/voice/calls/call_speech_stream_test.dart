import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:hermes_app/src/voice/calls/call_speech_stream.dart';
import 'package:stream_channel/stream_channel.dart';

import 'fakes.dart';

void main() {
  test(
    'streams text, reconstructs split PCM samples, waits for speaker drain',
    () async {
      final socket = StreamChannelController<Object?>();
      final sent = <Object?>[];
      socket.foreign.stream.listen(sent.add);
      final output = FakeCallBridge()..drainGate = Completer<void>();
      final stream = CallSpeechStream(
        connect: ([q = const {}]) async {
          expect(q, {'profile': 'work'});
          return socket.local;
        },
        output: output,
      );
      stream.append('Hello.');
      await stream.open('work');
      final done = stream.finish();
      var finished = false;
      unawaited(done.then((_) => finished = true));
      socket.foreign.sink
        ..add(
          jsonEncode({'type': 'start', 'sample_rate': 48000, 'channels': 1}),
        )
        ..add([1, 2, 3])
        ..add([4, 5, 6])
        ..add(jsonEncode({'type': 'end'}));
      await pumpEventQueue();
      expect(sent.map((v) => jsonDecode(v as String)), [
        {'text': 'Hello.'},
        {'done': true},
      ]);
      expect(output.played.map((p) => p.$1), [
        [1, 2],
        [3, 4, 5, 6],
      ]);
      expect(output.played.map((p) => p.$2), [48000, 48000]);
      expect(finished, isFalse);
      output.drainGate!.complete();
      await done;
    },
  );
  for (final frame in [
    jsonEncode({'type': 'fallback'}),
    [1, 2],
    jsonEncode({'type': 'start', 'sample_rate': 0, 'channels': 1}),
  ]) {
    test(
      'fails promptly for unsupported/missing audio format: $frame',
      () async {
        final socket = StreamChannelController<Object?>();
        socket.foreign.stream.listen((_) {});
        var failures = 0;
        final stream = CallSpeechStream(
          connect: ([_ = const {}]) async => socket.local,
          output: FakeCallBridge(),
          onFailure: () => failures++,
        );
        await stream.open(null);
        socket.foreign.sink.add(frame);
        await pumpEventQueue(); // Failure before finish must not be unhandled.
        await expectLater(stream.finish(), throwsStateError);
        expect(failures, 1);
      },
    );
  }
  test('ending before a socket opens closes the late socket', () async {
    final opened = Completer<StreamChannel<Object?>>();
    final socket = StreamChannelController<Object?>();
    var closed = false;
    socket.foreign.stream.listen((_) {}, onDone: () => closed = true);
    final output = FakeCallBridge();
    final stream = CallSpeechStream(
      connect: ([_ = const {}]) => opened.future,
      output: output,
    );
    final opening = stream.open(null);
    await stream.stop();
    opened.complete(socket.local);
    await opening;
    await pumpEventQueue();
    expect(closed, isTrue);
    expect(output.stops, 1);
    expect(output.played, isEmpty);
  });
  test(
    'a connection completing after timeout is closed without leaking a socket',
    () {
      fakeAsync((clock) {
        final opened = Completer<StreamChannel<Object?>>();
        final socket = StreamChannelController<Object?>();
        var closed = false;
        socket.foreign.stream.listen((_) {}, onDone: () => closed = true);
        final stream = CallSpeechStream(
          connect: ([_ = const {}]) => opened.future,
          output: FakeCallBridge(),
        );
        var failed = false;
        unawaited(
          stream.open(null).catchError((Object _) {
            failed = true;
          }),
        );
        clock.elapse(const Duration(seconds: 11));
        clock.flushMicrotasks();
        expect(failed, isTrue);
        opened.complete(socket.local);
        clock.flushMicrotasks();
        expect(closed, isTrue);
      });
    },
  );
}
