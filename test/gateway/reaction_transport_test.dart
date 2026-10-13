import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';

import '../support/fake_gateway.dart';

void main() {
  test('verified prompt receipt carries the same physical runtime as live reactions', () async {
    final gateway = FakeGateway();
    gateway.handlers['prompt.submit'] = (params) {
      unawaited(
        Future<void>(() {
          gateway.event('message.reaction', params['session_id'] as String, {
            'row_id': 42,
            'role': 'user',
            'reactions': [
              {'emoji': '👍', 'author': 'agent'},
            ],
          });
          gateway.event('reaction', params['session_id'] as String, {
            'kind': 'vibe',
          });
          gateway.event('message.complete', params['session_id'] as String, {
            'text': 'Main',
            'status': 'complete',
          });
        }),
      );
      return {'status': 'streaming', 'user_row_id': 42};
    };
    final transport = HermesGatewayTransport(connect: gateway.connect);
    addTearDown(transport.close);
    final events = await transport.send(text: 'Own', profile: 'work').toList();
    final binding = transport.ownedSessionFor('stored-1', profile: 'work')!;
    final receipt = events.whereType<PromptAcknowledged>().single;
    expect(receipt.userRowId, 42);
    expect(receipt.runtimeId, binding.runtimeId);
    expect(receipt.connection, same(binding.connection));
    expect(
      events.whereType<MessageReactionsUpdated>().single.connection,
      same(binding.connection),
    );
    expect(events.whereType<SessionAcknowledgementReported>(), hasLength(1));
    expect(events.whereType<ReplyCompleted>().single.text, 'Main');
  });
  test('reaction replay and concurrent live frames reuse the existing sequence ledger', () {
    fakeAsync((clock) {
      final gateway = FakeGateway()
        ..stampSeq = true
        ..sendReady = true;
      gateway.resumeResult = {
        'session_id': 'rt-1',
        'session_key': 'stored-1',
        'running': true,
      };
      gateway.turn = (g, sid) {
        g.event('message.start', sid);
        g.event('message.reaction', sid, {
          'row_id': 21,
          'role': 'user',
          'reactions': [
            {'emoji': 'First', 'author': 'agent'},
          ],
        });
        g.drop();
        g.event('message.reaction', sid, {
          'row_id': 21,
          'role': 'user',
          'reactions': [
            {'emoji': 'Replayed', 'author': 'agent'},
          ],
        });
      };
      gateway.beforeEventsAnswer = (g) => g.event('message.reaction', 'rt-1', {
        'row_id': 21,
        'role': 'user',
        'reactions': [
          {'emoji': 'Replay and live', 'author': 'agent'},
        ],
      });
      final transport = HermesGatewayTransport(
        connect: gateway.connect,
        sleep: (_) async {},
      );
      final seen = <ChatEvent>[];
      final subscription = transport
          .send(text: 'Own', profile: 'work')
          .listen(seen.add);
      clock.flushMicrotasks();
      final snapshots = seen.whereType<MessageReactionsUpdated>().toList();
      expect(snapshots.map((event) => event.snapshot.reactions.single.emoji), [
        'First',
        'Replayed',
        'Replay and live',
      ]);
      expect(
        identical(snapshots.first.connection, snapshots.last.connection),
        isFalse,
      );
      expect(seen.whereType<ReplyCompleted>(), isEmpty);
      gateway.event('message.complete', 'rt-1', {
        'text': 'Main',
        'status': 'complete',
      });
      clock.flushMicrotasks();
      expect(seen.whereType<ReplyCompleted>(), hasLength(1));
      unawaited(subscription.cancel());
      unawaited(transport.close());
      clock.flushMicrotasks();
    });
  });
  test(
    'queued gate admits passive reactions before the preceding turn settles',
    () {
      fakeAsync((clock) {
        final gateway = FakeGateway()..submitStatus = 'queued';
        final transport = HermesGatewayTransport(connect: gateway.connect);
        final seen = <ChatEvent>[];
        final subscription = transport
            .send(text: 'Queued', profile: 'work')
            .listen(seen.add);
        clock.flushMicrotasks();
        gateway.event('message.delta', 'rt-1', {'text': 'Prior turn prose'});
        gateway.event('message.reaction', 'rt-1', {
          'row_id': 21,
          'role': 'user',
          'reactions': [
            {'emoji': '👍', 'author': 'agent'},
          ],
        });
        gateway.event('reaction', 'rt-1', {'kind': 'vibe'});
        clock.flushMicrotasks();
        expect(seen.whereType<MessageReactionsUpdated>(), hasLength(1));
        expect(seen.whereType<SessionAcknowledgementReported>(), hasLength(1));
        expect(seen.whereType<ReplyDelta>(), isEmpty);
        expect(seen.whereType<ReplyCompleted>(), isEmpty);
        unawaited(subscription.cancel());
        unawaited(transport.close());
        clock.flushMicrotasks();
      });
    },
  );

  test('auto-continued own-turn classifier leaves passive reactions session-scoped', () {
    fakeAsync((clock) {
      final gateway = FakeGateway()..submitStatus = 'queued';
      gateway.resumeResult = {
        'session_id': 'rt-2',
        'session_key': 'stored-2',
        'auto_continue': {'attempt': 1},
      };
      gateway.beforeSubmitAnswer = (g) {
        g.event('message.start', 'rt-2');
        g.event('message.delta', 'rt-2', {'text': 'Earlier own turn'});
      };
      final transport = HermesGatewayTransport(connect: gateway.connect);
      final seen = <ChatEvent>[];
      final subscription = transport
          .send(threadId: 'stored-2', text: 'Queued', profile: 'work')
          .listen(seen.add);
      clock.flushMicrotasks();
      gateway.event('message.reaction', 'rt-2', {
        'row_id': 21,
        'role': 'user',
        'reactions': [
          {'emoji': '👍', 'author': 'agent'},
        ],
      });
      gateway.event('reaction', 'rt-2', {'kind': 'vibe'});
      clock.flushMicrotasks();
      expect(seen.whereType<MessageReactionsUpdated>(), hasLength(1));
      expect(seen.whereType<SessionAcknowledgementReported>(), hasLength(1));
      expect(
        seen.whereType<UnsolicitedEvent>().where(
          (event) =>
              event.event is MessageReactionsUpdated ||
              event.event is SessionAcknowledgementReported,
        ),
        isEmpty,
      );
      expect(
        seen.whereType<UnsolicitedEvent>().where(
          (event) => event.event is ReplyDelta,
        ),
        hasLength(1),
      );
      expect(seen.whereType<ReplyCompleted>(), isEmpty);
      unawaited(subscription.cancel());
      unawaited(transport.close());
      clock.flushMicrotasks();
    });
  });
}
