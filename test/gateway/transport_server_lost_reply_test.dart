import 'dart:async';
import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';

import '../support/fake_gateway.dart';

/// What the transport tells a reply when the server no longer has its turn, how
/// long it waits for an answer it cannot get, and what a Stop says when the
/// server has nothing to stop. `prompt.submit` is sent once in every test.
class _Seen {
  final events = <ChatEvent>[];
  Object? error;
  var done = false;
  // ignore: cancel_subscriptions
  late final StreamSubscription<ChatEvent> subscription;
}

_Seen _listen(Stream<ChatEvent> stream) {
  final seen = _Seen();
  seen.subscription = stream.listen(
    seen.events.add,
    onError: (Object error) => seen.error = error,
    onDone: () => seen.done = true,
  );
  return seen;
}

class _FixedRandom implements Random {
  _FixedRandom(this.value);

  final double value;

  @override
  bool nextBool() => value >= 0.5;

  @override
  double nextDouble() => value;

  @override
  int nextInt(int max) => (value * max).floor();
}

/// A turn on `rt-1` that wrote some text and started a tool call, then lost its
/// socket.
void _dropDuringTool(FakeGateway g, String sid) {
  g.event('message.start', sid);
  g.event('message.delta', sid, {'text': 'Starting. '});
  g.event('tool.start', sid, {
    'tool_id': 't1',
    'name': 'terminal',
    'context': 'make',
  });
  g.drop();
}

