import 'dart:async';
import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';

import '../support/fake_gateway.dart';

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

void main() {
  late FakeGateway gateway;
  late HermesGatewayTransport transport;
  var networkUp = true;
  var connects = 0;
  var stayUp = false;

  /// A reply that streams, then loses its socket with the network down: what
  /// an app finds when it comes back from the background.
  void fake(void Function(FakeAsync async) body) => fakeAsync((async) {
    networkUp = true;
    connects = 0;
    stayUp = false;
    gateway = FakeGateway()
      ..stampSeq = true
      ..sendReady = true
      ..resumeResult = {'session_id': 'rt-1', 'running': true}
      ..turn = (g, sid) {
        g.event('message.start', sid);
        g.event('message.delta', sid, {'text': 'a'});
        if (!stayUp) networkUp = false;
        g.drop();
      };
    transport = HermesGatewayTransport(
      random: _HalfRandom(),
      connect: () async {
        if (connects++ > 0 && !networkUp) throw StateError('network down');
        return gateway.connect();
      },
    );
    body(async);
  });

  tearDown(() => transport.close());

  int count(String method) => gateway.methods.where((m) => m == method).length;

  void expectNeverResubmitted() => expect(count('prompt.submit'), 1);

  void finishReply() => gateway.event('message.complete', 'rt-1', {
    'text': 'done',
    'status': 'complete',
  });

  group('A reply back from the background waits for the network', () {
    test('network down for 99 s, back after the app asked again: the same '
        'reply carries on', () {
      fake((async) {
        final seen = _listen(transport.send(text: 'hi'));
        async.elapse(const Duration(seconds: 50));
        // The app was asleep; coming back to the front asks the connection.
        unawaited(transport.checkConnection());
        async.elapse(const Duration(seconds: 49));
        networkUp = true;
        async.elapse(const Duration(seconds: 20));
        finishReply();
        async.flushMicrotasks();

        expect(seen.error, isNull);
        expect(seen.done, isTrue);
        expect(seen.events.whereType<ReplyCompleted>(), hasLength(1));
        expect(count('session.resume'), 1);
        expectNeverResubmitted();
      });
    });

    test('network that needs 6 s after the resume: the reply carries on', () {
      fake((async) {
        final seen = _listen(transport.send(text: 'hi'));
        async.elapse(const Duration(seconds: 6));
        networkUp = true;
        async.elapse(const Duration(seconds: 10));
        finishReply();
        async.flushMicrotasks();

        expect(seen.error, isNull);
        expect(seen.done, isTrue);
        expect(count('session.resume'), 1);
        expectNeverResubmitted();
      });
    });

    test('a first attempt that fails and a second that works: the reply '
        'carries on', () {
      fake((async) {
        final seen = _listen(transport.send(text: 'hi'));
        async.elapse(const Duration(milliseconds: 100));
        networkUp = true;
        async.elapse(const Duration(seconds: 2));
        finishReply();
        async.flushMicrotasks();

        expect(seen.error, isNull);
        expect(seen.done, isTrue);
        expectNeverResubmitted();
      });
    });

    test('a turn that finished while the app was away: its reply is shown', () {
      fake((async) {
        gateway.resumeResult = {
          'session_id': 'rt-1',
          'running': false,
          'messages': [
            {'role': 'assistant', 'text': 'all done'},
          ],
        };
        final seen = _listen(transport.send(text: 'hi'));
        async.elapse(const Duration(seconds: 3));
        networkUp = true;
        async.elapse(const Duration(seconds: 10));

        expect(seen.error, isNull);
        expect(seen.done, isTrue);
        expect(seen.events.whereType<ReplyCompleted>().single.text, 'all done');
        expectNeverResubmitted();
      });
    });

    test('the first resume is never answered, the second works: the reply '
        'carries on, and the hung call is cut off after 20 s', () {
      fake((async) {
        stayUp = true;
        // The first resume reaches the server and gets no answer.
        gateway.silent.add('session.resume');
        final seen = _listen(transport.send(text: 'hi'));
        async.elapse(const Duration(seconds: 19));
        expect(count('session.resume'), 1);
        expect(seen.error, isNull);

        gateway.silent.remove('session.resume');
        async.elapse(const Duration(seconds: 12));
        finishReply();
        async.flushMicrotasks();

        expect(count('session.resume'), 2);
        expect(seen.error, isNull);
        expect(seen.done, isTrue);
        expectNeverResubmitted();
      });
    });

    test('the app coming to the front while an attempt hangs gives the wait a '
        'new window', () {
      fakeAsync((async) {
        gateway = FakeGateway()
          ..stampSeq = true
          ..sendReady = true
          ..resumeResult = {'session_id': 'rt-1', 'running': true}
          ..turn = (g, sid) {
            g.event('message.start', sid);
            g.drop();
          };
        var opened = 0;
        var up = false;
        transport = HermesGatewayTransport(
          random: _HalfRandom(),
          connect: () async {
            if (opened++ == 0) return gateway.connect();
            if (!up) {
              await Future<void>.delayed(const Duration(seconds: 20));
              throw StateError('network down');
            }
            return gateway.connect();
          },
        );
        final seen = _listen(transport.send(text: 'hi'));
        async.elapse(const Duration(seconds: 55));
        unawaited(transport.checkConnection());
        async.elapse(const Duration(seconds: 6));

        expect(seen.error, isNull);

        async.elapse(const Duration(seconds: 29));
        up = true;
        async.elapse(const Duration(seconds: 20));
        finishReply();
        async.flushMicrotasks();

        expect(seen.error, isNull);
        expect(seen.done, isTrue);
        expectNeverResubmitted();
      });
    });

    test('the app coming to the front cuts a backoff wait short', () {
      fakeAsync((async) {
        gateway = FakeGateway()
          ..stampSeq = true
          ..sendReady = true
          ..turn = (g, sid) {
            g.event('message.start', sid);
            g.drop();
          };
        var opened = 0;
        transport = HermesGatewayTransport(
          random: _HalfRandom(),
          // A wait that only the app coming back can end.
          sleep: (_) => Completer<void>().future,
          connect: () async {
            if (opened++ == 0) return gateway.connect();
            throw StateError('network down');
          },
        );
        _listen(transport.send(text: 'hi'));
        async.flushMicrotasks();
        expect(opened, 2);

        unawaited(transport.checkConnection());
        async.flushMicrotasks();

        expect(opened, 3);
        expectNeverResubmitted();
      });
    });

    test('a network that never returns ends the reply once the window is '
        'spent, still without a second submit', () {
      fake((async) {
        final seen = _listen(transport.send(text: 'hi'));
        async.elapse(const Duration(seconds: 59));
        expect(seen.error, isNull);

        async.elapse(const Duration(seconds: 2));

        expect(seen.error, isA<GatewayConnectionClosed>());
        expect(seen.error, isNot(isA<GatewaySessionGone>()));
        expect(count('session.resume'), 0);
        expectNeverResubmitted();
      });
    });

    test('five attempts the server answered with an error still give up', () {
      fake((async) {
        stayUp = true;
        gateway.handlers['session.resume'] = (_) =>
            throw const FakeRpcError(5000, 'storage');
        final seen = _listen(transport.send(text: 'hi'));
        async.elapse(const Duration(seconds: 120));

        expect(count('session.resume'), 5);
        expect(seen.error, isA<GatewayConnectionClosed>());
        expect(seen.error, isNot(isA<GatewaySessionGone>()));
        expectNeverResubmitted();
      });
    });
  });

  group('A resume that says the session is gone', () {
    test('4007 session not found: one attempt, a typed final failure', () {
      fake((async) {
        stayUp = true;
        gateway.resumeResult = null;
        final seen = _listen(transport.send(text: 'hi'));
        async.elapse(const Duration(seconds: 30));

        expect(count('session.resume'), 1);
        expect(seen.error, isA<GatewaySessionGone>());
        expect((seen.error! as GatewaySessionGone).code, 4007);
        expect(seen.done, isTrue);
        expectNeverResubmitted();
      });
    });

    test('a 4007 that does not say "not found" is retried', () {
      fake((async) {
        stayUp = true;
        var answered = 0;
        gateway.handlers['session.resume'] = (_) {
          if (answered++ == 0) throw const FakeRpcError(4007, 'try again');
          return {'session_id': 'rt-1', 'running': true};
        };
        final seen = _listen(transport.send(text: 'hi'));
        async.elapse(const Duration(seconds: 5));
        finishReply();
        async.flushMicrotasks();

        expect(count('session.resume'), 2);
        expect(seen.error, isNull);
        expectNeverResubmitted();
      });
    });

    test('a follow-up stream whose resume is refused as gone ends with the '
        'typed failure', () {
      fake((async) {
        stayUp = true;
        gateway.turn = (g, sid) {
          g.event('message.start', sid);
          g.event('message.complete', sid, {'text': 'a', 'status': 'complete'});
        };
        _listen(transport.send(text: 'hi'));
        async.flushMicrotasks();
        final follow = _listen(transport.followUps('stored-1'));
        async.flushMicrotasks();
        gateway.event('message.start', 'rt-1');
        async.flushMicrotasks();
        final before = count('session.resume');

        gateway.resumeResult = null;
        gateway.drop();
        async.elapse(const Duration(seconds: 30));

        expect(count('session.resume'), before + 1);
        expect(follow.error, isA<GatewaySessionGone>());
        expectNeverResubmitted();
      });
    });

    test('picking a thread up whose resume is refused as gone makes one '
        'attempt and ends quietly', () {
      fake((async) {
        stayUp = true;
        gateway.resumeResult = null;
        final follow = _listen(transport.followUps('stored-9'));
        async.elapse(const Duration(seconds: 30));

        expect(count('session.resume'), 1);
        expect(follow.done, isTrue);
        expect(follow.error, isNull);
        expect(count('prompt.submit'), 0);
      });
    });

    test('4007 asking for a retry is retried like any transient answer', () {
      fake((async) {
        stayUp = true;
        var answered = 0;
        gateway.handlers['session.resume'] = (_) {
          if (answered++ == 0) {
            throw const FakeRpcError(
              4007,
              'session no longer live; retry resume',
            );
          }
          return {'session_id': 'rt-1', 'running': true};
        };
        final seen = _listen(transport.send(text: 'hi'));
        async.elapse(const Duration(seconds: 5));
        finishReply();
        async.flushMicrotasks();

        expect(count('session.resume'), 2);
        expect(seen.error, isNull);
        expect(seen.done, isTrue);
        expectNeverResubmitted();
      });
    });

    for (final code in [4000, 4006, 4064, 4130, 4132]) {
      test('$code is final too', () {
        fake((async) {
          stayUp = true;
          gateway.handlers['session.resume'] = (_) =>
              throw FakeRpcError(code, 'refused');
          final seen = _listen(transport.send(text: 'hi'));
          async.elapse(const Duration(seconds: 30));

          expect(count('session.resume'), 1);
          expect((seen.error! as GatewaySessionGone).code, code);
          expectNeverResubmitted();
        });
      });
    }

    test('5000 (storage trouble) is retried', () {
      fake((async) {
        stayUp = true;
        var answered = 0;
        gateway.handlers['session.resume'] = (_) {
          if (answered++ == 0) throw const FakeRpcError(5000, 'storage');
          return {'session_id': 'rt-1', 'running': true};
        };
        final seen = _listen(transport.send(text: 'hi'));
        async.elapse(const Duration(seconds: 5));
        finishReply();
        async.flushMicrotasks();

        expect(count('session.resume'), 2);
        expect(seen.error, isNull);
        expectNeverResubmitted();
      });
    });
  });
}
