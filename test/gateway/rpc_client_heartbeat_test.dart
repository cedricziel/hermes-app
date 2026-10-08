import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:stream_channel/stream_channel.dart';

/// Answers every frame the client sends the way a gateway would: pings are
/// answered (or refused as unknown), and every other frame is recorded.
class _Server {
  _Server(this.wire, {this.answerPings = true, this.pingUnknown = false}) {
    wire.foreign.stream.listen(_onFrame);
  }

  final StreamChannelController<String> wire;
  final bool answerPings;
  final bool pingUnknown;

  /// Every frame the client sent, decoded.
  final frames = <Map<String, Object?>>[];

  int get pingCount =>
      frames.where((f) => f['method'] == 'gateway.ping').length;

  void _onFrame(String frame) {
    final message = jsonDecode(frame) as Map<String, Object?>;
    frames.add(message);
    if (message['method'] != 'gateway.ping' || !answerPings) return;
    final id = message['id'];
    final answer = pingUnknown
        ? {
            'jsonrpc': '2.0',
            'id': id,
            'error': {'code': kGatewayMethodNotFound, 'message': 'unknown'},
          }
        : {'jsonrpc': '2.0', 'id': id, 'result': <String, Object?>{}};
    wire.foreign.sink.add(jsonEncode(answer));
  }

  void send(Object message) => wire.foreign.sink.add(jsonEncode(message));

  void sendRaw(String frame) => wire.foreign.sink.add(frame);
}

Map<String, Object?> _eventFrame(
  String type, {
  String sessionId = 's',
  Map<String, Object?> payload = const {},
}) => {
  'jsonrpc': '2.0',
  'method': 'event',
  'params': {'type': type, 'session_id': sessionId, 'payload': payload},
};

