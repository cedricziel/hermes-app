import 'dart:async';
import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';

import '../support/fake_gateway.dart';

/// What a stream has delivered so far, readable while fake time runs.
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

/// A [Random] whose draws are fixed, so each backoff delay is known.
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

/// The text of each delta a stream delivered, in order.
List<String> _deltas(_Seen seen) => [
  for (final event in seen.events)
    if (event is ReplyDelta) event.text,
];

/// The runtime types from the first [ReplyRebuilt] on.
List<Type> _fromRebuild(_Seen seen) => [
  for (final event in seen.events.skipWhile((e) => e is! ReplyRebuilt))
    event.runtimeType,
];

/// A turn that streams seqs 1 to 7 (`message.start`, then six deltas whose
/// text is their seq), then drops the socket. [whileDown] records what the
/// server emits while the socket is down.
void _streamSevenThenDrop(
  FakeGateway g,
  String sid,
  void Function(FakeGateway g) whileDown,
) {
  g.event('message.start', sid);
  for (var seq = 2; seq <= 7; seq++) {
    g.event('message.delta', sid, {'text': '$seq'});
  }
  g.drop();
  whileDown(g);
}

void _deltaSeqs(FakeGateway g, String sid, int from, int to) {
  for (var seq = from; seq <= to; seq++) {
    g.event('message.delta', sid, {'text': '$seq'});
  }
}

