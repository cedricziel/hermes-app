import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/gateway_connection.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/chat/gateway/reconnect_diagnosis.dart';
import 'package:hermes_app/src/telemetry/diagnosis_buckets.dart';

import '../support/fake_gateway.dart';
import '../support/recorded_events.dart';

/// Recognisable text no transport event may carry.
const _prompt = 'SENTINEL_PROMPT_5e1a launch the secret rocket';
const _serverText = 'SENTINEL_SERVER_5e1a.internal.example';

DioException _dio(DioExceptionType type, [int? status]) {
  final options = RequestOptions(path: '/x');
  return DioException(
    requestOptions: options,
    type: type,
    response: status == null
        ? null
        : Response<Object?>(requestOptions: options, statusCode: status),
  );
}

class _Seen {
  final events = <ChatEvent>[];
  Object? error;
}

_Seen _listen(Stream<ChatEvent> stream) {
  final seen = _Seen();
  stream.listen(seen.events.add, onError: (Object error) => seen.error = error);
  return seen;
}

class _FixedRandom implements Random {
  @override
  bool nextBool() => true;

  @override
  double nextDouble() => 0.5;

  @override
  int nextInt(int max) => max ~/ 2;
}

void _streamSevenThenDrop(
  FakeGateway g,
  String sid, [
  void Function(FakeGateway g)? whileDown,
]) {
  g.event('message.start', sid);
  for (var seq = 2; seq <= 7; seq++) {
    g.event('message.delta', sid, {'text': '$seq'});
  }
  g.drop();
  whileDown?.call(g);
}

const _attemptKeys = {
  'attempt',
  'drops',
  'pick_up',
  'stage',
  'result',
  'error_type',
  'close_code',
  'duration',
  'answered',
  'final',
};

