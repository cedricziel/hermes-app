import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';
import 'package:stream_channel/stream_channel.dart';

import '../support/recording_tracer.dart';

/// A request span of a gateway client ends by its deadline and says why, also
/// when the app was suspended past it: timers stop while the process sleeps,
/// so the end would otherwise be stamped when the app came back.
void main() {
  late RecordingTracer tracer;
  late StreamChannelController<String> wire;
  late List<Map<String, Object?>> frames;

  const deadline = Duration(seconds: 30);

  /// Runs [body] with a wall clock that [jump] can move without any timer
  /// firing, as a suspended process sees it.
  void run(
    void Function(
      FakeAsync async,
      GatewayRpcClient Function({
        Duration? defaultTimeout,
        StreamChannel<String>? channel,
      })
      open,
      void Function(Duration by) jump,
      DateTime Function() now,
    )
    body,
  ) {
    fakeAsync((async) {
      final start = DateTime(2026, 1, 1, 12);
      var jumped = Duration.zero;
      DateTime now() => start.add(async.elapsed + jumped);
      withClock(Clock(now), () {
        tracer = RecordingTracer();
        wire = StreamChannelController<String>();
        frames = [];
        wire.foreign.stream.listen(
          (frame) => frames.add(jsonDecode(frame) as Map<String, Object?>),
        );
        GatewayRpcClient open({
          Duration? defaultTimeout,
          StreamChannel<String>? channel,
        }) => GatewayRpcClient(
          channel ?? wire.local,
          telemetry: ConnectionTelemetry(tracer: tracer).gateway(),
          defaultTimeout: defaultTimeout,
        );
        body(async, open, (by) => jumped += by, now);
      });
    });
  }

  test('a request past its timeout fails and its span says so', () {
    run((async, open, jump, now) {
      final client = open();
      final sent = now();
      Object? error;
      client
          .requestWithin('slash.exec', const {}, timeout: deadline)
          .then<void>((_) {}, onError: (Object e) => error = e);

      async.elapse(deadline);
      async.flushMicrotasks();

      expect(error, isA<GatewayRequestTimeout>());
      final span = tracer.spans.single;
      expect(span.ended, isTrue);
      expect(span.status?.name, 'error');
      expect(span.attributes['error.type'], 'GatewayRequestTimeout');
      expect(span.endTime, isNull, reason: 'on time, nothing is backdated');
      expect(now().difference(sent), deadline);
      unawaited(client.close());
      async.flushMicrotasks();
    });
  });

  test('a request given no timeout takes the default one', () {
    run((async, open, jump, now) {
      final client = open(defaultTimeout: deadline);
      Object? error;
      client
          .request('memory.proposals', const {})
          .then<void>((_) {}, onError: (Object e) => error = e);

      async.elapse(deadline);
      async.flushMicrotasks();

      expect(error, isA<GatewayRequestTimeout>());
      expect(tracer.spans.single.ended, isTrue);
      unawaited(client.close());
      async.flushMicrotasks();
    });
  });

  test('a guarded request has the deadline too', () {
    run((async, open, jump, now) {
      final client = open();
      Object? error;
      client
          .requestGuarded(
            'billing.step_up',
            const {},
            authorize: () => true,
            timeout: deadline,
          )
          .then<void>((_) {}, onError: (Object e) => error = e);

      async.elapse(deadline);
      async.flushMicrotasks();

      expect(error, isA<GatewayRequestTimeout>());
      expect(tracer.spans.single.ended, isTrue);
      unawaited(client.close());
      async.flushMicrotasks();
    });
  });

  test('a timeout that fires after the app slept ends the span at its '
      'deadline, not when the app came back', () {
    run((async, open, jump, now) {
      final client = open();
      final sent = now();
      client
          .requestWithin('slash.exec', const {}, timeout: deadline)
          .then<void>((_) {}, onError: (Object _) {});

      // The phone locked: 30 minutes pass on the wall clock, no timer runs.
      jump(const Duration(minutes: 30));
      async.elapse(deadline);
      async.flushMicrotasks();

      final span = tracer.spans.single;
      expect(span.ended, isTrue);
      expect(span.attributes['error.type'], 'GatewayRequestTimeout');
      expect(span.endTime, sent.add(deadline));
      unawaited(client.close());
      async.flushMicrotasks();
    });
  });

  test('a socket that closes after the app slept ends the span at the '
      "request's deadline and fails it fast", () {
    run((async, open, jump, now) {
      final client = open();
      final sent = now();
      Object? error;
      client
          .requestWithin('slash.exec', const {}, timeout: deadline)
          .then<void>((_) {}, onError: (Object e) => error = e);
      async.flushMicrotasks();

      jump(const Duration(minutes: 15));
      unawaited(client.close());
      async.flushMicrotasks();

      expect(error, isA<GatewayConnectionClosed>());
      final span = tracer.spans.single;
      expect(span.attributes['error.type'], 'GatewayConnectionClosed');
      expect(span.endTime, sent.add(deadline));
    });
  });

  test('a socket that closes within the deadline ends the span as it is', () {
    run((async, open, jump, now) {
      final client = open();
      client
          .requestWithin('slash.exec', const {}, timeout: deadline)
          .then<void>((_) {}, onError: (Object _) {});
      async.flushMicrotasks();

      async.elapse(const Duration(seconds: 5));
      unawaited(client.close());
      async.flushMicrotasks();

      final span = tracer.spans.single;
      expect(span.attributes['error.type'], 'GatewayConnectionClosed');
      expect(span.endTime, isNull);
    });
  });

  test('an answer ends the span once, and the timer does not end it again', () {
    run((async, open, jump, now) {
      final client = open();
      Map<String, Object?>? result;
      client
          .requestWithin('slash.exec', const {}, timeout: deadline)
          .then<void>((r) => result = r);
      async.flushMicrotasks();
      final id = frames.single['id'];

      wire.foreign.sink.add(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': id,
          'result': {'ok': true},
        }),
      );
      async.elapse(deadline * 2);
      async.flushMicrotasks();

      expect(result, {'ok': true});
      final span = tracer.spans.single;
      expect(span.endCalls, 1);
      expect(span.status?.name, 'ok');
      unawaited(client.close());
      async.flushMicrotasks();
    });
  });

  test('a late answer of an abandoned request is ignored', () {
    run((async, open, jump, now) {
      final client = open();
      client
          .requestWithin('slash.exec', const {}, timeout: deadline)
          .then<void>((_) {}, onError: (Object _) {});
      async.flushMicrotasks();
      final id = frames.single['id'];
      async.elapse(deadline);
      async.flushMicrotasks();

      wire.foreign.sink.add(jsonEncode({'jsonrpc': '2.0', 'id': id}));
      async.flushMicrotasks();

      expect(tracer.spans.single.endCalls, 1);
      expect(client.isClosed, isFalse);
      unawaited(client.close());
      async.flushMicrotasks();
    });
  });

  test('an answer to a request that must undo a late result, read after the '
      'deadline and before the timer ran, is a timeout; the span ends once, '
      'at the deadline', () {
    run((async, open, jump, now) {
      final client = open();
      final sent = now();
      Object? error;
      Map<String, Object?>? result;
      client
          .requestWithin(
            'image.attach_bytes',
            const {},
            timeout: deadline,
            onLateResult: (_) {},
          )
          .then<void>((r) => result = r, onError: (Object e) => error = e);
      async.flushMicrotasks();
      final id = frames.single['id'];

      // The app slept past the deadline; the answer was waiting on the socket
      // and is read before the overdue timer runs.
      jump(const Duration(minutes: 10));
      wire.foreign.sink.add(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': id,
          'result': {'ok': true},
        }),
      );
      async.flushMicrotasks();

      expect(result, isNull);
      expect(error, isA<GatewayRequestTimeout>());
      final span = tracer.spans.single;
      expect(span.endCalls, 1);
      expect(span.attributes['error.type'], 'GatewayRequestTimeout');
      expect(span.endTime, sent.add(deadline));

      async.elapse(deadline);
      async.flushMicrotasks();
      expect(span.endCalls, 1);
      unawaited(client.close());
      async.flushMicrotasks();
    });
  });

  test('a liveness probe answered late still finds the socket alive', () {
    run((async, open, jump, now) {
      final client = open();
      bool? alive;
      client.isResponsive(deadline).then((v) => alive = v);
      async.flushMicrotasks();
      final id = frames.single['id'];

      jump(const Duration(minutes: 10));
      wire.foreign.sink.add(
        jsonEncode({'jsonrpc': '2.0', 'id': id, 'result': <String, Object?>{}}),
      );
      async.flushMicrotasks();

      expect(alive, isTrue);
      expect(client.isClosed, isFalse);
      expect(tracer.spans.single.endCalls, 1);
      unawaited(client.close());
      async.flushMicrotasks();
    });
  });

  test('the answer of a request that timed out is handed to onLateResult, '
      'once', () {
    run((async, open, jump, now) {
      final client = open();
      final late = <Map<String, Object?>>[];
      client
          .requestWithin(
            'image.attach_bytes',
            const {},
            timeout: deadline,
            onLateResult: late.add,
          )
          .then<void>((_) {}, onError: (Object _) {});
      async.flushMicrotasks();
      final id = frames.single['id'];
      async.elapse(deadline);
      async.flushMicrotasks();
      expect(late, isEmpty);

      for (var i = 0; i < 2; i++) {
        wire.foreign.sink.add(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': id,
            'result': {'path': '/p.png'},
          }),
        );
        async.flushMicrotasks();
      }

      expect(late, [
        {'path': '/p.png'},
      ]);
      unawaited(client.close());
      async.flushMicrotasks();
    });
  });

  test(
    'an answer that is a timeout by the clock also reaches onLateResult',
    () {
      run((async, open, jump, now) {
        final client = open();
        final late = <Map<String, Object?>>[];
        client
            .requestWithin(
              'image.attach_bytes',
              const {},
              timeout: deadline,
              onLateResult: late.add,
            )
            .then<void>((_) {}, onError: (Object _) {});
        async.flushMicrotasks();
        jump(const Duration(minutes: 10));
        wire.foreign.sink.add(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': frames.single['id'],
            'result': {'path': '/p.png'},
          }),
        );
        async.flushMicrotasks();

        expect(late, [
          {'path': '/p.png'},
        ]);
        unawaited(client.close());
        async.flushMicrotasks();
      });
    },
  );

  test('a request with no deadline of its own still settles on a late answer, '
      'with its span ended at the default deadline', () {
    run((async, open, jump, now) {
      final client = open(defaultTimeout: deadline);
      final sent = now();
      Map<String, Object?>? result;
      Object? error;
      client
          .request('approval.respond', const {})
          .then<void>((r) => result = r, onError: (Object e) => error = e);
      async.flushMicrotasks();

      jump(const Duration(minutes: 10));
      wire.foreign.sink.add(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': frames.single['id'],
          'result': {'resolved': 1},
        }),
      );
      async.flushMicrotasks();

      expect(error, isNull);
      expect(result, {'resolved': 1});
      final span = tracer.spans.single;
      expect(span.endCalls, 1);
      expect(span.status?.name, 'ok');
      expect(span.endTime, sent.add(deadline));
      unawaited(client.close());
      async.flushMicrotasks();
    });
  });

  test('any other request settles on an answer read after the deadline, with '
      'its span ended once, at the deadline', () {
    run((async, open, jump, now) {
      final client = open();
      final sent = now();
      Map<String, Object?>? result;
      Object? error;
      client
          .requestWithin('prompt.submit', const {}, timeout: deadline)
          .then<void>((r) => result = r, onError: (Object e) => error = e);
      async.flushMicrotasks();

      jump(const Duration(minutes: 10));
      wire.foreign.sink.add(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': frames.single['id'],
          'result': {'status': 'streaming'},
        }),
      );
      async.flushMicrotasks();
      async.elapse(deadline);
      async.flushMicrotasks();

      expect(error, isNull);
      expect(result, {'status': 'streaming'});
      final span = tracer.spans.single;
      expect(span.endCalls, 1);
      expect(span.status?.name, 'ok');
      expect(span.endTime, sent.add(deadline));
      unawaited(client.close());
      async.flushMicrotasks();
    });
  });

  test('a liveness probe nobody answers returns false, ends its span once as '
      'a timeout and leaves no request pending', () {
    run((async, open, jump, now) {
      final client = open();
      bool? alive;
      client.isResponsive(deadline).then((v) => alive = v);
      async.flushMicrotasks();

      async.elapse(deadline);
      async.flushMicrotasks();
      expect(alive, isFalse);
      final span = tracer.spans.single;
      expect(span.endCalls, 1);
      expect(span.attributes['error.type'], 'GatewayRequestTimeout');

      // The socket closing afterwards finds nothing left to end.
      unawaited(client.close());
      async.flushMicrotasks();
      expect(span.endCalls, 1);
      expect(span.attributes['error.type'], 'GatewayRequestTimeout');
    });
  });

  test(
    'the deadline runs from when the frame is out, not from encoding it',
    () {
      run((async, open, jump, now) {
        // Writing a large frame takes two seconds of the clock.
        final slow = StreamChannel<String>.withGuarantees(
          wire.local.stream,
          _SlowSink(wire.local.sink, () => jump(const Duration(seconds: 2))),
        );
        final client = open(channel: slow);
        final late = <Map<String, Object?>>[];
        Object? error;
        client
            .requestWithin(
              'image.attach_bytes',
              const {},
              timeout: deadline,
              onLateResult: late.add,
            )
            .then<void>((_) {}, onError: (Object e) => error = e);
        async.flushMicrotasks();

        // The answer comes 29 s after the frame went out, within its deadline,
        // but 31 s after the request began.
        jump(const Duration(seconds: 29, milliseconds: 500));
        wire.foreign.sink.add(
          jsonEncode({
            'jsonrpc': '2.0',
            'id': frames.single['id'],
            'result': {'path': '/p.png'},
          }),
        );
        async.flushMicrotasks();

        expect(error, isNull);
        expect(late, isEmpty);
        unawaited(client.close());
        async.flushMicrotasks();
      });
    },
  );
}

class _SlowSink implements StreamSink<String> {
  _SlowSink(this._inner, this._onAdd);

  final StreamSink<String> _inner;
  final void Function() _onAdd;

  @override
  void add(String event) {
    _onAdd();
    _inner.add(event);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _inner.addError(error, stackTrace);

  @override
  Future<void> addStream(Stream<String> stream) => _inner.addStream(stream);

  @override
  Future<void> close() => _inner.close();

  @override
  Future<void> get done => _inner.done;
}