void main() {
  late FakeGateway gateway;
  late HermesGatewayTransport transport;

  /// Runs [body] under fake time with a fresh gateway and transport. They are
  /// built inside the fake zone, so their stream microtasks run on
  /// `flushMicrotasks`.
  void fake(void Function(FakeAsync async) body) => fakeAsync((async) {
    gateway = FakeGateway()
      ..stampSeq = true
      ..sendReady = true;
    transport = HermesGatewayTransport(
      connect: gateway.connect,
      random: _FixedRandom(0.5),
    );
    body(async);
  });

  tearDown(() => transport.close());

  group('Replay fills the gap', () {
    test(
      'Replay fills the gap: seqs 8 to 12 are delivered once, then the live 13',
      () {
        fake((async) {
          gateway.turn = (g, sid) =>
              _streamSevenThenDrop(g, sid, (g) => _deltaSeqs(g, sid, 8, 12));
          gateway.resumeResult = {'session_id': 'rt-1', 'running': true};

          final seen = _listen(transport.send(text: 'hi'));
          async.flushMicrotasks();
          gateway.event('message.delta', 'rt-1', {'text': '13'});
          gateway.event('message.complete', 'rt-1', {
            'text': 'done',
            'status': 'complete',
          });
          async.flushMicrotasks();

          expect(seen.error, isNull);
          expect(seen.done, isTrue);
          expect(_deltas(seen), [for (var seq = 2; seq <= 13; seq++) '$seq']);
          expect(gateway.requestOf('session.events.since')['params'], {
            'session_id': 'rt-1',
            'last_seen': 7,
          });
        });
      },
    );
  });

  group('Live events overlap the replay', () {
    test('Live events overlap the replay: seqs 11 to 13 sent before the replay answer are not delivered twice', () {
      fake((async) {
        gateway.turn = (g, sid) =>
            _streamSevenThenDrop(g, sid, (g) => _deltaSeqs(g, sid, 8, 10));
        gateway.resumeResult = {'session_id': 'rt-1', 'running': true};
        gateway.beforeEventsAnswer = (g) => _deltaSeqs(g, 'rt-1', 11, 13);

        final seen = _listen(transport.send(text: 'hi'));
        async.flushMicrotasks();
        gateway.event('message.complete', 'rt-1', {
          'text': 'done',
          'status': 'complete',
        });
        async.flushMicrotasks();

        expect(seen.error, isNull);
        expect(_deltas(seen), [for (var seq = 2; seq <= 13; seq++) '$seq']);
        expect(seen.events.last, isA<ReplyCompleted>());
      });
    });
  });

  group('Replay truncated or server restarted', () {
    test('Replay truncated: the resume snapshot rebuilds the reply and live events continue', () {
      fake((async) {
        gateway.truncateReplay = true;
        gateway.resumeResult = {
          'session_id': 'rt-1',
          'running': true,
          'inflight': {'assistant': 'abc'},
        };
        gateway.turn = (g, sid) => _streamSevenThenDrop(g, sid, (_) {});

        final seen = _listen(transport.send(text: 'hi'));
        async.flushMicrotasks();
        gateway.event('message.delta', 'rt-1', {'text': 'd'});
        gateway.event('message.complete', 'rt-1', {
          'text': 'abcd',
          'status': 'complete',
        });
        async.flushMicrotasks();

        expect(seen.error, isNull);
        expect(
          seen.events.whereType<ReplyRebuilt>().map((e) => e.text).toList(),
          ['abc'],
        );
        expect(_fromRebuild(seen), [ReplyRebuilt, ReplyDelta, ReplyCompleted]);
      });
    });

    test('A delta between the resume and the truncated answer is not repeated after the snapshot that holds it', () {
      fake((async) {
        gateway.truncateReplay = true;
        gateway.resumeResult = {
          'session_id': 'rt-1',
          'running': true,
          'inflight': {'assistant': 'abc'},
        };
        gateway.turn = (g, sid) => _streamSevenThenDrop(
          g,
          sid,
          (g) => g.event('message.delta', sid, {'text': 'b'}),
        );
        gateway.beforeResumeAnswer = (g) =>
            g.event('message.delta', 'rt-1', {'text': 'c'});
        gateway.beforeEventsAnswer = (g) =>
            g.event('message.delta', 'rt-1', {'text': 'd'});

        final seen = _listen(transport.send(text: 'hi'));
        async.flushMicrotasks();
        gateway.event('message.complete', 'rt-1', {
          'text': 'abcd',
          'status': 'complete',
        });
        async.flushMicrotasks();

        expect(seen.error, isNull);
        expect(_fromRebuild(seen), [ReplyRebuilt, ReplyDelta, ReplyCompleted]);
        expect(seen.events.whereType<ReplyRebuilt>().single.text, 'abc');
        expect(_deltas(seen).last, 'd');
        expect(_deltas(seen).where((text) => text == 'c'), hasLength(0));
      });
    });

    test('A delta parked before the resume answer is delivered when the snapshot was taken before it', () {
      fake((async) {
        gateway.truncateReplay = true;
        gateway.resumeResult = {
          'session_id': 'rt-1',
          'running': true,
          'inflight': {'assistant': 'ab'},
        };
        gateway.turn = (g, sid) => _streamSevenThenDrop(
          g,
          sid,
          (g) => g.event('message.delta', sid, {'text': 'b'}),
        );
        gateway.beforeResumeAnswer = (g) =>
            g.event('message.delta', 'rt-1', {'text': 'c'});
        gateway.beforeEventsAnswer = (g) =>
            g.event('message.delta', 'rt-1', {'text': 'd'});

        final seen = _listen(transport.send(text: 'hi'));
        async.flushMicrotasks();
        gateway.event('message.complete', 'rt-1', {
          'text': 'abcd',
          'status': 'complete',
        });
        async.flushMicrotasks();

        expect(seen.error, isNull);
        expect(seen.events.whereType<ReplyRebuilt>().single.text, 'ab');
        expect(_fromRebuild(seen), [
          ReplyRebuilt,
          ReplyDelta,
          ReplyDelta,
          ReplyCompleted,
        ]);
        expect(
          seen.events
              .skipWhile((e) => e is! ReplyRebuilt)
              .whereType<ReplyDelta>()
              .map((e) => e.text)
              .toList(),
          ['c', 'd'],
        );
      });
    });

    test(
      'A new epoch on the new socket rebuilds the reply from the snapshot',
      () {
        fake((async) {
          gateway.resumeResult = {
            'session_id': 'rt-1',
            'running': true,
            'inflight': {'assistant': 'abc'},
          };
          gateway.turn = (g, sid) => _streamSevenThenDrop(g, sid, (_) {});
          gateway.beforeResumeAnswer = (g) => g.epoch = 'epoch-2';

          final seen = _listen(transport.send(text: 'hi'));
          async.flushMicrotasks();
          gateway.event('message.delta', 'rt-1', {'text': 'd'});
          gateway.event('message.complete', 'rt-1', {
            'text': 'abcd',
            'status': 'complete',
          });
          async.flushMicrotasks();

          expect(seen.error, isNull);
          expect(seen.events.whereType<ReplyRebuilt>().single.text, 'abc');
          expect(_fromRebuild(seen), [
            ReplyRebuilt,
            ReplyDelta,
            ReplyCompleted,
          ]);
        });
      },
    );

    test('Turn ended while disconnected: the replayed events up to the completion are delivered', () {
      fake((async) {
        gateway.resumeResult = {'session_id': 'rt-1', 'running': false};
        gateway.turn = (g, sid) => _streamSevenThenDrop(g, sid, (g) {
          g.event('message.delta', sid, {'text': '8'});
          g.event('message.complete', sid, {
            'text': 'Done',
            'status': 'complete',
          });
        });

        final seen = _listen(transport.send(text: 'hi'));
        async.flushMicrotasks();

        expect(seen.error, isNull);
        expect(seen.done, isTrue);
        expect(_deltas(seen), [for (var seq = 2; seq <= 8; seq++) '$seq']);
        expect(
          seen.events.last,
          isA<ReplyCompleted>().having((e) => e.text, 'text', 'Done'),
        );
        expect(seen.events.whereType<ThreadNeedsRefetch>(), isEmpty);
      });
    });

    test('Turn ended while disconnected with no completion in the replay: the stored reply, then a refetch', () {
      fake((async) {
        gateway.resumeResult = {
          'session_id': 'rt-1',
          'running': false,
          'messages': [
            {'role': 'user', 'text': 'hi'},
            {'role': 'assistant', 'text': 'Done'},
          ],
        };
        gateway.turn = (g, sid) => _streamSevenThenDrop(g, sid, (_) {});

        final seen = _listen(transport.send(text: 'hi'));
        async.flushMicrotasks();

        expect(seen.error, isNull);
        expect(seen.done, isTrue);
        // The refetch comes before the stored completion, which keeps the
        // completion the last event (see the existing follow-up tests).
        expect(
          seen.events.sublist(seen.events.length - 2).map((e) => e.runtimeType),
          [ThreadNeedsRefetch, ReplyCompleted],
        );
        expect(
          seen.events.last,
          isA<ReplyCompleted>().having((e) => e.text, 'text', 'Done'),
        );
      });
    });
  });

  group('Requests open across the drop', () {
    const approval = {
      'id': 'srq-1',
      'method': 'approval',
      'params': {
        'command': 'ls -la',
        'description': 'List files',
        'choices': ['once', 'deny'],
      },
    };

    test('Requests open across the drop: a request in the resume answer is shown once, keyed by its id', () {
      fake((async) {
        gateway.resumeResult = {
          'session_id': 'rt-1',
          'running': true,
          'open_requests': [approval],
        };
        gateway.turn = (g, sid) => _streamSevenThenDrop(g, sid, (_) {});

        final seen = _listen(transport.send(text: 'hi'));
        async.flushMicrotasks();
        gateway.event('message.complete', 'rt-1', {
          'text': 'done',
          'status': 'complete',
        });
        async.flushMicrotasks();

        expect(seen.error, isNull);
        expect(
          seen.events.whereType<ApprovalRequested>().single.request.requestId,
          'srq-1',
        );
      });
    });

    test(
      'The same id again from session.events.since is not yielded again',
      () {
        fake((async) {
          gateway.resumeResult = {
            'session_id': 'rt-1',
            'running': true,
            'open_requests': [approval],
          };
          gateway.openRequests = [approval];
          gateway.turn = (g, sid) => _streamSevenThenDrop(g, sid, (_) {});

          final seen = _listen(transport.send(text: 'hi'));
          async.flushMicrotasks();
          gateway.event('message.complete', 'rt-1', {
            'text': 'done',
            'status': 'complete',
          });
          async.flushMicrotasks();

          expect(seen.error, isNull);
          expect(
            seen.events
                .whereType<ApprovalRequested>()
                .map((e) => e.request.requestId)
                .toList(),
            ['srq-1'],
          );
        });
      },
    );
  });

  group('Backoff', () {
    test('Backoff: reconnect attempts wait reconnectDelay(attempt), and the reply errors after 5 failed attempts', () {
      fake((async) {
        final attemptsAt = <Duration>[];
        var opened = 0;
        transport = HermesGatewayTransport(
          random: _FixedRandom(0.5),
          connect: () async {
            if (opened++ == 0) return gateway.connect();
            attemptsAt.add(async.elapsed);
            throw StateError('gateway unreachable');
          },
        );
        gateway.turn = (g, sid) => _streamSevenThenDrop(g, sid, (_) {});

        final seen = _listen(transport.send(text: 'hi'));
        async.elapse(const Duration(seconds: 10));

        expect(attemptsAt, const [
          Duration.zero,
          Duration(milliseconds: 300),
          Duration(milliseconds: 900),
          Duration(milliseconds: 2100),
          Duration(milliseconds: 4500),
        ]);
        expect(seen.error, isA<GatewayConnectionClosed>());
      });
    });

    test('Backoff: the waits go through the injected sleep', () {
      fake((async) {
        final waits = <Duration>[];
        var opened = 0;
        transport = HermesGatewayTransport(
          random: _FixedRandom(0.5),
          sleep: (delay) async => waits.add(delay),
          connect: () async {
            if (opened++ == 0) return gateway.connect();
            throw StateError('gateway unreachable');
          },
        );
        gateway.turn = (g, sid) => _streamSevenThenDrop(g, sid, (_) {});

        final seen = _listen(transport.send(text: 'hi'));
        async.flushMicrotasks();

        expect(waits, const [
          Duration(milliseconds: 300),
          Duration(milliseconds: 600),
          Duration(milliseconds: 1200),
          Duration(milliseconds: 2400),
        ]);
        expect(seen.error, isA<GatewayConnectionClosed>());
      });
    });

    test('Backoff: the reply gives up 60 seconds after the drop, however many attempts are left', () {
      fake((async) {
        gateway.silent.add('session.resume');
        gateway.turn = (g, sid) => _streamSevenThenDrop(g, sid, (_) {});

        final seen = _listen(transport.send(text: 'hi'));
        async.elapse(const Duration(seconds: 59));

        expect(seen.error, isNull);

        async.elapse(const Duration(seconds: 1));

        expect(seen.error, isA<GatewayConnectionClosed>());
      });
    });
  });

  group('Answering across a reconnect', () {
    test('an approval answered after a reconnect sends the response frame on the new socket', () {
      fake((async) {
        final first = FakeGateway()
          ..turn = (g, sid) {
            g.event('message.start', sid);
            g.serverRequest('srq-1', 'approval', sid, {'command': 'ls'});
            g.drop();
          };
        final second = FakeGateway()
          ..resumeResult = {'session_id': 'rt-1', 'running': true};
        var opened = 0;
        transport = HermesGatewayTransport(
          connect: () async => (opened++ == 0 ? first : second).channel,
        );

        final seen = _listen(transport.send(text: 'hi'));
        async.flushMicrotasks();

        expect(second.methods, contains('session.resume'));
        expect(
          seen.events.whereType<ApprovalRequested>().single.request.requestId,
          'srq-1',
        );

        bool? answered;
        unawaited(
          transport.answerApproval('srq-1', 'once').then((v) => answered = v),
        );
        async.flushMicrotasks();

        expect(answered, isTrue);
        expect(first.responses, isEmpty);
        expect(second.responses.single['id'], 'srq-1');
        expect(second.responses.single['result'], {'choice': 'once'});

        second.event('message.complete', 'rt-1', {
          'text': 'done',
          'status': 'complete',
        });
        async.flushMicrotasks();
        expect(seen.done, isTrue);
      });
    });
  });
}
