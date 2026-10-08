import 'dart:async';
import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_reply.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';

import '../support/fake_gateway.dart';

/// What a stream has delivered so far, readable while fake time runs.
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

    test('A restart that changes the epoch before the new socket is ready rebuilds '
        'the reply from the snapshot and drops the stale ring', () {
      fake((async) {
        gateway.resumeResult = {
          'session_id': 'rt-1',
          'running': true,
          'inflight': {'assistant': 'abc'},
        };
        gateway.turn = (g, sid) => _streamSevenThenDrop(g, sid, (g) {
          g.epoch = 'epoch-2';
          _deltaSeqs(g, sid, 8, 9);
        });

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
        expect(_fromRebuild(seen), [ReplyRebuilt, ReplyDelta, ReplyCompleted]);
        expect(
          seen.events
              .skipWhile((e) => e is! ReplyRebuilt)
              .whereType<ReplyDelta>()
              .map((e) => e.text),
          ['d'],
        );
      });
    });

    test('An older gateway without session.events.since: a running turn '
        'carries on from the snapshot', () {
      fake((async) {
        gateway.unknownMethods.add('session.events.since');
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
        expect(seen.done, isTrue);
        expect(_fromRebuild(seen), [ReplyRebuilt, ReplyDelta, ReplyCompleted]);
      });
    });

    test('An older gateway without session.events.since: an ended turn ends '
        'with the stored reply', () {
      fake((async) {
        gateway.unknownMethods.add('session.events.since');
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
        expect(
          seen.events.sublist(seen.events.length - 2).map((e) => e.runtimeType),
          [ThreadNeedsRefetch, ReplyCompleted],
        );
      });
    });

    test('No watermark: a ring this app never saw is not replayed over the '
        'snapshot', () {
      fake((async) {
        gateway.resumeResult = {
          'session_id': 'rt-1',
          'running': true,
          'inflight': {'assistant': '123'},
        };
        // Everything the turn said went out while the socket was down, so
        // this app holds no seq for the session.
        gateway.turn = (g, sid) {
          g.drop();
          _deltaSeqs(g, sid, 1, 3);
        };

        final seen = _listen(transport.send(text: 'hi'));
        async.flushMicrotasks();
        gateway.event('message.delta', 'rt-1', {'text': '4'});
        gateway.event('message.complete', 'rt-1', {
          'text': '1234',
          'status': 'complete',
        });
        async.flushMicrotasks();

        expect(seen.error, isNull);
        expect(gateway.methods, isNot(contains('session.events.since')));
        expect(seen.events.whereType<ReplyRebuilt>().single.text, '123');
        expect(_deltas(seen), ['4']);
      });
    });

    test('Frames without a seq: the reconnect rebuilds from the snapshot and '
        'shows each live delta once', () {
      fake((async) {
        gateway.stampSeq = false;
        gateway.resumeResult = {
          'session_id': 'rt-1',
          'running': true,
          'inflight': {'assistant': 'abc'},
        };
        gateway.turn = (g, sid) {
          g.event('message.start', sid);
          g.event('message.delta', sid, {'text': 'a'});
          g.drop();
        };

        final seen = _listen(transport.send(text: 'hi'));
        async.flushMicrotasks();
        gateway.event('message.delta', 'rt-1', {'text': 'd'});
        gateway.event('message.complete', 'rt-1', {
          'text': 'abcd',
          'status': 'complete',
        });
        async.flushMicrotasks();

        expect(seen.error, isNull);
        expect(gateway.methods, isNot(contains('session.events.since')));
        expect(_fromRebuild(seen), [ReplyRebuilt, ReplyDelta, ReplyCompleted]);
        expect(_deltas(seen), ['a', 'd']);
      });
    });

    test('A delta that is only whitespace is delivered even when the snapshot '
        'ends with whitespace', () {
      fake((async) {
        gateway.truncateReplay = true;
        gateway.resumeResult = {
          'session_id': 'rt-1',
          'running': true,
          'inflight': {'assistant': 'ab '},
        };
        gateway.turn = (g, sid) => _streamSevenThenDrop(g, sid, (_) {});
        gateway.beforeResumeAnswer = (g) =>
            g.event('message.delta', 'rt-1', {'text': ' '});

        final seen = _listen(transport.send(text: 'hi'));
        async.flushMicrotasks();
        gateway.event('message.complete', 'rt-1', {
          'text': 'ab  ',
          'status': 'complete',
        });
        async.flushMicrotasks();

        expect(seen.error, isNull);
        expect(
          seen.events
              .skipWhile((e) => e is! ReplyRebuilt)
              .whereType<ReplyDelta>()
              .map((e) => e.text),
          [' '],
        );
      });
    });

    test('Of two identical short deltas parked ahead of the snapshot only the '
        'first can be dropped', () {
      fake((async) {
        gateway.truncateReplay = true;
        gateway.resumeResult = {
          'session_id': 'rt-1',
          'running': true,
          'inflight': {'assistant': 'abb'},
        };
        gateway.turn = (g, sid) => _streamSevenThenDrop(g, sid, (_) {});
        gateway.beforeResumeAnswer = (g) {
          g.event('message.delta', 'rt-1', {'text': 'b'});
          g.event('message.delta', 'rt-1', {'text': 'b'});
        };

        final seen = _listen(transport.send(text: 'hi'));
        async.flushMicrotasks();
        gateway.event('message.complete', 'rt-1', {
          'text': 'abbb',
          'status': 'complete',
        });
        async.flushMicrotasks();

        expect(
          seen.events
              .skipWhile((e) => e is! ReplyRebuilt)
              .whereType<ReplyDelta>()
              .map((e) => e.text),
          ['b'],
        );
      });
    });

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

    test('Turn ended while disconnected with no completion in the replay: a refetch, then the stored reply', () {
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

  group('Two watches on one runtime session', () {
    test('each gets every live event, not half of them', () {
      fake((async) {
        gateway.resumeResult = {'session_id': 'rt-1', 'running': true};
        gateway.turn = (g, sid) => g.event('message.start', sid);

        final replying = _listen(transport.send(text: 'hi'));
        async.flushMicrotasks();
        final following = _listen(transport.followUps('stored-1'));
        async.flushMicrotasks();
        _deltaSeqs(gateway, 'rt-1', 2, 4);
        async.flushMicrotasks();

        expect(_deltas(replying), ['2', '3', '4']);
        expect(_deltas(following), ['2', '3', '4']);
      });
    });
  });

  group('Gaps the replay cannot fill', () {
    test('a truncated replay with no snapshot reads the thread again and '
        'carries on live', () {
      fake((async) {
        gateway.truncateReplay = true;
        gateway.resumeResult = {'session_id': 'rt-1', 'running': true};
        gateway.turn = (g, sid) => _streamSevenThenDrop(g, sid, (_) {});

        final seen = _listen(transport.send(text: 'hi'));
        async.flushMicrotasks();
        gateway.event('message.delta', 'rt-1', {'text': 'z'});
        gateway.event('message.complete', 'rt-1', {
          'text': 'z',
          'status': 'complete',
        });
        async.flushMicrotasks();

        expect(seen.error, isNull);
        expect(
          seen.events
              .skipWhile((e) => e is! ThreadNeedsRefetch)
              .map((e) => e.runtimeType),
          [ThreadNeedsRefetch, ReplyDelta, ReplyCompleted],
        );
      });
    });

    test('a changed epoch with no snapshot reads the thread again', () {
      fake((async) {
        gateway.resumeResult = {'session_id': 'rt-1', 'running': true};
        gateway.turn = (g, sid) =>
            _streamSevenThenDrop(g, sid, (g) => g.epoch = 'epoch-2');

        final seen = _listen(transport.send(text: 'hi'));
        async.flushMicrotasks();

        expect(seen.events.whereType<ThreadNeedsRefetch>(), hasLength(1));
      });
    });

    test('an error in the replay of an ended turn with no stored reply is '
        'what the reply fails with', () {
      fake((async) {
        gateway.resumeResult = {'session_id': 'rt-1', 'running': false};
        gateway.turn = (g, sid) => _streamSevenThenDrop(g, sid, (g) {
          g.event('error', sid, {'message': 'The model is overloaded.'});
        });

        final seen = _listen(transport.send(text: 'hi'));
        async.flushMicrotasks();

        expect(seen.error, isNull);
        expect(seen.done, isTrue);
        expect(
          seen.events.whereType<ReplyErrored>().single.message,
          'The model is overloaded.',
        );
        final reply = ChatMessage(
          id: 'r',
          role: ChatRole.assistant,
          content: '',
          createdAt: DateTime(2026),
          status: MessageStatus.thinking,
        );
        for (final event in seen.events) {
          applyReplyEvent(reply, event);
        }
        expect(reply.status, MessageStatus.error);
        expect(reply.error, 'The model is overloaded.');
      });
    });

    test('a turn that ended while disconnected leaves the session listened '
        'to, so the next turn Hermes chains is followed', () {
      fake((async) {
        gateway.resumeResult = {'session_id': 'rt-1', 'running': false};
        gateway.turn = (g, sid) => _streamSevenThenDrop(g, sid, (g) {
          g.event('message.complete', sid, {
            'text': 'Done',
            'status': 'complete',
          });
        });

        final seen = _listen(transport.send(text: 'hi'));
        async.flushMicrotasks();
        expect(seen.done, isTrue);

        final follow = _listen(transport.followUps('stored-1'));
        async.flushMicrotasks();
        gateway.event('message.start', 'rt-1');
        gateway.event('message.delta', 'rt-1', {'text': 'again'});
        async.flushMicrotasks();

        expect(follow.events.map((e) => e.runtimeType), [
          ReplyStarted,
          ReplyDelta,
        ]);
        // Only the reconnect resumed: the follow-up read the parked watch.
        expect(
          gateway.methods.where((m) => m == 'session.resume'),
          hasLength(1),
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

  group('Server requests across the drop', () {
    final request = {
      'command': 'ls -la',
      'choices': ['once', 'deny'],
    };

    test('a request parked on the new socket keeps its place among the '
        'replayed events', () {
      fake((async) {
        gateway.resumeResult = {'session_id': 'rt-1', 'running': true};
        gateway.turn = (g, sid) =>
            _streamSevenThenDrop(g, sid, (g) => _deltaSeqs(g, sid, 8, 9));
        gateway.beforeEventsAnswer = (g) {
          _deltaSeqs(g, 'rt-1', 10, 10);
          g.serverRequest('srq-1', 'approval', 'rt-1', request);
          _deltaSeqs(g, 'rt-1', 11, 11);
        };

        final seen = _listen(transport.send(text: 'hi'));
        async.flushMicrotasks();

        expect(
          seen.events
              .skipWhile((e) => !(e is ReplyDelta && e.text == '8'))
              .map((e) => e is ReplyDelta ? e.text : e.runtimeType.toString()),
          ['8', '9', '10', 'ApprovalRequested', '11'],
        );
      });
    });

    test('a request shown before the reconnect and sent again by the new '
        'socket is shown once', () {
      fake((async) {
        gateway.resumeResult = {
          'session_id': 'rt-1',
          'running': true,
          'open_requests': [
            {'id': 'srq-1', 'method': 'approval', 'params': request},
          ],
        };
        gateway.turn = (g, sid) => _streamSevenThenDrop(g, sid, (_) {});

        final seen = _listen(transport.send(text: 'hi'));
        async.flushMicrotasks();
        gateway.serverRequest('srq-1', 'approval', 'rt-1', request);
        async.flushMicrotasks();

        expect(seen.events.whereType<ApprovalRequested>(), hasLength(1));
      });
    });
  });

  group('Open requests after the events', () {
    const approval = {
      'id': 'srq-1',
      'method': 'approval',
      'params': {'command': 'ls', 'tool_name': 'terminal'},
    };

    ChatMessage placeholder() => ChatMessage(
      id: 'r',
      role: ChatRole.assistant,
      content: '',
      createdAt: DateTime(2026),
      status: MessageStatus.thinking,
    );

    test('a request raised during the outage binds to the tool call the '
        'replay starts', () {
      fake((async) {
        gateway.resumeResult = {
          'session_id': 'rt-1',
          'running': true,
          'open_requests': [approval],
        };
        gateway.turn = (g, sid) => _streamSevenThenDrop(g, sid, (g) {
          g.event('tool.start', sid, {'tool_id': 't1', 'name': 'terminal'});
        });

        final seen = _listen(transport.send(text: 'hi'));
        async.flushMicrotasks();
        final reply = placeholder();
        for (final event in seen.events) {
          applyReplyEvent(reply, event);
        }

        final request = reply.inputRequests.single as ApprovalRequest;
        expect(request.requestId, 'srq-1');
        expect(request.toolCallIndex, 0);
      });
    });

    test('an ended turn shows its open request after the replayed events', () {
      fake((async) {
        gateway.resumeResult = {
          'session_id': 'rt-1',
          'running': false,
          'open_requests': [approval],
          'messages': [
            {'role': 'assistant', 'text': 'Done'},
          ],
        };
        gateway.turn = (g, sid) => _streamSevenThenDrop(g, sid, (g) {
          g.event('tool.start', sid, {'tool_id': 't1', 'name': 'terminal'});
        });

        final seen = _listen(transport.send(text: 'hi'));
        async.flushMicrotasks();

        final types = seen.events.map((e) => e.runtimeType).toList();
        expect(
          types.indexOf(ToolStarted),
          lessThan(types.indexOf(ApprovalRequested)),
        );
      });
    });
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

  group('A reply reconnecting more than once', () {
    test('the silence probe asks the connection the reply is on now', () {
      fake((async) {
        final first = FakeGateway()
          ..turn = (g, sid) {
            g.event('message.start', sid);
            g.drop();
          };
        final second = FakeGateway()
          ..resumeResult = {'session_id': 'rt-1', 'running': true}
          ..activeSessions = {};
        var opened = 0;
        transport = HermesGatewayTransport(
          connect: () async => (opened++ == 0 ? first : second).channel,
          random: _FixedRandom(0.5),
        );

        final seen = _listen(transport.send(text: 'hi'));
        async.flushMicrotasks();
        expect(seen.error, isNull);

        async.elapse(const Duration(seconds: 46));

        expect(second.methods, contains('session.active_list'));
        expect(seen.error, isA<GatewayConnectionClosed>());
      });
    });

    test('a socket that keeps dropping gives up after 5 reconnects', () {
      fake((async) {
        gateway.resumeResult = {'session_id': 'rt-1', 'running': true};
        gateway.turn = (g, sid) => _streamSevenThenDrop(g, sid, (_) {});
        int resumes() =>
            gateway.methods.where((m) => m == 'session.resume').length;

        final seen = _listen(transport.send(text: 'hi'));
        async.elapse(const Duration(seconds: 10));
        for (var again = 2; again <= 5; again++) {
          expect(resumes(), again - 1);
          gateway.drop();
          async.elapse(const Duration(seconds: 10));
        }

        expect(seen.error, isNull);
        expect(resumes(), 5);

        gateway.drop();
        async.elapse(const Duration(seconds: 10));

        expect(seen.error, isA<GatewayConnectionClosed>());
        expect(resumes(), 5);
      });
    });

    test('a reconnect abandoned at the budget does not move the watermark', () {
      fake((async) {
        transport = HermesGatewayTransport(
          connect: gateway.connect,
          random: _FixedRandom(0.5),
          requestTimeout: const Duration(minutes: 10),
        );
        gateway.resumeResult = {'session_id': 'rt-1', 'running': true};
        gateway.turn = (g, sid) => _streamSevenThenDrop(g, sid, (_) {});
        final hold = gateway.holdEventsAnswer = Completer<void>();

        final first = _listen(transport.send(text: 'hi'));
        async.elapse(const Duration(seconds: 61));
        expect(first.error, isA<GatewayConnectionClosed>());

        // The abandoned attempt gets its answer late, with events 8 and 9.
        _deltaSeqs(gateway, 'rt-1', 8, 9);
        hold.complete();
        async.flushMicrotasks();

        gateway.holdEventsAnswer = null;
        gateway.turn = (g, sid) => g.drop();
        final again = _listen(
          transport.send(threadId: 'stored-1', text: 'again'),
        );
        async.elapse(const Duration(seconds: 10));

        final since = gateway.requests.where(
          (r) => r['method'] == 'session.events.since',
        );
        expect((since.last['params'] as Map)['last_seen'], 7);
        expect(_deltas(again), ['8', '9']);
      });
    });
  });

  group('Following a thread across a reconnect', () {
    /// A reply that completed, so its session stays listened to.
    void finishedReply(FakeGateway g, String sid) {
      g.event('message.start', sid);
      g.event('message.delta', sid, {'text': 'a'});
      g.event('message.complete', sid, {'text': 'a', 'status': 'complete'});
    }

    test('a chained turn that drops mid-way is replayed and carried on', () {
      fake((async) {
        gateway.resumeResult = {'session_id': 'rt-1', 'running': true};
        gateway.turn = finishedReply;
        final reply = _listen(transport.send(text: 'hi'));
        async.flushMicrotasks();
        expect(reply.done, isTrue);

        final follow = _listen(transport.followUps('stored-1'));
        async.flushMicrotasks();
        gateway.event('message.start', 'rt-1');
        gateway.event('message.delta', 'rt-1', {'text': 'b'});
        async.flushMicrotasks();
        gateway.drop();
        _deltaSeqs(gateway, 'rt-1', 6, 7);
        async.elapse(const Duration(seconds: 1));
        gateway.event('message.delta', 'rt-1', {'text': 'e'});
        gateway.event('message.complete', 'rt-1', {
          'text': 'b67e',
          'status': 'complete',
        });
        async.flushMicrotasks();

        expect(follow.error, isNull);
        expect(_deltas(follow), ['b', '6', '7', 'e']);
        expect(
          (gateway.requestOf('session.events.since')['params']
              as Map)['last_seen'],
          5,
        );
      });
    });

    test('cancelling after a reconnect closes the new watch, so the thread is '
        'picked up afresh', () {
      fake((async) {
        gateway.resumeResult = {'session_id': 'rt-1', 'running': true};
        gateway.turn = finishedReply;
        _listen(transport.send(text: 'hi'));
        async.flushMicrotasks();

        final follow = _listen(transport.followUps('stored-1'));
        async.flushMicrotasks();
        gateway.event('message.start', 'rt-1');
        async.flushMicrotasks();
        gateway.drop();
        async.elapse(const Duration(seconds: 1));
        int resumes() =>
            gateway.methods.where((m) => m == 'session.resume').length;
        final before = resumes();

        unawaited(follow.subscription.cancel());
        async.flushMicrotasks();
        final next = _listen(transport.followUps('stored-1'));
        async.flushMicrotasks();

        // A parked watch left behind would be read instead, and nothing asked.
        expect(resumes(), before + 1);
        unawaited(next.subscription.cancel());
      });
    });

    test('a thread picked up from a snapshot replays what a drop missed', () {
      fake((async) {
        gateway.resumeResult = {
          'session_id': 'rt-1',
          'running': true,
          'inflight': {'assistant': 'x'},
        };

        final follow = _listen(transport.followUps('stored-1'));
        async.flushMicrotasks();
        _deltaSeqs(gateway, 'rt-1', 1, 2);
        async.flushMicrotasks();
        gateway.drop();
        _deltaSeqs(gateway, 'rt-1', 3, 4);
        async.elapse(const Duration(seconds: 1));
        gateway.event('message.delta', 'rt-1', {'text': '5'});
        gateway.event('message.complete', 'rt-1', {
          'text': 'x12345',
          'status': 'complete',
        });
        async.flushMicrotasks();

        expect(follow.error, isNull);
        expect(follow.events.first, isA<ReplyStarted>());
        expect(_deltas(follow), ['1', '2', '3', '4', '5']);
      });
    });

    test('a thread picked up from a snapshot that drops before any live '
        'event rebuilds again instead of replaying the ring', () {
      fake((async) {
        gateway.resumeResult = {
          'session_id': 'rt-1',
          'running': true,
          'inflight': {'assistant': 'x'},
        };

        final follow = _listen(transport.followUps('stored-1'));
        async.flushMicrotasks();
        gateway.drop();
        _deltaSeqs(gateway, 'rt-1', 1, 3);
        gateway.resumeResult = {
          'session_id': 'rt-1',
          'running': true,
          'inflight': {'assistant': 'x123'},
        };
        async.elapse(const Duration(seconds: 1));
        gateway.event('message.delta', 'rt-1', {'text': '4'});
        gateway.event('message.complete', 'rt-1', {
          'text': 'x1234',
          'status': 'complete',
        });
        async.flushMicrotasks();

        expect(follow.error, isNull);
        expect(gateway.methods, isNot(contains('session.events.since')));
        expect(follow.events.whereType<ReplyRebuilt>().map((e) => e.text), [
          'x',
          'x123',
        ]);
        expect(_deltas(follow), ['4']);
      });
    });

    test('opening a thread offline makes one attempt and does not wait', () {
      fake((async) {
        final waits = <Duration>[];
        var attempts = 0;
        transport = HermesGatewayTransport(
          random: _FixedRandom(0.5),
          sleep: (delay) async => waits.add(delay),
          connect: () async {
            attempts++;
            throw StateError('gateway unreachable');
          },
        );

        final follow = _listen(transport.followUps('stored-1'));
        async.flushMicrotasks();

        expect(attempts, 1);
        expect(waits, isEmpty);
        expect(follow.done, isTrue);
        expect(follow.error, isNull);
      });
    });
  });

  group('Watches that start where they should', () {
    test('frames a send buffered are not dropped because a live idle watch '
        'already saw them', () {
      fake((async) {
        gateway.resumeResult = {'session_id': 'rt-1', 'running': true};
        gateway.turn = (g, sid) {
          g.event('message.start', sid);
          g.event('message.complete', sid, {'text': 'a', 'status': 'complete'});
        };
        _listen(transport.send(text: 'hi'));
        async.flushMicrotasks();

        gateway.turn = (_, _) {};
        gateway.beforeResumeAnswer = (g) => _deltaSeqs(g, 'rt-1', 3, 4);
        final again = _listen(
          transport.send(threadId: 'stored-1', text: 'again'),
        );
        async.flushMicrotasks();

        expect(_deltas(again), ['3', '4']);
      });
    });

    test('a restarted server that numbers from 1 again is not mistaken for '
        'duplicates', () {
      fake((async) {
        gateway.resumeResult = {'session_id': 'rt-1', 'running': true};
        gateway.turn = (g, sid) {
          g.event('message.start', sid);
          g.event('message.delta', sid, {'text': 'a'});
          g.event('message.complete', sid, {'text': 'a', 'status': 'complete'});
        };
        _listen(transport.send(text: 'hi'));
        async.flushMicrotasks();

        gateway.drop();
        gateway.epoch = 'epoch-2';
        gateway.turn = (g, sid) {
          g.event('message.start', sid);
          g.event('message.delta', sid, {'text': 'x'});
          g.event('message.complete', sid, {'text': 'x', 'status': 'complete'});
        };
        final again = _listen(
          transport.send(threadId: 'stored-1', text: 'again'),
        );
        async.flushMicrotasks();

        expect(again.error, isNull);
        expect(_deltas(again), ['x']);
        expect(again.events.last, isA<ReplyCompleted>());
      });
    });

    test('a resume on another runtime session with no snapshot reads the '
        'thread again', () {
      fake((async) {
        gateway.resumeResult = {'session_id': 'rt-9', 'running': true};
        gateway.turn = (g, sid) => _streamSevenThenDrop(g, sid, (_) {});

        final seen = _listen(transport.send(text: 'hi'));
        async.flushMicrotasks();
        gateway.event('message.complete', 'rt-9', {
          'text': 'z',
          'status': 'complete',
        });
        async.flushMicrotasks();

        expect(seen.events.whereType<ThreadNeedsRefetch>(), hasLength(1));
        expect(seen.events.last, isA<ReplyCompleted>());
      });
    });
  });

  group('Listening on after a turn that ended while disconnected', () {
    test('a follow-up stream goes on to the next turn Hermes chains', () {
      fake((async) {
        gateway.resumeResult = {'session_id': 'rt-1', 'running': true};
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
        gateway.resumeResult = {
          'session_id': 'rt-1',
          'running': false,
          'messages': [
            {'role': 'assistant', 'text': 'Done'},
          ],
        };
        gateway.drop();
        async.elapse(const Duration(seconds: 1));
        expect(follow.events.last, isA<ReplyCompleted>());

        gateway.event('message.start', 'rt-1');
        gateway.event('message.delta', 'rt-1', {'text': 'again'});
        async.flushMicrotasks();

        expect(follow.done, isFalse);
        final tail = follow.events.sublist(follow.events.length - 2);
        expect(tail.map((e) => e.runtimeType), [ReplyStarted, ReplyDelta]);
        expect(_deltas(follow), ['again']);
      });
    });

    test('a picked-up thread whose turn ended goes on to the next one', () {
      fake((async) {
        gateway.resumeResult = {
          'session_id': 'rt-1',
          'running': false,
          'messages': [
            {'role': 'assistant', 'text': 'Done'},
          ],
        };

        final follow = _listen(transport.followUps('stored-1'));
        async.flushMicrotasks();
        expect(follow.events.single, isA<ReplyCompleted>());

        gateway.event('message.start', 'rt-1');
        gateway.event('message.delta', 'rt-1', {'text': 'again'});
        async.flushMicrotasks();

        expect(follow.done, isFalse);
        expect(_deltas(follow), ['again']);
      });
    });
  });

  group('A watch the transport closed', () {
    test('a follow-up stream is not reconnected when a send takes the '
        'session over', () {
      fake((async) {
        gateway.resumeResult = {'session_id': 'rt-1', 'running': true};
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

        gateway.turn = (_, _) {};
        _listen(transport.send(threadId: 'stored-1', text: 'next'));
        async.flushMicrotasks();
        gateway.event('message.delta', 'rt-1', {'text': 'z'});
        async.flushMicrotasks();

        expect(follow.done, isTrue);
        expect(follow.error, isNull);
        expect(_deltas(follow), isEmpty);
        // One resume: the send's own, not a reconnect of the follow-up.
        expect(
          gateway.methods.where((m) => m == 'session.resume'),
          hasLength(1),
        );
      });
    });
  });

  group('Reconnecting with the settle, gate and re-key rules of main', () {
    test('a follow-up stream re-keyed by compression reconnects under the new '
        'id and is cleaned up under it', () {
      fake((async) {
        gateway.resumeResult = {'session_id': 'rt-1', 'running': true};
        gateway.turn = (g, sid) {
          g.event('message.start', sid);
          g.event('message.complete', sid, {'text': 'a', 'status': 'complete'});
        };
        _listen(transport.send(text: 'hi'));
        async.flushMicrotasks();

        final follow = _listen(transport.followUps('stored-1'));
        async.flushMicrotasks();
        gateway.event('message.start', 'rt-1');
        gateway.event('session.info', 'rt-1', {
          'running': true,
          'stored_session_id': 'stored-2',
        });
        async.flushMicrotasks();
        gateway.drop();
        async.elapse(const Duration(seconds: 1));

        expect(
          gateway.requestOf('session.resume')['params'],
          containsPair('session_id', 'stored-2'),
        );

        int resumes() =>
            gateway.methods.where((m) => m == 'session.resume').length;
        final before = resumes();
        unawaited(follow.subscription.cancel());
        async.flushMicrotasks();
        final next = _listen(transport.followUps('stored-2'));
        async.flushMicrotasks();

        // The reconnected watch was taken out of _idle under the new key, so
        // the thread is picked up afresh rather than read from a stale watch.
        expect(resumes(), before + 1);
        unawaited(next.subscription.cancel());
      });
    });

    test('a prompt queued behind a running turn keeps its gate across a drop '
        'that ended both turns', () {
      fake((async) {
        gateway.submitStatus = 'queued';
        gateway.resumeResult = {
          'session_id': 'rt-1',
          'running': false,
          'messages': [
            {'role': 'assistant', 'text': 'new done'},
          ],
        };
        gateway.turn = (g, sid) {
          g.event('message.delta', sid, {'text': 'old'});
          g.drop();
          g.event('message.complete', sid, {
            'text': 'old done',
            'status': 'complete',
          });
          g.event('session.info', sid, {'running': false});
        };

        final seen = _listen(transport.send(text: 'next', queued: true));
        async.flushMicrotasks();

        expect(seen.error, isNull);
        expect(seen.done, isTrue);
        expect(seen.events.whereType<ReplyCompleted>(), isEmpty);
        expect(seen.events.whereType<ThreadNeedsRefetch>(), isNotEmpty);
        expect(
          seen.events.last,
          isA<SessionInfo>().having((e) => e.running, 'running', false),
        );
      });
    });
  });

  group('Cancelling during a reconnect', () {
    test('a reply whose consumer cancelled makes no further attempt', () {
      fake((async) {
        var attempts = 0;
        var opened = 0;
        transport = HermesGatewayTransport(
          random: _FixedRandom(0.5),
          connect: () async {
            if (opened++ == 0) return gateway.connect();
            attempts++;
            throw StateError('gateway unreachable');
          },
        );
        gateway.turn = (g, sid) => _streamSevenThenDrop(g, sid, (_) {});

        final seen = _listen(transport.send(text: 'hi'));
        async.flushMicrotasks();
        expect(attempts, 1);

        unawaited(seen.subscription.cancel());
        async.elapse(const Duration(seconds: 30));

        expect(attempts, 1);
        expect(seen.error, isNull);
      });
    });

    test('a follow-up stream that was cancelled makes no further attempt', () {
      fake((async) {
        var attempts = 0;
        var opened = 0;
        transport = HermesGatewayTransport(
          random: _FixedRandom(0.5),
          connect: () async {
            if (opened++ == 0) return gateway.connect();
            attempts++;
            throw StateError('gateway unreachable');
          },
        );
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
        gateway.drop();
        async.flushMicrotasks();
        expect(attempts, 1);

        unawaited(follow.subscription.cancel());
        async.elapse(const Duration(seconds: 30));

        expect(attempts, 1);
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
