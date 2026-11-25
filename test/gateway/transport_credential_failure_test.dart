import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/gateway_connection.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/chat/gateway/ticket_mint_gate.dart';

import '../support/fake_gateway.dart';
import '../support/fake_hermes_server.dart';

class _Seen {
  final events = <ChatEvent>[];
  Object? error;
  var done = false;
}

_Seen _listen(Stream<ChatEvent> stream) {
  final seen = _Seen();
  stream.listen(
    seen.events.add,
    onError: (Object error) => seen.error = error,
    onDone: () => seen.done = true,
  );
  return seen;
}

class _HalfRandom implements Random {
  @override
  bool nextBool() => true;

  @override
  double nextDouble() => 0.5;

  @override
  int nextInt(int max) => max ~/ 2;
}

DioException _cancelled() => DioException(
  requestOptions: RequestOptions(path: '/api/auth/ws-ticket'),
  type: DioExceptionType.cancel,
);

void main() {
  late FakeGateway gateway;
  late HermesGatewayTransport transport;
  late FakeHermesServer server;
  late TicketMintGate gate;
  late List<Duration> mintTimes;

  int count(String method) => gateway.methods.where((m) => m == method).length;

  int mints() => server.requestsTo('POST', '/api/auth/ws-ticket').length;

  /// A transport on the real ticket route: [answer] is what that route says.
  void fake(
    void Function(FakeAsync async) body, {
    required FakeResponse Function() answer,
    bool firstMintOk = true,
  }) => fakeAsync((async) {
    mintTimes = [];
    gateway = FakeGateway()
      ..stampSeq = true
      ..sendReady = true
      ..resumeResult = {'session_id': 'rt-1', 'running': true}
      ..turn = (g, sid) {
        g.event('message.start', sid);
        g.event('message.delta', sid, {'text': 'a'});
        g.drop();
      };
    var first = firstMintOk;
    server = FakeHermesServer()
      ..onRequest('POST', '/api/auth/ws-ticket', (_) {
        if (first) {
          first = false;
          return (status: 200, body: {'ticket': 'tkt'});
        }
        mintTimes.add(async.elapsed);
        return answer();
      });
    final api = server.client();
    transport = HermesGatewayTransport(
      random: _HalfRandom(),
      connect: hermesGatewayConnect(
        baseUrl: 'http://hermes.test',
        authRequired: true,
        api: api,
        ticketGate: gate = TicketMintGate(random: _HalfRandom()),
        open: (_) => gateway.connect(),
      ),
    );
    body(async);
  });

  tearDown(() => transport.close());

  group('a reply that lost its socket while the server refuses tickets', () {
    test('asks the server once, then gives up at once instead of trying for '
        'a minute', () {
      fake(answer: () => (status: 401, body: {'detail': 'no'}), (async) {
        final seen = _listen(transport.send(text: 'hi'));
        async.elapse(const Duration(seconds: 120));

        expect(mints(), 2, reason: 'the first connect and one attempt');
        expect(seen.error, isA<GatewayReplyLost>());
        expect(count('prompt.submit'), 1);
      });
    });

    test('and a thread opened later does not mint again before the wait is '
        'over', () {
      fake(answer: () => (status: 401, body: {'detail': 'no'}), (async) {
        _listen(transport.send(text: 'hi'));
        async.elapse(const Duration(seconds: 1));
        final before = mints();

        // The app asks the connection again, a poll fires, a thread opens.
        for (var i = 0; i < 5; i++) {
          unawaited(transport.checkConnection());
          unawaited(transport.activeStatusesAnswered());
          async.elapse(const Duration(seconds: 2));
        }

        expect(mints(), before);
      });
    });

    test('once the wait has run out, a server that accepts again is used '
        'without anyone signing in again', () {
      var accept = false;
      fake(
        answer: () => accept
            ? (status: 200, body: {'ticket': 'tkt-2'})
            : (status: 401, body: {'detail': 'no'}),
        (async) {
          gateway.activeSessions = {};
          _listen(transport.send(text: 'hi'));
          async.elapse(const Duration(seconds: 70));
          accept = true;
          async.elapse(const Duration(minutes: 11));

          Map<String, String>? statuses;
          unawaited(
            transport.activeStatusesAnswered().then(
              (value) => statuses = value,
            ),
          );
          async.elapse(const Duration(seconds: 1));

          expect(statuses, isNotNull);
        },
      );
    });
  });

  group(
    'a reply that lost its socket while the server answers with errors',
    () {
      test('keeps trying, further apart each time', () {
        fake(answer: () => (status: 503, body: {'detail': 'restarting'}), (
          async,
        ) {
          _listen(transport.send(text: 'hi'));
          async.elapse(const Duration(seconds: 70));

          expect(mintTimes.length, greaterThan(2));
          final gaps = [
            for (var i = 1; i < mintTimes.length; i++)
              mintTimes[i] - mintTimes[i - 1],
          ];
          for (var i = 1; i < gaps.length; i++) {
            expect(
              gaps[i],
              greaterThanOrEqualTo(gaps[i - 1]),
              reason: 'gaps: $gaps',
            );
          }
          expect(count('prompt.submit'), 1);
        });
      });
    },
  );

  group('a send meeting a 503 on its ticket', () {
    test('opens again after its short backoff, so one 503 does not end it', () {
      var asked = 0;
      fake(
        firstMintOk: false,
        answer: () => asked++ == 0
            ? (status: 503, body: {'detail': 'restarting'})
            : (status: 200, body: {'ticket': 'tkt'}),
        (async) {
          final seen = _listen(transport.send(text: 'hi'));
          async.elapse(const Duration(seconds: 10));

          expect(seen.error, isNull);
          expect(count('prompt.submit'), 1);
          expect(mints(), greaterThanOrEqualTo(2));
        },
      );
    });

    test('inside a longer wait its opens fail locally, and no request goes '
        'out', () {
      fake(
        firstMintOk: false,
        answer: () => (status: 200, body: {'ticket': 'tkt'}),
        (async) {
          // Five server errors in a row: the wait is now 4.8 s.
          for (var i = 0; i < 5; i++) {
            unawaited(
              gate
                  .run<void>(() async {
                    throw DioException.badResponse(
                      statusCode: 503,
                      requestOptions: RequestOptions(path: '/x'),
                      response: Response<Object?>(
                        requestOptions: RequestOptions(path: '/x'),
                        statusCode: 503,
                      ),
                    );
                  })
                  .then<void>((_) {}, onError: (Object _) {}),
            );
            async.flushMicrotasks();
            if (i < 4) async.elapse(const Duration(seconds: 20));
          }

          final seen = _listen(transport.send(text: 'hi'));
          async.elapse(const Duration(seconds: 2));

          expect(seen.error, isA<GatewayCredentialBackedOff>());
          expect(mints(), 0);
          expect(count('prompt.submit'), 0);
        },
      );
    });
  });

  group('a reply that lost its socket after the session ended', () {
    // The HTTP client cancels every protected request once the session has
    // ended: nothing reaches the server, and nothing is worth retrying.
    test('stops at the first cancelled attempt', () {
      fakeAsync((async) {
        gateway = FakeGateway()
          ..stampSeq = true
          ..sendReady = true
          ..resumeResult = {'session_id': 'rt-1', 'running': true}
          ..turn = (g, sid) {
            g.event('message.start', sid);
            g.event('message.delta', sid, {'text': 'a'});
            g.drop();
          };
        var connects = 0;
        transport = HermesGatewayTransport(
          random: _HalfRandom(),
          connect: () async {
            if (connects++ > 0) throw _cancelled();
            return gateway.connect();
          },
        );

        final seen = _listen(transport.send(text: 'hi'));
        async.elapse(const Duration(seconds: 120));

        expect(connects, 2);
        expect(seen.error, isA<GatewayReplyLost>());
        expect(count('prompt.submit'), 1);
      });
    });

    test('a send whose ticket is cancelled is not retried on a new socket', () {
      fakeAsync((async) {
        gateway = FakeGateway();
        var connects = 0;
        transport = HermesGatewayTransport(
          random: _HalfRandom(),
          connect: () async {
            connects++;
            throw _cancelled();
          },
        );

        final seen = _listen(transport.send(text: 'hi'));
        async.elapse(const Duration(seconds: 120));

        expect(connects, 1);
        expect(seen.error, isA<DioException>());
        expect(count('prompt.submit'), 0);
      });
    });

    test('a send the server refused a ticket for is not retried on a new '
        'socket', () {
      fake(
        firstMintOk: false,
        answer: () => (status: 401, body: {'detail': 'no'}),
        (async) {
          final seen = _listen(transport.send(text: 'hi'));
          // Before a retry would have waited out its first backoff (300 ms).
          async.elapse(const Duration(milliseconds: 100));

          expect(seen.error, isA<DioException>());
          expect(count('prompt.submit'), 0);
        },
      );
    });
  });
}