/// What the transport says when a reply loses its socket and fights to get it
/// back: how the socket ended, how every reconnect attempt went, and how a
/// lost reply is picked up again. Fixed names, buckets and flags only.
void main() {
  late FakeGateway gateway;
  late RecordedEvents events;
  late HermesGatewayTransport transport;

  void fake(void Function(FakeAsync async) body) => fakeAsync((async) {
    gateway = FakeGateway()
      ..stampSeq = true
      ..sendReady = true;
    events = RecordedEvents();
    transport = HermesGatewayTransport(
      connect: gateway.connect,
      events: events.call,
      random: _FixedRandom(),
    );
    body(async);
  });

  List<Map<String, Object>> attempts() =>
      events.named('gateway.reconnect_attempt');

  group('gateway.socket_closed', () {
    test('a socket the server ended says so, while a reply runs', () {
      fake((async) {
        gateway.resumeResult = {'session_id': 'rt-1', 'running': true};
        gateway.turn = (g, sid) => _streamSevenThenDrop(g, sid);
        _listen(transport.send(text: _prompt));
        async.flushMicrotasks();

        expect(events.named('gateway.socket_closed').first, {
          'reason': 'remote_close',
          'close_code': 'none',
          'lived': 'under_1s',
          'reply_running': true,
        });
      });
    });

    test('the app closing the transport is app_closed', () {
      fake((async) {
        _listen(transport.send(text: _prompt));
        async.flushMicrotasks();
        unawaited(transport.close());
        async.flushMicrotasks();

        expect(
          events.named('gateway.socket_closed').last['reason'],
          'app_closed',
        );
      });
    });
  });

  group('gateway.reconnect_attempt', () {
    test('a replay that fills the gap is one connected, final attempt', () {
      fake((async) {
        gateway.resumeResult = {'session_id': 'rt-1', 'running': true};
        gateway.turn = (g, sid) => _streamSevenThenDrop(g, sid);
        _listen(transport.send(text: _prompt));
        async.flushMicrotasks();

        expect(attempts(), [
          {
            'attempt': 1,
            'drops': 0,
            'pick_up': false,
            'stage': 'done',
            'result': 'connected',
            'error_type': 'none',
            'close_code': 'none',
            'duration': 'under_1s',
            'answered': true,
            'final': true,
          },
        ]);
      });
    });

    test('a gateway that refuses the connection is one attempt each', () {
      fake((async) {
        var opened = 0;
        transport = HermesGatewayTransport(
          events: events.call,
          random: _FixedRandom(),
          connect: () async {
            if (opened++ == 0) return gateway.connect();
            throw SocketException(
              _serverText,
              osError: const OSError('Connection refused', 111),
            );
          },
        );
        gateway.turn = (g, sid) => _streamSevenThenDrop(g, sid);
        final seen = _listen(transport.send(text: _prompt));
        async.elapse(const Duration(seconds: 70));

        expect(seen.error, isA<GatewayConnectionClosed>());
        expect(attempts().length, greaterThan(3));
        for (final attempt in attempts()) {
          expect(attempt['result'], 'refused');
          expect(attempt['error_type'], 'socket');
          expect(attempt['stage'], 'connect');
          expect(attempt['answered'], isFalse);
          expect(attempt['final'], isFalse);
        }
        expect(
          attempts().map((a) => a['attempt']),
          List.generate(attempts().length, (i) => i + 1),
        );
        expect(events.named('gateway.reconnect').single['outcome'], 'failed');
      });
    });

    test('no network is told from a refusal', () {
      fake((async) {
        var opened = 0;
        transport = HermesGatewayTransport(
          events: events.call,
          random: _FixedRandom(),
          connect: () async {
            if (opened++ == 0) return gateway.connect();
            throw SocketException(
              _serverText,
              osError: const OSError('Network is unreachable', 101),
            );
          },
        );
        gateway.turn = (g, sid) => _streamSevenThenDrop(g, sid);
        _listen(transport.send(text: _prompt));
        async.elapse(const Duration(seconds: 5));

        expect(attempts().first['result'], 'no_network');
      });
    });

    test('a resume that hangs is a timeout at the resume step', () {
      fake((async) {
        gateway.silent.add('session.resume');
        gateway.turn = (g, sid) => _streamSevenThenDrop(g, sid);
        _listen(transport.send(text: _prompt));
        async.elapse(const Duration(seconds: 30));

        final first = attempts().first;
        expect(first['result'], 'timeout');
        expect(first['error_type'], 'timeout');
        expect(first['stage'], 'resume');
        expect(first['answered'], isFalse);
        expect(first['duration'], '20_60s');
      });
    });

    test('a session the server lost is resume_gone, final, answered', () {
      fake((async) {
        gateway.resumeResult = null;
        gateway.turn = (g, sid) => _streamSevenThenDrop(g, sid);
        _listen(transport.send(text: _prompt));
        async.elapse(const Duration(seconds: 30));

        expect(attempts().single, {
          'attempt': 1,
          'drops': 0,
          'pick_up': false,
          'stage': 'done',
          'result': 'resume_gone',
          'error_type': 'rpc',
          'close_code': 'none',
          'duration': 'under_1s',
          'answered': true,
          'final': true,
        });
      });
    });

    test('a busy gateway (4009) is told apart and retried', () {
      fake((async) {
        gateway.turn = (g, sid) => _streamSevenThenDrop(g, sid, (g) {
          g.sessionErrorCode = 4009;
        });
        _listen(transport.send(text: _prompt));
        async.elapse(const Duration(seconds: 10));

        expect(attempts().length, greaterThan(1));
        expect(attempts().first['result'], 'busy');
        expect(attempts().first['error_type'], 'rpc');
        expect(attempts().first['answered'], isTrue);
        expect(attempts().first['final'], isFalse);
      });
    });

    test('every attempt has exactly the fixed attributes and values', () {
      fake((async) {
        gateway.silent.add('session.resume');
        gateway.turn = (g, sid) => _streamSevenThenDrop(g, sid);
        _listen(transport.send(text: _prompt));
        async.elapse(const Duration(seconds: 70));

        expect(attempts(), isNotEmpty);
        for (final attempt in attempts()) {
          expect(attempt.keys.toSet(), _attemptKeys);
          expect(kReconnectResults, contains(attempt['result']));
          expect(kReconnectErrorTypes, contains(attempt['error_type']));
          expect(kCloseCodeBuckets, contains(attempt['close_code']));
          expect(kDurationBuckets, contains(attempt['duration']));
          expect(attempt['attempt'], isA<int>());
          expect(attempt['answered'], isA<bool>());
        }
      });
    });

    test('prompt.submit is never resent by a reconnect', () {
      fake((async) {
        gateway.silent.add('session.resume');
        gateway.turn = (g, sid) => _streamSevenThenDrop(g, sid);
        _listen(transport.send(text: _prompt));
        async.elapse(const Duration(seconds: 70));

        expect(
          gateway.methods.where((m) => m == 'prompt.submit'),
          hasLength(1),
        );
      });
    });
  });

  group('gateway.reattach', () {
    void lose(FakeAsync async) {
      gateway.silent.add('session.resume');
      gateway.turn = (g, sid) => _streamSevenThenDrop(g, sid);
      final seen = _listen(transport.send(text: _prompt));
      async.elapse(const Duration(seconds: 61));
      expect(seen.error, isA<GatewayReplyLost>());
    }

    test('the same reply still running is same_reply', () {
      fake((async) {
        lose(async);
        gateway.silent.remove('session.resume');
        gateway.resumeResult = {'session_id': 'rt-1', 'running': true};
        final follow = _listen(transport.followUps('stored-1'));
        async.flushMicrotasks();

        expect(events.named('gateway.reattach'), [
          {'outcome': 'same_reply', 'refetch': false, 'replayed_count': 0},
        ]);
        expect(follow.error, isNull);
      });
    });

    test('a turn that finished meanwhile is finished_while_away', () {
      fake((async) {
        lose(async);
        gateway.silent.remove('session.resume');
        gateway.resumeResult = {'session_id': 'rt-1', 'running': false};
        gateway.beforeEventsAnswer = (g) {
          g.event('message.complete', 'rt-1', {
            'text': 'Done.',
            'status': 'complete',
          });
        };
        _listen(transport.followUps('stored-1'));
        async.flushMicrotasks();

        expect(
          events.named('gateway.reattach').single['outcome'],
          'finished_while_away',
        );
      });
    });

    test('a session the server no longer has is gone', () {
      fake((async) {
        lose(async);
        gateway.silent.remove('session.resume');
        gateway.resumeResult = null;
        _listen(transport.followUps('stored-1'));
        async.flushMicrotasks();

        expect(events.named('gateway.reattach').single['outcome'], 'gone');
      });
    });

    test('a server out of reach is unreachable', () {
      fake((async) {
        lose(async);
        _listen(transport.followUps('stored-1'));
        async.elapse(const Duration(seconds: 30));

        expect(
          events.named('gateway.reattach').single['outcome'],
          'unreachable',
        );
      });
    });

    test('a turn that ended with nothing to show is told apart', () {
      fake((async) {
        lose(async);
        gateway.silent.remove('session.resume');
        gateway.resumeResult = {'session_id': 'rt-1', 'running': false};
        _listen(transport.followUps('stored-1'));
        async.flushMicrotasks();

        expect(
          events.named('gateway.reattach').single['outcome'],
          'finished_no_reply',
        );
      });
    });

    test('a refetch the pick-up asks for is flagged, even on a live reply', () {
      fake((async) {
        lose(async);
        gateway.silent.remove('session.resume');
        gateway.truncateReplay = true;
        gateway.resumeResult = {'session_id': 'rt-1', 'running': true};
        _listen(transport.followUps('stored-1'));
        async.flushMicrotasks();

        expect(events.named('gateway.reattach').single, {
          'outcome': 'same_reply',
          'refetch': true,
          'replayed_count': 0,
        });
      });
    });

    test('a snapshot that rebuilds the reply asks for no refetch', () {
      fake((async) {
        lose(async);
        gateway.silent.remove('session.resume');
        gateway.truncateReplay = true;
        gateway.resumeResult = {
          'session_id': 'rt-1',
          'running': true,
          'inflight': {'assistant': 'abc'},
        };
        _listen(transport.followUps('stored-1'));
        async.flushMicrotasks();

        expect(events.named('gateway.reattach').single['refetch'], isFalse);
      });
    });

    test('a thread that lost no reply logs no reattach', () {
      fake((async) {
        gateway.resumeResult = {'session_id': 'rt-9', 'running': false};
        _listen(transport.followUps('stored-other'));
        async.flushMicrotasks();

        expect(events.named('gateway.reattach'), isEmpty);
      });
    });
  });

  group('privacy and robustness', () {
    test('no transport event carries the prompt or what the server said', () {
      fake((async) {
        var opened = 0;
        transport = HermesGatewayTransport(
          events: events.call,
          random: _FixedRandom(),
          connect: () async {
            if (opened++ == 0) return gateway.connect();
            throw SocketException(
              _serverText,
              osError: OSError(_serverText, 111),
            );
          },
        );
        gateway.turn = (g, sid) => _streamSevenThenDrop(g, sid);
        _listen(transport.send(text: _prompt, threadId: 'stored-$_serverText'));
        async.elapse(const Duration(seconds: 70));
        unawaited(transport.close());
        async.flushMicrotasks();

        final all = [
          ...events.named('gateway.socket_closed'),
          ...attempts(),
          ...events.named('gateway.reattach'),
          ...events.named('gateway.reconnect'),
        ];
        expect(all, isNotEmpty);
        for (final attributes in all) {
          for (final entry in attributes.entries) {
            final text = '${entry.key} ${entry.value}';
            expect(text, isNot(contains('SENTINEL')));
            expect(text, isNot(contains('example')));
            expect(text, isNot(contains('rt-')));
          }
        }
      });
    });

    test('a logger that throws does not break the send', () {
      fakeAsync((async) {
        gateway = FakeGateway()
          ..stampSeq = true
          ..sendReady = true;
        transport = HermesGatewayTransport(
          connect: gateway.connect,
          events: (name, [attributes = const {}]) =>
              throw StateError('exporter down'),
          random: _FixedRandom(),
        );
        gateway.resumeResult = {'session_id': 'rt-1', 'running': true};
        gateway.turn = (g, sid) => _streamSevenThenDrop(g, sid, (g) {
          g.event('message.complete', sid, {
            'text': 'Done.',
            'status': 'complete',
          });
        });
        final seen = _listen(transport.send(text: _prompt));
        async.elapse(const Duration(seconds: 5));

        expect(seen.error, isNull);
        expect(
          gateway.methods.where((m) => m == 'prompt.submit'),
          hasLength(1),
        );
      });
    });
  });

  group('classification', () {
    test('every failure sorts into fixed names, never its message', () {
      final cases = <Object?, (String, String)>{
        const GatewayCallTimedOut(): ('timeout', 'timeout'),
        TimeoutException(_serverText): ('timeout', 'timeout'),
        const GatewayConnectionClosed(): ('closed', 'closed'),
        const GatewayCredentialUnavailable(): ('credential', 'credential'),
        const GatewayRpcException(4009, _serverText): ('busy', 'rpc'),
        const GatewayRpcException(5000, _serverText): ('rejected', 'rpc'),
        SocketException(_serverText, osError: const OSError('x', 111)): (
          'refused',
          'socket',
        ),
        SocketException(_serverText, osError: const OSError('x', 101)): (
          'no_network',
          'socket',
        ),
        const HandshakeException(_serverText): ('refused', 'tls'),
        StateError(_serverText): ('other', 'other'),
        _dio(DioExceptionType.badResponse, 401): ('credential', 'http'),
        _dio(DioExceptionType.badResponse, 403): ('credential', 'http'),
        _dio(DioExceptionType.badResponse, 502): ('http_error', 'http'),
        _dio(DioExceptionType.badResponse): ('http_error', 'http'),
        _dio(DioExceptionType.badCertificate): ('bad_certificate', 'tls'),
        _dio(DioExceptionType.cancel): ('cancelled', 'cancelled'),
        _dio(DioExceptionType.unknown): ('other', 'other'),
        _dio(DioExceptionType.connectionError): ('no_network', 'http'),
        _dio(DioExceptionType.receiveTimeout): ('timeout', 'timeout'),
      };
      for (final entry in cases.entries) {
        final got = diagnoseReconnectError(entry.key);
        expect((got.result, got.errorType), entry.value, reason: '$entry');
        expect(kReconnectResults, contains(got.result));
        expect(kReconnectErrorTypes, contains(got.errorType));
      }
    });
  });
}
