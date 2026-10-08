import 'dart:async';

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

void main() {
  late FakeGateway gateway;
  late HermesGatewayTransport transport;

  setUp(() {
    gateway = FakeGateway();
    transport = HermesGatewayTransport(connect: () async => gateway.channel);
  });

  tearDown(() => transport.close());

  /// The events of a whole reply. Fails instead of hanging when the stream
  /// never ends.
  Future<List<ChatEvent>> reply({String? threadId, String text = 'hi'}) =>
      transport
          .send(threadId: threadId, text: text)
          .toList()
          .timeout(const Duration(seconds: 5));

  group('submit outcome', () {
    for (final status in ['redirected', 'steered']) {
      test(
        'Folded into the running turn: a $status submit yields PromptFolded and closes',
        () async {
          gateway.submitStatus = status;

          final events = await reply(threadId: 'stored-2');

          expect(events, hasLength(1));
          expect(events.single, isA<PromptFolded>());
        },
      );
    }

    test(
      'Queued by the server: a queued submit streams the turn once it starts',
      () async {
        gateway.submitStatus = 'queued';
        gateway.turn = (g, sid) {
          g.event('message.start', sid);
          g.event('message.delta', sid, {'text': 'Hi'});
          g.event('message.complete', sid, {
            'text': 'Hi',
            'status': 'complete',
          });
        };

        final events = await reply();

        expect(events.map((e) => e.runtimeType), [
          ThreadBound,
          ReplyStarted,
          ReplyDelta,
          ReplyCompleted,
        ]);
      },
    );

    test(
      'The reply arrives before the submit answer: events stream in order',
      () async {
        gateway.beforeSubmitAnswer = (g) {
          g.event('message.start', 'rt-1');
          g.event('message.delta', 'rt-1', {'text': 'Early'});
        };
        gateway.turn = (g, sid) => g.event('message.complete', sid, {
          'text': 'Early',
          'status': 'complete',
        });

        final events = await reply();

        expect(events.map((e) => e.runtimeType), [
          ThreadBound,
          ReplyStarted,
          ReplyDelta,
          ReplyCompleted,
        ]);
        expect((events[2] as ReplyDelta).text, 'Early');
      },
    );
  });

  group('early events', () {
    test('Events that arrive before the resume answer: a delta of the resumed session is yielded after the resume', () async {
      gateway.beforeResumeAnswer = (g) =>
          g.event('message.delta', 'rt-2', {'text': 'early'});
      gateway.turn = (g, sid) => g.event('message.complete', sid, {
        'text': 'Done',
        'status': 'complete',
      });

      final events = await reply(threadId: 'stored-2');

      expect(events.map((e) => e.runtimeType), [ReplyDelta, ReplyCompleted]);
      expect((events.first as ReplyDelta).text, 'early');
    });
  });

  group('turn settling', () {
    test('Settled without a completion: session.info running false ends the reply, keeping its text', () async {
      gateway.emitSessionInfo = true;
      gateway.turn = (g, sid) {
        g.event('message.start', sid);
        g.event('message.delta', sid, {'text': 'Partial'});
      };

      final events = await reply(threadId: 'stored-1');

      expect(events.map((e) => e.runtimeType), [
        ReplyStarted,
        ReplyDelta,
        SessionInfo,
      ]);
      expect((events.last as SessionInfo).running, isFalse);
    });

    test('Settled without a completion: a completion that arrives later reaches the follow-ups', () async {
      gateway.emitSessionInfo = true;
      gateway.turn = (g, sid) => g.event('message.start', sid);
      await reply(threadId: 'stored-1');

      gateway.event('message.complete', 'rt-2', {
        'text': 'Late',
        'status': 'complete',
      });
      final late = await transport
          .followUps('stored-1')
          .first
          .timeout(const Duration(seconds: 5));

      expect(late, isA<ReplyCompleted>());
      expect((late as ReplyCompleted).text, 'Late');
    });

    test('Stale report before the turn began: a running false report within 15 s does not end the reply', () async {
      gateway.turn = (g, sid) {
        g.event('session.info', sid, {'running': false});
        g.event('message.start', sid);
        g.event('message.complete', sid, {
          'text': 'Hello',
          'status': 'complete',
        });
      };

      final events = await reply();

      // The stale report is held back: it carries nothing the thread needs.
      expect(events.map((e) => e.runtimeType), [
        ThreadBound,
        ReplyStarted,
        ReplyCompleted,
      ]);
    });

    test('Stale report before the turn began: a running false report after 15 s without a start ends the reply', () {
      fakeAsync((async) {
        final gateway = FakeGateway();
        final transport = HermesGatewayTransport(
          connect: () async => gateway.channel,
        );
        final seen = _listen(transport.send(text: 'hi'));
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 10));
        gateway.event('session.info', 'rt-1', {'running': false});
        async.flushMicrotasks();
        expect(seen.done, isFalse);

        async.elapse(const Duration(seconds: 6));
        gateway.event('session.info', 'rt-1', {'running': false});
        async.flushMicrotasks();

        expect(seen.done, isTrue);
        expect(seen.events.last, isA<SessionInfo>());
      });
    });

    test('Error event without a completion: a settle after the error ends the reply, keeping its text', () async {
      gateway.emitSessionInfo = true;
      gateway.turn = (g, sid) {
        g.event('message.start', sid);
        g.event('message.delta', sid, {'text': 'Partial'});
        g.event('error', sid, {'message': 'boom'});
      };

      final events = await reply(threadId: 'stored-1');

      expect(events.map((e) => e.runtimeType), [
        ReplyStarted,
        ReplyDelta,
        ReplyErrored,
        SessionInfo,
      ]);
      expect((events[2] as ReplyErrored).message, 'boom');
    });

    test('Error event without a completion: a failed completion after the error ends the reply once', () async {
      gateway.turn = (g, sid) {
        g.event('error', sid, {'message': 'boom'});
        g.event('message.complete', sid, {'text': '', 'status': 'error'});
      };

      final events = await reply();

      expect(events.map((e) => e.runtimeType), [
        ThreadBound,
        ReplyErrored,
        ReplyCompleted,
      ]);
      expect((events.last as ReplyCompleted).failed, isTrue);
    });

    test('Only running false ends a reply: session.info with running true is forwarded and the stream goes on', () async {
      gateway.turn = (g, sid) {
        g.event('message.start', sid);
        g.event('session.info', sid, {'running': true});
        g.event('message.complete', sid, {
          'text': 'Hello',
          'status': 'complete',
        });
      };

      final events = await reply();

      expect(events.map((e) => e.runtimeType), [
        ThreadBound,
        ReplyStarted,
        SessionInfo,
        ReplyCompleted,
      ]);
      expect((events[2] as SessionInfo).running, isTrue);
    });
  });

  group('silence probe and heartbeat', () {
    test('A silent live turn: a session still listed as working keeps the reply waiting', () {
      fakeAsync((async) {
        final gateway = FakeGateway()..activeSessions = {'stored-1': 'working'};
        final transport = HermesGatewayTransport(
          connect: () async => gateway.channel,
        );
        gateway.turn = (g, sid) => g.event('message.start', sid);
        final seen = _listen(transport.send(text: 'hi'));
        int probes() =>
            gateway.methods.where((m) => m == 'session.active_list').length;
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 45));
        async.flushMicrotasks();
        expect(probes(), 1);
        expect(seen.done, isFalse);

        async.elapse(const Duration(seconds: 45));
        async.flushMicrotasks();
        expect(probes(), 2);
        expect(seen.done, isFalse);
        expect(seen.error, isNull);
      });
    });

    test(
      'A silent live turn: a session no longer listed ends the reply as broken',
      () {
        fakeAsync((async) {
          final gateway = FakeGateway()..activeSessions = {};
          final transport = HermesGatewayTransport(
            connect: () async => gateway.channel,
          );
          gateway.turn = (g, sid) => g.event('message.start', sid);
          final seen = _listen(transport.send(text: 'hi'));
          async.flushMicrotasks();

          async.elapse(const Duration(seconds: 44));
          async.flushMicrotasks();
          expect(seen.error, isNull);

          async.elapse(const Duration(seconds: 1));
          async.flushMicrotasks();
          expect(seen.error, isA<GatewayConnectionClosed>());
        });
      },
    );

    test('Dead socket: a socket silent for 45 s closes, and the reply in flight reconnects', () {
      fakeAsync((async) {
        final gateway = FakeGateway()
          ..resumeResult = {'session_id': 'rt-1', 'running': true};
        var connects = 0;
        final transport = HermesGatewayTransport(
          connect: () async {
            connects++;
            if (connects > 1) gateway.deaf = false;
            return gateway.connect();
          },
        );
        gateway.turn = (g, sid) => g.event('message.start', sid);
        final seen = _listen(transport.send(text: 'hi'));
        async.flushMicrotasks();

        gateway.deaf = true;
        async.elapse(const Duration(seconds: 44));
        async.flushMicrotasks();
        expect(connects, 1);

        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(connects, 2);
        expect(
          gateway.methods.where((m) => m == 'session.resume'),
          hasLength(1),
        );

        gateway.event('message.complete', 'rt-1', {
          'text': 'Back',
          'status': 'complete',
        });
        async.flushMicrotasks();

        expect(seen.done, isTrue);
        expect(seen.error, isNull);
        expect(seen.events.last, isA<ReplyCompleted>());
      });
    });
  });
}