void main() {
  group('heartbeat', () {
    test('Quiet but alive: no event for 30 s, pings answered, stays open', () {
      fakeAsync((async) {
        final wire = StreamChannelController<String>();
        final server = _Server(wire);
        final client = GatewayRpcClient(
          wire.local,
          heartbeat: true,
          pingEvery: const Duration(seconds: 15),
          deadAfter: const Duration(seconds: 45),
        );

        async.elapse(const Duration(seconds: 30));
        expect(client.isClosed, isFalse);
        expect(server.pingCount, 2);

        async.elapse(const Duration(seconds: 60));
        expect(client.isClosed, isFalse);

        unawaited(client.close());
        async.flushMicrotasks();
      });
    });

    test('Ping cadence: a gateway.ping goes out every 15 s', () {
      fakeAsync((async) {
        final wire = StreamChannelController<String>();
        final server = _Server(wire);
        final client = GatewayRpcClient(wire.local, heartbeat: true);

        async.elapse(const Duration(seconds: 14));
        expect(server.pingCount, 0);
        async.elapse(const Duration(seconds: 1));
        expect(server.pingCount, 1);
        async.elapse(const Duration(seconds: 15));
        expect(server.pingCount, 2);

        unawaited(client.close());
        async.flushMicrotasks();
      });
    });

    test(
      'Dead socket: no frame for 45 s closes the client and fails requests',
      () {
        fakeAsync((async) {
          final wire = StreamChannelController<String>();
          final server = _Server(wire, answerPings: false);
          final client = GatewayRpcClient(wire.local, heartbeat: true);

          Object? failure;
          unawaited(
            client
                .request('session.create')
                .then<void>((_) {}, onError: (Object e) => failure = e),
          );

          async.elapse(const Duration(seconds: 44));
          expect(client.isClosed, isFalse);
          expect(failure, isNull);

          async.elapse(const Duration(seconds: 1));
          async.flushMicrotasks();
          expect(client.isClosed, isTrue);
          expect(failure, isA<GatewayConnectionClosed>());
          // The ping due at the deadline's own instant still goes out: the
          // close waits a turn of the event loop for frames in flight.
          expect(server.pingCount, 3);
        });
      },
    );

    test('Dead socket: closing stops the heartbeat and leaves no timers', () {
      fakeAsync((async) {
        final wire = StreamChannelController<String>();
        final server = _Server(wire);
        final client = GatewayRpcClient(wire.local, heartbeat: true);

        unawaited(client.close());
        async.flushMicrotasks();
        final pingsAtClose = server.pingCount;

        async.elapse(const Duration(minutes: 5));
        expect(server.pingCount, pingsAtClose);
        expect(async.pendingTimers, isEmpty);
      });
    });

    test('Gateway without ping: refused pings still count as alive', () {
      fakeAsync((async) {
        final wire = StreamChannelController<String>();
        final server = _Server(wire, pingUnknown: true);
        final client = GatewayRpcClient(wire.local, heartbeat: true);

        async.elapse(const Duration(seconds: 90));
        expect(client.isClosed, isFalse);
        expect(server.pingCount, 6);

        unawaited(client.close());
        async.flushMicrotasks();
      });
    });

    test('An event resets the last-frame clock', () {
      fakeAsync((async) {
        final wire = StreamChannelController<String>();
        final server = _Server(wire, answerPings: false);
        final client = GatewayRpcClient(wire.local, heartbeat: true);

        async.elapse(const Duration(seconds: 30));
        server.send(_eventFrame('message.delta'));
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 44));
        expect(client.isClosed, isFalse);
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(client.isClosed, isTrue);
      });
    });

    test('A reply to a request resets the last-frame clock', () {
      fakeAsync((async) {
        final wire = StreamChannelController<String>();
        final server = _Server(wire, answerPings: false);
        final client = GatewayRpcClient(wire.local, heartbeat: true);

        unawaited(
          client
              .request('session.info')
              .then<void>((_) {}, onError: (Object _) {}),
        );
        async.elapse(const Duration(seconds: 30));
        final id = server.frames.firstWhere(
          (f) => f['method'] == 'session.info',
        )['id'];
        server.send({'jsonrpc': '2.0', 'id': id, 'result': {}});
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 44));
        expect(client.isClosed, isFalse);

        unawaited(client.close());
        async.flushMicrotasks();
      });
    });

    test('A server request resets the last-frame clock', () {
      fakeAsync((async) {
        final wire = StreamChannelController<String>();
        final server = _Server(wire, answerPings: false);
        final client = GatewayRpcClient(wire.local, heartbeat: true);

        async.elapse(const Duration(seconds: 30));
        server.send({
          'jsonrpc': '2.0',
          'id': 'r1',
          'method': 'approval',
          'params': {'session_id': 's'},
        });
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 44));
        expect(client.isClosed, isFalse);

        unawaited(client.close());
        async.flushMicrotasks();
      });
    });

    test('A non-JSON frame resets the last-frame clock', () {
      fakeAsync((async) {
        final wire = StreamChannelController<String>();
        final server = _Server(wire, answerPings: false);
        final client = GatewayRpcClient(wire.local, heartbeat: true);

        async.elapse(const Duration(seconds: 30));
        server.sendRaw('not json at all');
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 44));
        expect(client.isClosed, isFalse);

        unawaited(client.close());
        async.flushMicrotasks();
      });
    });

    test('Heartbeat off: no ping is sent and a silent socket stays open', () {
      fakeAsync((async) {
        final wire = StreamChannelController<String>();
        final server = _Server(wire, answerPings: false);
        final client = GatewayRpcClient(wire.local);

        async.elapse(const Duration(minutes: 5));
        expect(client.isClosed, isFalse);
        expect(server.pingCount, 0);

        unawaited(client.close());
        async.flushMicrotasks();
      });
    });
  });

  group('gateway.ready epoch', () {
    test('Epoch is null until gateway.ready arrives', () {
      fakeAsync((async) {
        final wire = StreamChannelController<String>();
        final server = _Server(wire);
        final client = GatewayRpcClient(wire.local);

        expect(client.epoch, isNull);
        async.flushMicrotasks();
        expect(client.epoch, isNull);

        unawaited(client.close());
        async.flushMicrotasks();
        expect(server.frames, isEmpty);
      });
    });

    test('gateway.ready exposes replay_epoch and is still emitted', () {
      fakeAsync((async) {
        final wire = StreamChannelController<String>();
        final server = _Server(wire);
        final client = GatewayRpcClient(wire.local);
        final types = <String>[];
        final sub = client.events.listen((e) => types.add(e.type));

        server.send(
          _eventFrame('gateway.ready', payload: {'replay_epoch': 'epoch-7'}),
        );
        async.flushMicrotasks();

        expect(client.epoch, 'epoch-7');
        expect(types, ['gateway.ready']);

        unawaited(sub.cancel());
        unawaited(client.close());
        async.flushMicrotasks();
      });
    });
  });

  group('session id from payload', () {
    test('Session-less broadcast takes the payload session_id', () {
      fakeAsync((async) {
        final wire = StreamChannelController<String>();
        final server = _Server(wire);
        final client = GatewayRpcClient(wire.local);
        final received = <GatewayEvent>[];
        final sub = client.events.listen(received.add);

        server.send({
          'jsonrpc': '2.0',
          'method': 'event',
          'params': {
            'type': 'approval.cancelled',
            'session_id': '',
            'payload': {'session_id': 'rt-9'},
          },
        });
        async.flushMicrotasks();

        expect(received.single.sessionId, 'rt-9');

        unawaited(sub.cancel());
        unawaited(client.close());
        async.flushMicrotasks();
      });
    });

    test('Event with its own session_id keeps it', () {
      fakeAsync((async) {
        final wire = StreamChannelController<String>();
        final server = _Server(wire);
        final client = GatewayRpcClient(wire.local);
        final received = <GatewayEvent>[];
        final sub = client.events.listen(received.add);

        server.send({
          'jsonrpc': '2.0',
          'method': 'event',
          'params': {
            'type': 'message.delta',
            'session_id': 'rt-1',
            'payload': {'session_id': 'rt-9'},
          },
        });
        async.flushMicrotasks();

        expect(received.single.sessionId, 'rt-1');

        unawaited(sub.cancel());
        unawaited(client.close());
        async.flushMicrotasks();
      });
    });
  });

  group('heartbeat after a suspend', () {
    test(
      'Dead socket: a frame that was waiting when the deadline fired keeps the '
      'socket open',
      () {
        fakeAsync((async) {
          final wire = StreamChannelController<String>();
          // Pings go unanswered: only the late event is a sign of life.
          final server = _Server(wire, answerPings: false);
          final client = GatewayRpcClient(wire.local, heartbeat: true);
          // Due at the same instant as the deadline but queued behind it, as a
          // frame that arrived while the app was suspended is.
          Timer(const Duration(seconds: 45), () {
            server.send(_eventFrame('message.delta'));
          });

          async.elapse(const Duration(seconds: 45));
          async.flushMicrotasks();

          expect(client.isClosed, isFalse);

          unawaited(client.close());
          async.flushMicrotasks();
        });
      },
    );

    test('Dead socket: a deadline that fired long past due waits for the reads '
        'the OS had not delivered yet', () {
      fakeAsync((async) {
        final start = clock.now();
        var jump = Duration.zero;
        // The wall clock jumps while the app is suspended; timers do not.
        withClock(Clock(() => start.add(async.elapsed + jump)), () {
          final wire = StreamChannelController<String>();
          final server = _Server(wire, answerPings: false);
          final client = GatewayRpcClient(wire.local, heartbeat: true);
          jump = const Duration(minutes: 10);
          Timer(const Duration(seconds: 45, milliseconds: 100), () {
            server.send(_eventFrame('message.delta'));
          });

          async.elapse(const Duration(seconds: 46));
          async.flushMicrotasks();

          expect(client.isClosed, isFalse);

          unawaited(client.close());
          async.flushMicrotasks();
        });
      });
    });
  });
}
