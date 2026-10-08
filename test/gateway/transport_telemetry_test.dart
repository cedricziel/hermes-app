import 'dart:async';
import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/chat/gateway/unmapped_events.dart';

import '../support/fake_gateway.dart';
import '../support/recorded_events.dart';

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

/// A [Random] whose draws are fixed, so the backoff delays are known.
class _FixedRandom implements Random {
  @override
  bool nextBool() => true;

  @override
  double nextDouble() => 0.5;

  @override
  int nextInt(int max) => max ~/ 2;
}

/// A turn that streams seqs 1 to 7, then drops the socket. [whileDown] records
/// what the server emits while the socket is down.
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

void main() {
  late FakeGateway gateway;
  late RecordedEvents events;
  late HermesGatewayTransport transport;

  /// Runs [body] under fake time with a fresh gateway and transport, which
  /// are built inside the fake zone so their microtasks run on
  /// `flushMicrotasks`.
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

  setUp(() {
    gateway = FakeGateway();
    events = RecordedEvents();
    transport = HermesGatewayTransport(
      connect: () async => gateway.channel,
      events: events.call,
    );
  });

  tearDown(() => transport.close());

  Future<void> reply({String text = 'hi'}) => transport
      .send(text: text)
      .toList()
      .timeout(const Duration(seconds: 5))
      .then((_) {});

  group('gateway.turn_settled', () {
    test('a completion settles the turn as complete', () async {
      gateway.turn = (g, sid) => g.event('message.complete', sid, {
        'text': 'Hi',
        'status': 'complete',
      });

      await reply();

      expect(events.named('gateway.turn_settled'), [
        {'via': 'complete'},
      ]);
    });

    test('an idle report settles a turn that never completed', () async {
      gateway.turn = (g, sid) {
        g.event('message.start', sid);
        g.event('message.delta', sid, {'text': 'partial'});
        g.event('session.info', sid, {'running': false});
      };

      await reply();

      expect(events.named('gateway.turn_settled'), [
        {'via': 'session_info'},
      ]);
    });

    test('an error event then an idle report settles the turn as an error '
        'event', () async {
      gateway.turn = (g, sid) {
        g.event('message.start', sid);
        g.event('error', sid, {'message': 'provider down'});
        g.event('session.info', sid, {'running': false});
      };

      await reply();

      expect(events.named('gateway.turn_settled'), [
        {'via': 'error_event'},
      ]);
    });

    test('a failed completion after an error event is a completion', () async {
      gateway.turn = (g, sid) {
        g.event('message.start', sid);
        g.event('error', sid, {'message': 'provider down'});
        g.event('message.complete', sid, {'text': 'x', 'status': 'error'});
      };

      await reply();

      expect(events.named('gateway.turn_settled'), [
        {'via': 'complete'},
      ]);
    });

    test('a chained turn settled on the follow-ups is reported too', () async {
      gateway.turn = (g, sid) => g.event('message.complete', sid, {
        'text': 'Hi',
        'status': 'complete',
      });
      await reply();
      final seen = _listen(transport.followUps('stored-1'));

      gateway
        ..event('message.start', 'rt-1')
        ..event('message.delta', 'rt-1', {'text': 'goal'})
        ..event('session.info', 'rt-1', {'running': false});
      await pumpEventQueue();

      expect(seen.events.last, isA<SessionInfo>());
      expect(events.named('gateway.turn_settled'), [
        {'via': 'complete'},
        {'via': 'session_info'},
      ]);
    });

    test('a silent turn that is no longer listed is reported as a probe', () {
      fakeAsync((async) {
        final silent = FakeGateway()..activeSessions = {};
        final recorded = RecordedEvents();
        final probing = HermesGatewayTransport(
          connect: () async => silent.channel,
          events: recorded.call,
        );
        silent.turn = (g, sid) => g.event('message.start', sid);
        final seen = _listen(probing.send(text: 'hi'));
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 45));
        async.flushMicrotasks();

        expect(seen.error, isA<GatewayConnectionClosed>());
        expect(recorded.named('gateway.turn_settled'), [
          {'via': 'silence_probe'},
        ]);
      });
    });

    test('a silent turn that is still listed is not settled', () {
      fakeAsync((async) {
        final silent = FakeGateway()..activeSessions = {'stored-1': 'working'};
        final recorded = RecordedEvents();
        final probing = HermesGatewayTransport(
          connect: () async => silent.channel,
          events: recorded.call,
        );
        silent.turn = (g, sid) => g.event('message.start', sid);
        _listen(probing.send(text: 'hi'));
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 90));
        async.flushMicrotasks();

        expect(recorded.named('gateway.turn_settled'), isEmpty);
      });
    });
  });

  group('gateway.reconnect', () {
    test('a replay that fills the gap is reported with its size', () {
      fake((async) {
        gateway.resumeResult = {'session_id': 'rt-1', 'running': true};
        gateway.turn = (g, sid) => _streamSevenThenDrop(g, sid, (g) {
          for (var seq = 8; seq <= 12; seq++) {
            g.event('message.delta', sid, {'text': '$seq'});
          }
        });

        _listen(transport.send(text: 'hi'));
        async.flushMicrotasks();

        expect(events.named('gateway.reconnect'), [
          {
            'attempt': 1,
            'outcome': 'replayed',
            'replayed_count': 5,
            'truncated': false,
            'epoch_changed': false,
          },
        ]);
      });
    });

    test('a truncated replay rebuilt from the snapshot is a refetch', () {
      fake((async) {
        gateway.truncateReplay = true;
        gateway.resumeResult = {
          'session_id': 'rt-1',
          'running': true,
          'inflight': {'assistant': 'abc'},
        };
        gateway.turn = (g, sid) => _streamSevenThenDrop(g, sid);

        _listen(transport.send(text: 'hi'));
        async.flushMicrotasks();

        expect(events.named('gateway.reconnect'), [
          {
            'attempt': 1,
            'outcome': 'rest_refetch',
            'replayed_count': 0,
            'truncated': true,
            'epoch_changed': false,
          },
        ]);
      });
    });

    test('a restarted server is reported as an epoch change', () {
      fake((async) {
        gateway.resumeResult = {
          'session_id': 'rt-1',
          'running': true,
          'inflight': {'assistant': 'abc'},
        };
        gateway.turn = (g, sid) =>
            _streamSevenThenDrop(g, sid, (g) => g.epoch = 'epoch-2');

        _listen(transport.send(text: 'hi'));
        async.flushMicrotasks();

        expect(events.named('gateway.reconnect'), [
          {
            'attempt': 1,
            'outcome': 'rest_refetch',
            'replayed_count': 0,
            'truncated': false,
            'epoch_changed': true,
          },
        ]);
      });
    });

    test('a turn that ended while disconnected is reported as ended', () {
      fake((async) {
        gateway.resumeResult = {'session_id': 'rt-1', 'running': false};
        gateway.turn = (g, sid) => _streamSevenThenDrop(g, sid, (g) {
          g.event('message.complete', sid, {
            'text': 'Done',
            'status': 'complete',
          });
        });

        _listen(transport.send(text: 'hi'));
        async.flushMicrotasks();

        expect(events.named('gateway.reconnect'), [
          {
            'attempt': 1,
            'outcome': 'ended',
            'replayed_count': 1,
            'truncated': false,
            'epoch_changed': false,
          },
        ]);
      });
    });

    test(
      'a turn that ended while disconnected is also reported as settled',
      () {
        fake((async) {
          gateway.resumeResult = {'session_id': 'rt-1', 'running': false};
          gateway.turn = (g, sid) => _streamSevenThenDrop(g, sid, (g) {
            g.event('message.complete', sid, {
              'text': 'Done',
              'status': 'complete',
            });
          });

          _listen(transport.send(text: 'hi'));
          async.flushMicrotasks();

          expect(events.named('gateway.turn_settled'), [
            {'via': 'complete'},
          ]);
        });
      },
    );

    test('a turn that ended while disconnected with only its stored reply is '
        'settled as complete', () {
      fake((async) {
        gateway.resumeResult = {
          'session_id': 'rt-1',
          'running': false,
          'messages': [
            {'role': 'assistant', 'text': 'Done'},
          ],
        };
        gateway.turn = (g, sid) => _streamSevenThenDrop(g, sid);

        _listen(transport.send(text: 'hi'));
        async.flushMicrotasks();

        expect(events.named('gateway.turn_settled'), [
          {'via': 'complete'},
        ]);
      });
    });

    test('a thread picked up while its turn runs is reported once it '
        'settles', () async {
      gateway.resumeResult = {'session_id': 'rt-1', 'running': true};

      _listen(transport.followUps('stored-1'));
      await pumpEventQueue();
      expect(events.named('gateway.turn_settled'), isEmpty);

      gateway.event('message.complete', 'rt-1', {
        'text': 'Done',
        'status': 'complete',
      });
      await pumpEventQueue();

      expect(events.named('gateway.turn_settled'), [
        {'via': 'complete'},
      ]);
    });

    test('opening an idle thread with a stored reply logs no settle', () {
      fake((async) {
        gateway.resumeResult = {
          'session_id': 'rt-1',
          'running': false,
          'messages': [
            {'role': 'assistant', 'text': 'Done'},
          ],
        };

        final seen = _listen(transport.followUps('stored-1'));
        async.flushMicrotasks();

        expect(seen.events.whereType<ReplyCompleted>(), isNotEmpty);
        expect(events.named('gateway.turn_settled'), isEmpty);
      });
    });

    test('opening an idle thread with nothing stored logs no settle', () {
      fake((async) {
        gateway.resumeResult = {'session_id': 'rt-1', 'running': false};

        _listen(transport.followUps('stored-1'));
        async.flushMicrotasks();

        expect(events.named('gateway.turn_settled'), isEmpty);
      });
    });

    group('a queued prompt whose connection dropped', () {
      /// The turn ahead of the prompt ends while the socket is down, and the
      /// replay hands over its completion before the prompt's own turn began.
      void queuedBehindEndedTurn(FakeAsync async, {required Duration after}) {
        gateway.resumeResult = {'session_id': 'rt-1', 'running': false};
        gateway.submitStatus = 'queued';
        gateway.turn = (g, sid) => g.event('message.delta', sid, {'text': '1'});

        _listen(transport.send(text: 'hi'));
        async.flushMicrotasks();
        async.elapse(after);
        gateway.drop();
        gateway.event('message.complete', 'rt-1', {
          'text': 'old',
          'status': 'complete',
        });
        async.flushMicrotasks();
      }

      test('the idle report that stands in for the turn ahead settles the '
          'reply inside the grace too', () {
        fake((async) {
          queuedBehindEndedTurn(async, after: const Duration(seconds: 1));

          expect(events.named('gateway.reconnect'), hasLength(1));
          expect(events.named('gateway.turn_settled'), [
            {'via': 'session_info'},
          ]);
        });
      });

      test('the same report is a settle once the grace has passed', () {
        fake((async) {
          queuedBehindEndedTurn(async, after: const Duration(seconds: 20));

          expect(events.named('gateway.turn_settled'), [
            {'via': 'session_info'},
          ]);
        });
      });

      for (final after in [1, 20]) {
        test('the prompt\'s own turn settling later on the follow-ups is not '
            'counted again (${after}s)', () {
          fake((async) {
            queuedBehindEndedTurn(async, after: Duration(seconds: after));
            final seen = _listen(transport.followUps('stored-1'));
            async.flushMicrotasks();

            gateway
              ..event('message.start', 'rt-1')
              ..event('message.delta', 'rt-1', {'text': 'mine'})
              ..event('message.complete', 'rt-1', {
                'text': 'mine',
                'status': 'complete',
              });
            async.flushMicrotasks();

            expect(seen.events.whereType<ReplyCompleted>(), hasLength(1));
            expect(events.named('gateway.turn_settled'), [
              {'via': 'session_info'},
            ]);

            // The next turn Hermes chains is a reply of its own.
            gateway
              ..event('message.start', 'rt-1')
              ..event('message.complete', 'rt-1', {
                'text': 'goal',
                'status': 'complete',
              });
            async.flushMicrotasks();

            expect(events.named('gateway.turn_settled'), [
              {'via': 'session_info'},
              {'via': 'complete'},
            ]);
          });
        });
      }

      test('a truncated replay settles the queued prompt\'s reply once, and a separate '
          'turn on the follow-ups is counted too', () {
        fake((async) {
          gateway
            ..resumeResult = {
              'session_id': 'rt-1',
              'running': false,
              'messages': [
                {'role': 'assistant', 'text': 'old'},
              ],
            }
            ..truncateReplay = true
            ..submitStatus = 'queued'
            ..turn = (g, sid) => g.event('message.delta', sid, {'text': '1'});

          _listen(transport.send(text: 'hi'));
          async.flushMicrotasks();
          gateway.drop();
          gateway.event('message.complete', 'rt-1', {
            'text': 'old',
            'status': 'complete',
          });
          async.flushMicrotasks();
          expect(events.named('gateway.turn_settled'), [
            {'via': 'session_info'},
          ]);

          _listen(transport.followUps('stored-1'));
          async.flushMicrotasks();
          gateway
            ..event('message.start', 'rt-1')
            ..event('message.complete', 'rt-1', {
              'text': 'goal',
              'status': 'complete',
            });
          async.flushMicrotasks();

          expect(events.named('gateway.turn_settled'), [
            {'via': 'session_info'},
            {'via': 'complete'},
          ]);
        });
      });

      test('a restarted server settles the queued prompt\'s reply once, and a separate '
          'turn on the follow-ups is counted too', () {
        fake((async) {
          gateway
            ..resumeResult = {
              'session_id': 'rt-1',
              'running': false,
              'messages': [
                {'role': 'assistant', 'text': 'old'},
              ],
            }
            ..submitStatus = 'queued'
            ..turn = (g, sid) => g.event('message.delta', sid, {'text': '1'});

          _listen(transport.send(text: 'hi'));
          async.flushMicrotasks();
          gateway.drop();
          gateway.epoch = 'epoch-2';
          gateway.event('message.complete', 'rt-1', {
            'text': 'old',
            'status': 'complete',
          });
          async.flushMicrotasks();
          expect(events.named('gateway.turn_settled'), [
            {'via': 'session_info'},
          ]);

          _listen(transport.followUps('stored-1'));
          async.flushMicrotasks();
          gateway
            ..event('message.start', 'rt-1')
            ..event('message.complete', 'rt-1', {
              'text': 'goal',
              'status': 'complete',
            });
          async.flushMicrotasks();

          expect(events.named('gateway.turn_settled'), [
            {'via': 'session_info'},
            {'via': 'complete'},
          ]);
        });
      });

      test('a prompt\'s completion delivered by a pick-up leaves nothing to '
          'skip: the next turn on the follow-ups is counted', () {
        fake((async) {
          queuedBehindEndedTurn(async, after: const Duration(seconds: 20));
          expect(events.named('gateway.turn_settled'), [
            {'via': 'session_info'},
          ]);

          // The idle watch dies, so reopening the thread picks it up afresh
          // and finds the prompt's reply stored.
          gateway.drop();
          gateway.resumeResult = {
            'session_id': 'rt-1',
            'running': false,
            'messages': [
              {'role': 'assistant', 'text': 'mine'},
            ],
          };
          async.flushMicrotasks();
          final seen = _listen(transport.followUps('stored-1'));
          async.flushMicrotasks();
          expect(seen.events.whereType<ReplyCompleted>(), hasLength(1));

          gateway
            ..event('message.start', 'rt-1')
            ..event('message.complete', 'rt-1', {
              'text': 'goal',
              'status': 'complete',
            });
          async.flushMicrotasks();

          expect(events.named('gateway.turn_settled'), [
            {'via': 'session_info'},
            {'via': 'complete'},
          ]);
        });
      });

      test('a turn Hermes ran on its own is counted once, and not as the '
          'prompt\'s turn beginning', () {
        fake((async) {
          gateway
            ..resumeResult = {
              'session_id': 'rt-2',
              'session_key': 'stored-2',
              'auto_continue': {'attempt': 1},
            }
            ..submitStatus = 'queued'
            ..beforeSubmitAnswer = (g) {
              g.event('message.start', 'rt-2');
            }
            ..turn = (g, sid) {
              g.drop();
              g.event('message.complete', 'rt-2', {
                'text': 'resumed',
                'status': 'complete',
              });
            };

          _listen(transport.send(threadId: 'stored-2', text: 'hi'));
          async.flushMicrotasks();
          final seen = _listen(transport.followUps('stored-2'));
          async.flushMicrotasks();

          expect(seen.events.whereType<ReplyCompleted>(), hasLength(1));
          expect(events.named('gateway.turn_settled'), [
            {'via': 'session_info'},
            {'via': 'complete'},
          ]);
        });
      });
    });

    test('a gateway that cannot be reached is reported as failed after the '
        'attempts made', () {
      fake((async) {
        var opened = 0;
        transport = HermesGatewayTransport(
          events: events.call,
          random: _FixedRandom(),
          connect: () async {
            if (opened++ == 0) return gateway.connect();
            throw StateError('gateway unreachable');
          },
        );
        gateway.turn = (g, sid) => _streamSevenThenDrop(g, sid);

        final seen = _listen(transport.send(text: 'hi'));
        async.elapse(const Duration(seconds: 30));

        expect(seen.error, isA<GatewayConnectionClosed>());
        expect(events.named('gateway.reconnect'), [
          {
            'attempt': 5,
            'outcome': 'failed',
            'replayed_count': 0,
            'truncated': false,
            'epoch_changed': false,
          },
        ]);
      });
    });

    test('the replayed text is never part of the event', () {
      fake((async) {
        gateway.resumeResult = {'session_id': 'rt-1', 'running': true};
        gateway.turn = (g, sid) => _streamSevenThenDrop(g, sid, (g) {
          g.event('message.delta', sid, {'text': 'confidential words'});
        });

        _listen(transport.send(text: 'confidential words'));
        async.flushMicrotasks();

        final attributes = events.named('gateway.reconnect').single;
        expect(attributes.keys, {
          'attempt',
          'outcome',
          'replayed_count',
          'truncated',
          'epoch_changed',
        });
        expect(attributes.values.whereType<String>(), ['replayed']);
      });
    });
  });

  group('gateway.event_unmapped', () {
    Future<void> turnSending(
      void Function(FakeGateway g, String sid) extra,
    ) async {
      gateway.turn = (g, sid) {
        extra(g, sid);
        g.event('message.complete', sid, {'text': 'Hi', 'status': 'complete'});
      };
      await reply();
    }

    test('a type the app does not show is reported once per connection, '
        'without its payload', () async {
      await turnSending((g, sid) {
        g.event('foo.bar', sid, {'text': 'private words'});
        g.event('foo.bar', sid, {'text': 'private words'});
      });

      expect(events.named('gateway.event_unmapped'), [
        {'event.type': 'foo.bar'},
      ]);
    });

    test('a new connection reports the type again', () async {
      Future<void> unknownTurn() => turnSending(
        (g, sid) => g.event('foo.bar', sid, {'text': 'private words'}),
      );
      await unknownTurn();
      await transport.close();
      gateway = FakeGateway();
      transport = HermesGatewayTransport(
        connect: () async => gateway.channel,
        events: events.call,
      );

      await unknownTurn();

      expect(events.named('gateway.event_unmapped'), hasLength(2));
    });

    test('expected noise and other sessions are not reported', () async {
      await turnSending((g, sid) {
        g.event('gateway.ready', '');
        g.event('session.usage', sid);
        g.event('sessions.changed', '');
        g.event('skills.changed', sid);
        g.event('notification.push', sid);
        g.event('foo.bar', 'rt-other');
      });

      expect(events.named('gateway.event_unmapped'), isEmpty);
    });

    test('a long type is cut to 64 characters', () async {
      await turnSending((g, sid) => g.event('x' * 100, sid));

      expect(events.named('gateway.event_unmapped'), [
        {'event.type': 'x' * 64},
      ]);
    });

    test(
      'after 20 distinct types the rest are reported as other, once',
      () async {
        await turnSending((g, sid) {
          for (var i = 0; i < 30; i++) {
            g.event('type.$i', sid);
          }
        });

        final reported = [
          for (final e in events.named('gateway.event_unmapped'))
            e['event.type'],
        ];
        expect(reported, [for (var i = 0; i < 20; i++) 'type.$i', 'other']);
      },
    );

    test(
      'a server request the app does not answer is reported as one',
      () async {
        gateway.turn = (g, sid) {
          g.serverRequest('srq-1', 'desktop.bridge', sid, {'text': 'private'});
          g.event('message.complete', sid, {
            'text': 'Hi',
            'status': 'complete',
          });
        };

        await reply();

        expect(events.named('gateway.event_unmapped'), [
          {'event.type': 'desktop.bridge', 'server_request': true},
        ]);
      },
    );

    test('an app that logs nothing still works', () async {
      transport = HermesGatewayTransport(connect: () async => gateway.channel);

      await turnSending((g, sid) => g.event('foo.bar', sid));
    });

    test('a logger that throws does not break the reply', () async {
      transport = HermesGatewayTransport(
        connect: () async => gateway.channel,
        events: (name, [attributes = const {}]) => throw StateError('boom'),
      );

      await turnSending((g, sid) => g.event('foo.bar', sid));
    });
  });

  group('UnmappedEvents', () {
    test('keeps the 21st distinct type out and reports the overflow once', () {
      final unmapped = UnmappedEvents();

      final admitted = [for (var i = 0; i < 25; i++) unmapped.admit('t$i')];

      expect(admitted.take(20), [for (var i = 0; i < 20; i++) 't$i']);
      expect(admitted.skip(20), ['other', null, null, null, null]);
      expect(unmapped.admit('t0'), isNull);
    });
  });
}