void main() {
  late FakeGateway gateway;
  late HermesGatewayTransport transport;

  void fake(
    void Function(FakeAsync async) body, {
    Duration quietBound = const Duration(minutes: 20),
  }) => fakeAsync((async) {
    gateway = FakeGateway()
      ..stampSeq = true
      ..sendReady = true
      ..activeSessions = null;
    transport = HermesGatewayTransport(
      connect: gateway.connect,
      random: _FixedRandom(0.5),
      quietBound: quietBound,
    );
    body(async);
  });

  tearDown(() => transport.close());

  int submits() => gateway.methods.where((m) => m == 'prompt.submit').length;
  int resumes() => gateway.methods.where((m) => m == 'session.resume').length;

  group('the server restarted under a reply that was streaming', () {
    test('a resume it refuses as not found says it restarted', () {
      fake((async) {
        gateway.turn = (g, sid) {
          _dropDuringTool(g, sid);
          g.epoch = 'epoch-2';
          g.resumeResult = null;
        };

        final seen = _listen(transport.send(text: 'hi'));
        async.elapse(const Duration(seconds: 5));

        expect(seen.error, isA<GatewaySessionGone>());
        final gone = seen.error! as GatewaySessionGone;
        expect(gone.code, 4007);
        expect(gone.restarted, isTrue);
        expect(submits(), 1);
      });
    });

    test('the same refusal with the same epoch is not a restart', () {
      fake((async) {
        gateway.turn = (g, sid) {
          _dropDuringTool(g, sid);
          g.resumeResult = null;
        };

        final seen = _listen(transport.send(text: 'hi'));
        async.elapse(const Duration(seconds: 5));

        final gone = seen.error! as GatewaySessionGone;
        expect(gone.restarted, isFalse);
        expect(submits(), 1);
      });
    });

    test('a resume that finds the turn over with nothing to show, on a new '
        'epoch, says it restarted', () {
      fake((async) {
        gateway.turn = (g, sid) {
          _dropDuringTool(g, sid);
          g.epoch = 'epoch-2';
          g.resumeResult = {
            'session_id': 'rt-9',
            'running': false,
            'messages': [
              {'role': 'user', 'text': 'hi'},
            ],
          };
        };

        final seen = _listen(transport.send(text: 'hi'));
        async.elapse(const Duration(seconds: 5));

        expect(seen.error, isA<GatewayTurnEnded>());
        expect((seen.error! as GatewayTurnEnded).restarted, isTrue);
        expect(submits(), 1);
      });
    });

    test('the same answer on the same epoch is only a turn that ended', () {
      fake((async) {
        gateway.turn = (g, sid) {
          _dropDuringTool(g, sid);
          g.resumeResult = {
            'session_id': 'rt-9',
            'running': false,
            'messages': [
              {'role': 'user', 'text': 'hi'},
            ],
          };
        };

        final seen = _listen(transport.send(text: 'hi'));
        async.elapse(const Duration(seconds: 5));

        expect(seen.error, isA<GatewayTurnEnded>());
        expect((seen.error! as GatewayTurnEnded).restarted, isFalse);
      });
    });

    test('an epoch change alone does not settle: Hermes re-runs the turn and '
        'its frames go into the same reply', () {
      fake((async) {
        gateway.turn = (g, sid) {
          _dropDuringTool(g, sid);
          g.epoch = 'epoch-2';
          g.resumeResult = {
            'session_id': 'rt-9',
            'running': false,
            'auto_continue': {'attempt': 1, 'interrupted_at': 1.0},
            'messages': [
              {'role': 'user', 'text': 'hi'},
            ],
          };
        };

        final seen = _listen(transport.send(text: 'hi'));
        async.elapse(const Duration(seconds: 5));
        expect(seen.error, isNull);
        expect(seen.done, isFalse);
        final rebuilt = seen.events.whereType<ReplyRebuilt>().single;
        expect(rebuilt.continued, isTrue);

        gateway.event('message.delta', 'rt-9', {'text': 'Again. '});
        gateway.event('message.complete', 'rt-9', {
          'text': 'Again. Done.',
          'status': 'complete',
        });
        async.flushMicrotasks();

        expect(seen.error, isNull);
        expect(seen.events.whereType<ReplyDelta>().last.text, 'Again. ');
        expect(seen.events.last, isA<ReplyCompleted>());
        expect(submits(), 1);
      });
    });

    test('a re-run the pick-up finds goes into the same reply too', () {
      fake((async) {
        gateway.silent.add('session.resume');
        gateway.turn = (g, sid) {
          _dropDuringTool(g, sid);
        };
        final lost = _listen(transport.send(text: 'hi'));
        async.elapse(const Duration(seconds: 61));
        expect(lost.error, isA<GatewayReplyLost>());

        gateway.silent.remove('session.resume');
        gateway.epoch = 'epoch-2';
        gateway.resumeResult = {
          'session_id': 'rt-9',
          'running': false,
          'auto_continue': {'attempt': 1},
          'messages': [
            {'role': 'user', 'text': 'hi'},
          ],
        };
        final follow = _listen(transport.followUps('stored-1'));
        async.flushMicrotasks();

        expect(follow.error, isNull);
        expect(follow.events.first, isA<ReplyStarted>());
        expect(
          follow.events.whereType<ReplyRebuilt>().single.continued,
          isTrue,
        );

        gateway.event('message.complete', 'rt-9', {
          'text': 'Done.',
          'status': 'complete',
        });
        async.flushMicrotasks();
        expect(follow.events.whereType<ReplyCompleted>(), hasLength(1));
        expect(submits(), 1);
        unawaited(follow.subscription.cancel());
      });
    });

    test('a pick-up that finds the session gone after a restart says so', () {
      fake((async) {
        gateway.silent.add('session.resume');
        gateway.turn = (g, sid) => _dropDuringTool(g, sid);
        final lost = _listen(transport.send(text: 'hi'));
        async.elapse(const Duration(seconds: 61));
        expect(lost.error, isA<GatewayReplyLost>());

        gateway.silent.remove('session.resume');
        gateway.epoch = 'epoch-2';
        gateway.resumeResult = null;
        final follow = _listen(transport.followUps('stored-1'));
        async.flushMicrotasks();

        expect(follow.error, isA<GatewaySessionGone>());
        expect((follow.error! as GatewaySessionGone).restarted, isTrue);
        expect(submits(), 1);
      });
    });
  });

  group('a silent reply is never held open by an answer that never comes', () {
    /// A live turn that said something and then went quiet.
    _Seen quietTurn(FakeAsync async) {
      gateway.turn = (g, sid) {
        g.event('message.start', sid);
        g.event('tool.start', sid, {'tool_id': 't1', 'name': 'terminal'});
      };
      final seen = _listen(transport.send(text: 'hi'));
      async.flushMicrotasks();
      return seen;
    }

    int probes() =>
        gateway.methods.where((m) => m == 'session.active_list').length;

    test('probes that are refused four times in a row end it as unconfirmed, '
        'and not before', () {
      fake((async) {
        gateway.handlers['session.active_list'] = (_) =>
            throw const FakeRpcError(5000, 'busy');
        final seen = quietTurn(async);

        async.elapse(const Duration(seconds: 45 * 3));
        expect(probes(), 3);
        expect(seen.error, isNull);

        async.elapse(const Duration(seconds: 45));
        expect(probes(), 4);
        expect(seen.error, isA<GatewayReplyUnconfirmed>());
        expect(seen.error, isA<GatewayConnectionClosed>());
        expect(submits(), 1);
      });
    });

    test('unreadable answers count the same as refusals', () {
      fake((async) {
        gateway.handlers['session.active_list'] = (_) => 'not an object';
        final seen = quietTurn(async);

        async.elapse(const Duration(seconds: 45 * 4));

        expect(seen.error, isA<GatewayReplyUnconfirmed>());
      });
    });

    test('an answer in between starts the count again', () {
      fake((async) {
        final answers = [
          'refuse',
          'refuse',
          'refuse',
          'list',
          'refuse',
          'refuse',
          'refuse',
          'refuse',
        ];
        var asked = 0;
        gateway.handlers['session.active_list'] = (_) {
          final answer = answers[asked++];
          if (answer == 'refuse') throw const FakeRpcError(5000, 'busy');
          return {
            'sessions': [
              {'session_key': 'stored-1', 'status': 'working'},
            ],
          };
        };
        final seen = quietTurn(async);

        async.elapse(const Duration(seconds: 45 * 7));
        expect(asked, 7);
        expect(seen.error, isNull);

        async.elapse(const Duration(seconds: 45));
        expect(asked, 8);
        expect(seen.error, isA<GatewayReplyUnconfirmed>());
      });
    });

    test('a turn the server lists as running that sends no frame for the '
        'bound is unconfirmed', () {
      fake((async) {
        gateway.activeSessions = {'stored-1': 'working'};
        final seen = quietTurn(async);

        // Probes at 45 s steps; the bound is 3 minutes of silence.
        async.elapse(const Duration(seconds: 45 * 3));
        expect(seen.error, isNull);

        async.elapse(const Duration(seconds: 45));
        expect(seen.error, isA<GatewayReplyUnconfirmed>());
        expect(submits(), 1);
      }, quietBound: const Duration(minutes: 3));
    });

    test('a frame starts the silence over', () {
      fake((async) {
        gateway.activeSessions = {'stored-1': 'working'};
        final seen = quietTurn(async);

        async.elapse(const Duration(seconds: 45 * 3));
        gateway.event('message.delta', 'rt-1', {'text': 'x'});
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 45 * 3));

        expect(seen.error, isNull);
      }, quietBound: const Duration(minutes: 3));
    });

    test('a turn no longer listed still ends as a turn that ended', () {
      fake((async) {
        gateway.activeSessions = {};
        final seen = quietTurn(async);

        async.elapse(const Duration(seconds: 45));

        expect(seen.error, isA<GatewayTurnEnded>());
        expect((seen.error! as GatewayTurnEnded).restarted, isFalse);
      });
    });

    test('a turn picked up again that goes quiet after a tool.start is '
        'bounded the same way', () {
      fake((async) {
        gateway.silent.add('session.resume');
        gateway.turn = (g, sid) => _dropDuringTool(g, sid);
        final lost = _listen(transport.send(text: 'hi'));
        async.elapse(const Duration(seconds: 61));
        expect(lost.error, isA<GatewayReplyLost>());

        gateway.silent.remove('session.resume');
        gateway.resumeResult = {'session_id': 'rt-1', 'running': true};
        gateway.handlers['session.active_list'] = (_) =>
            throw const FakeRpcError(5000, 'busy');
        final follow = _listen(transport.followUps('stored-1'));
        async.flushMicrotasks();
        gateway.event('tool.start', 'rt-1', {
          'tool_id': 't2',
          'name': 'terminal',
        });
        async.flushMicrotasks();
        expect(follow.error, isNull);

        async.elapse(const Duration(seconds: 45 * 4));

        expect(follow.error, isA<GatewayReplyUnconfirmed>());
        expect(submits(), 1);
      });
    });
  });

  group('Stop when the server answers that it has nothing to stop', () {
    Future<Object?> stopError(FakeAsync async) {
      final result = Completer<Object?>();
      transport
          .stopReply('stored-1')
          .then(
            (_) => result.complete(null),
            onError: (Object error) => result.complete(error),
          );
      async.flushMicrotasks();
      return result.future;
    }

    test('an interrupt answered 4001 is a session gone, not a failed stop', () {
      fake((async) {
        gateway.turn = (g, sid) => g.event('message.start', sid);
        gateway.handlers['session.interrupt'] = (_) =>
            throw const FakeRpcError(4001, 'session not found');
        final seen = _listen(transport.send(text: 'hi'));
        async.flushMicrotasks();

        Object? error;
        unawaited(stopError(async).then((e) => error = e));
        async.flushMicrotasks();

        expect(error, isA<GatewaySessionGone>());
        expect((error! as GatewaySessionGone).code, 4001);
        expect((error! as GatewaySessionGone).restarted, isFalse);
        unawaited(seen.subscription.cancel());
      });
    });

    test('another answer from the interrupt is still a failed stop', () {
      fake((async) {
        gateway.turn = (g, sid) => g.event('message.start', sid);
        gateway.handlers['session.interrupt'] = (_) =>
            throw const FakeRpcError(5000, 'boom');
        final seen = _listen(transport.send(text: 'hi'));
        async.flushMicrotasks();

        Object? error;
        unawaited(stopError(async).then((e) => error = e));
        async.flushMicrotasks();

        expect(error, isA<GatewayRpcException>());
        expect(error, isNot(isA<GatewaySessionGone>()));
        unawaited(seen.subscription.cancel());
      });
    });

    test('an interrupt nobody answers is a lost connection, not a session '
        'gone', () {
      fake((async) {
        gateway.turn = (g, sid) => g.event('message.start', sid);
        gateway.silent.add('session.interrupt');
        final seen = _listen(transport.send(text: 'hi'));
        async.flushMicrotasks();

        Object? error;
        unawaited(stopError(async).then((e) => error = e));
        async.elapse(const Duration(seconds: 31));

        expect(error, isA<GatewayConnectionClosed>());
        expect(error, isNot(isA<GatewaySessionGone>()));
        unawaited(seen.subscription.cancel());
      });
    });

    test('a reply that lost its connection, stopped after the server '
        'restarted, hears it restarted', () {
      fake((async) {
        gateway.silent.add('session.resume');
        gateway.turn = (g, sid) => _dropDuringTool(g, sid);
        final lost = _listen(transport.send(text: 'hi'));
        async.elapse(const Duration(seconds: 61));
        expect(lost.error, isA<GatewayReplyLost>());

        gateway.silent.remove('session.resume');
        gateway.epoch = 'epoch-2';
        gateway.resumeResult = null;
        Object? error;
        unawaited(stopError(async).then((e) => error = e));
        async.flushMicrotasks();

        expect(error, isA<GatewaySessionGone>());
        expect((error! as GatewaySessionGone).restarted, isTrue);
        expect(gateway.methods, isNot(contains('session.interrupt')));
        expect(submits(), 1);
      });
    });
  });

  group('cancelling ends a reconnect at once', () {
    test('a send cancelled while it waits for the network tries no more', () {
      fake((async) {
        gateway.silent.add('session.resume');
        gateway.turn = (g, sid) => _dropDuringTool(g, sid);
        final seen = _listen(transport.send(text: 'hi'));
        async.elapse(const Duration(seconds: 10));
        final before = resumes();
        expect(before, greaterThan(0));

        unawaited(seen.subscription.cancel());
        async.elapse(const Duration(minutes: 5));
        gateway.silent.remove('session.resume');
        async.elapse(const Duration(minutes: 5));

        expect(resumes(), lessThanOrEqualTo(before + 1));
        expect(submits(), 1);
      });
    });

    test(
      'a pick-up cancelled while its attempt is out opens nothing after',
      () {
        fake((async) {
          gateway.silent.add('session.resume');
          gateway.turn = (g, sid) => _dropDuringTool(g, sid);
          final lost = _listen(transport.send(text: 'hi'));
          async.elapse(const Duration(seconds: 61));
          expect(lost.error, isA<GatewayReplyLost>());

          final follow = _listen(transport.followUps('stored-1'));
          async.elapse(const Duration(seconds: 1));
          unawaited(follow.subscription.cancel());
          gateway.silent.remove('session.resume');
          gateway.resumeResult = {'session_id': 'rt-1', 'running': true};
          final before = resumes();
          async.elapse(const Duration(minutes: 2));

          expect(resumes(), before);
          expect(follow.events, isEmpty);
          expect(submits(), 1);
        });
      },
    );
  });

  group('the reconnect budget of a reply is counted and bounded', () {
    /// A server that resumes the session as running at once and then drops the
    /// socket again, so every reconnect succeeds and none holds.
    void flaky(FakeGateway g) {
      g.resumeResult = {'session_id': 'rt-1', 'running': true};
      // After the answer and the replay call that follows it.
      g.beforeResumeAnswer = (g) {
        Timer(const Duration(milliseconds: 50), g.drop);
      };
    }

    test('a send reconnects exactly five times, then is lost', () {
      fake((async) {
        gateway.turn = (g, sid) {
          g.event('message.start', sid);
          g.drop();
          flaky(g);
        };

        final seen = _listen(transport.send(text: 'hi'));
        async.elapse(const Duration(minutes: 10));

        expect(seen.error, isA<GatewayReplyLost>());
        expect(resumes(), 5);
        expect(submits(), 1);
      });
    });

    test('a followed reply reconnects exactly five times after the pick-up, '
        'then is lost', () {
      fake((async) {
        gateway.silent.add('session.resume');
        gateway.turn = (g, sid) => _dropDuringTool(g, sid);
        final lost = _listen(transport.send(text: 'hi'));
        async.elapse(const Duration(seconds: 61));
        expect(lost.error, isA<GatewayReplyLost>());
        gateway.silent.remove('session.resume');
        flaky(gateway);
        final before = resumes();

        final follow = _listen(transport.followUps('stored-1'));
        async.elapse(const Duration(minutes: 10));

        expect(follow.error, isA<GatewayReplyLost>());
        // The pick-up's own resume, then the five reconnects.
        expect(resumes() - before, 6);
        expect(submits(), 1);
      });
    });

    test('a pick-up makes one attempt and no more', () {
      fake((async) {
        gateway.silent.add('session.resume');
        gateway.turn = (g, sid) => _dropDuringTool(g, sid);
        final lost = _listen(transport.send(text: 'hi'));
        async.elapse(const Duration(seconds: 61));
        expect(lost.error, isA<GatewayReplyLost>());
        gateway.silent.remove('session.resume');
        gateway.handlers['session.resume'] = (_) =>
            throw const FakeRpcError(4007, 'session no longer live; retry');
        final before = resumes();

        final follow = _listen(transport.followUps('stored-1'));
        async.elapse(const Duration(minutes: 2));

        expect(resumes() - before, 1);
        expect(follow.error, isA<GatewayReplyLost>());
        expect(submits(), 1);
      });
    });
  });

  group('replay and parked frames are for the same runtime session only', () {
    test('a reply resumed on another runtime session does not ask for its '
        'old seq, and takes the new session numbering from the start', () {
      fake((async) {
        gateway.turn = (g, sid) {
          g.event('message.start', sid);
          for (var i = 2; i <= 7; i++) {
            g.event('message.delta', sid, {'text': 'old$i '});
          }
          g.drop();
          // The session was reaped: its stored id resumes on a new runtime.
          g.resumeResult = {'session_id': 'rt-9', 'running': true};
        };

        final seen = _listen(transport.send(text: 'hi'));
        async.elapse(const Duration(seconds: 5));
        expect(seen.error, isNull);
        expect(gateway.methods, isNot(contains('session.events.since')));

        // The new runtime counts from 1 again: nothing is dropped as old.
        gateway.event('message.delta', 'rt-9', {'text': 'new1 '});
        gateway.event('message.delta', 'rt-9', {'text': 'new2 '});
        async.flushMicrotasks();

        final deltas = [
          for (final e in seen.events)
            if (e is ReplyDelta) e.text,
        ];
        expect(deltas.skip(6), ['new1 ', 'new2 ']);
        expect(submits(), 1);
        unawaited(seen.subscription.cancel());
      });
    });

    test('a frame of the old runtime session that arrives later is not '
        'shown', () {
      fake((async) {
        gateway.turn = (g, sid) {
          g.event('message.start', sid);
          g.event('message.delta', sid, {'text': 'a '});
          g.drop();
          g.resumeResult = {'session_id': 'rt-9', 'running': true};
        };

        final seen = _listen(transport.send(text: 'hi'));
        async.elapse(const Duration(seconds: 5));
        gateway.event('message.delta', 'rt-1', {'text': 'stale '});
        gateway.event('message.delta', 'rt-9', {'text': 'live '});
        async.flushMicrotasks();

        final deltas = [
          for (final e in seen.events)
            if (e is ReplyDelta) e.text,
        ];
        expect(deltas, contains('live '));
        expect(deltas, isNot(contains('stale ')));
        unawaited(seen.subscription.cancel());
      });
    });

    test('frames parked while the resume is answered are kept for the '
        'runtime session it names only', () {
      fake((async) {
        gateway.turn = (g, sid) {
          g.event('message.start', sid);
          g.event('message.delta', sid, {'text': 'a '});
          g.drop();
          g.resumeResult = {'session_id': 'rt-9', 'running': true};
          g.beforeResumeAnswer = (g) {
            g.event('message.delta', 'rt-1', {'text': 'stale '});
            g.event('message.delta', 'rt-9', {'text': 'live '});
          };
        };

        final seen = _listen(transport.send(text: 'hi'));
        async.elapse(const Duration(seconds: 5));

        final deltas = [
          for (final e in seen.events)
            if (e is ReplyDelta) e.text,
        ];
        expect(deltas, ['a ', 'live ']);
        expect(submits(), 1);
        unawaited(seen.subscription.cancel());
      });
    });

    test(
      'a pick-up on the same runtime session still replays from its seq',
      () {
        fake((async) {
          gateway.silent.add('session.resume');
          gateway.turn = (g, sid) {
            g.event('message.start', sid);
            g.event('message.delta', sid, {'text': '2'});
            g.drop();
          };
          final lost = _listen(transport.send(text: 'hi'));
          async.elapse(const Duration(seconds: 61));
          expect(lost.error, isA<GatewayReplyLost>());

          gateway.silent.remove('session.resume');
          gateway.resumeResult = {'session_id': 'rt-1', 'running': true};
          gateway.beforeEventsAnswer = (g) =>
              g.event('message.delta', 'rt-1', {'text': '3'});
          final follow = _listen(transport.followUps('stored-1'));
          async.flushMicrotasks();

          final since = gateway.requests.where(
            (r) => r['method'] == 'session.events.since',
          );
          expect((since.last['params'] as Map)['last_seen'], 2);
          expect(follow.events.whereType<ReplyDelta>().single.text, '3');
          unawaited(follow.subscription.cancel());
        });
      },
    );
  });
}
