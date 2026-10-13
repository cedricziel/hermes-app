import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/chat/owned_session_transport.dart';

import '../support/fake_gateway.dart';

void main() {
  test(
    'usage lookup never guesses stored IDs or resumes an unattached session',
    () async {
      final gateway = FakeGateway();
      final transport = HermesGatewayTransport(connect: gateway.connect);
      addTearDown(transport.close);
      expect(
        transport.ownedSessionFor('stored-unknown', profile: 'work'),
        isNull,
      );
      expect(gateway.requests, isEmpty);
    },
  );

  test(
    'an attached usage read uses its actual runtime and explicit profile',
    () async {
      final gateway = FakeGateway();
      gateway.handlers['session.usage'] = (_) => {
        'model': 'reported',
        'total': 12,
        'cost_usd': 0.2,
      };
      gateway.turn = (g, sid) => g.event('message.complete', sid, {
        'text': 'Done',
        'status': 'complete',
      });
      final transport = HermesGatewayTransport(connect: gateway.connect);
      addTearDown(transport.close);
      final events = await transport
          .send(text: 'Test', profile: 'work')
          .toList();
      final stored = events.whereType<ThreadBound>().single.threadId;
      final binding = transport.ownedSessionFor(stored, profile: 'work')!;
      final resumesBefore = gateway.methods
          .where((method) => method == 'session.resume')
          .length;
      expect(
        await transport.readOwnedSession(binding, 'session.usage'),
        containsPair('total', 12),
      );
      expect(
        gateway.requests.singleWhere(
          (request) => request['method'] == 'session.usage',
        )['params'],
        {'session_id': 'rt-1', 'profile': 'work'},
      );
      expect(
        gateway.methods.where((method) => method == 'session.resume'),
        hasLength(resumesBefore),
      );
      expect(transport.ownedSessionFor(stored, profile: 'other'), isNull);
    },
  );

  test('usage ticks and completion totals keep their scoped source without opening another turn', () async {
    final gateway = FakeGateway()..stampSeq = true;
    gateway.turn = (g, sid) {
      g.event('session.usage', 'foreign-runtime', {
        'usage': {'total': 999},
      });
      g.event('session.usage', sid, {
        'usage': {'total': 12},
      });
      g.event('session.usage', sid, {
        'usage': {'total': 12},
      });
      g.event('message.complete', sid, {
        'text': 'Done',
        'status': 'complete',
        'usage': {'total': 13},
      });
    };
    final transport = HermesGatewayTransport(connect: gateway.connect);
    addTearDown(transport.close);
    final events = await transport.send(text: 'Test', profile: 'work').toList();
    final ticks = events.whereType<SessionUsageUpdated>().toList();
    expect(ticks.map((tick) => tick.snapshot?.total), [12, 12]);
    final binding = transport.ownedSessionFor('stored-1', profile: 'work')!;
    expect(
      ticks.every((tick) => identical(tick.connection, binding.connection)),
      isTrue,
    );
    final completion = events.whereType<ReplyCompleted>().single;
    expect(completion.usage?.total, 13);
    expect(completion.usageRuntimeId, 'rt-1');
  });

  test('an optional usage timeout keeps the same socket and reply usable', () {
    fakeAsync((clock) {
      final gateway = FakeGateway();
      gateway.silent.add('session.usage');
      gateway.turn = (g, sid) => g.event('message.complete', sid, {
        'text': 'Done',
        'status': 'complete',
      });
      final transport = HermesGatewayTransport(
        connect: gateway.connect,
        requestTimeout: const Duration(seconds: 2),
      );
      final first = transport.send(text: 'First').listen((_) {});
      clock.flushMicrotasks();
      final binding = transport.ownedSessionFor('stored-1')!;
      Object? failure;
      unawaited(
        transport.readOwnedSession(binding, 'session.usage').catchError((
          Object error,
        ) {
          failure = error;
          return <String, Object?>{};
        }),
      );
      clock.flushMicrotasks();
      clock.elapse(const Duration(seconds: 2));
      clock.flushMicrotasks();
      expect(failure, isA<TimeoutException>());
      expect(
        transport.ownedSessionFor('stored-1')?.connection,
        same(binding.connection),
      );
      final second = transport
          .send(threadId: 'stored-1', text: 'Second')
          .listen((_) {});
      clock.flushMicrotasks();
      expect(
        gateway.methods.where((method) => method == 'prompt.submit'),
        hasLength(2),
      );
      unawaited(first.cancel());
      unawaited(second.cancel());
      unawaited(transport.close());
      clock.flushMicrotasks();
    });
  });
  test('same-runtime takeover keeps the token and carries the guarded resume subset', () async {
    final gateway = FakeGateway();
    gateway.turn = (g, sid) => g.event('message.complete', sid, {
      'text': 'Done',
      'status': 'complete',
    });
    final transport = HermesGatewayTransport(connect: gateway.connect);
    addTearDown(transport.close);
    final changes = <OwnedSessionChange>[];
    final subscription = transport.ownedSessions.listen(changes.add);
    addTearDown(subscription.cancel);
    await transport.send(text: 'First', profile: 'work').toList();
    final first = transport.ownedSessionFor('stored-1', profile: 'work')!;
    gateway.silent.add('session.resume');
    final second = transport
        .send(threadId: 'stored-1', profile: 'work', text: 'Second')
        .toList();
    await pumpEventQueue();
    final started = changes.lastWhere((change) => change.resuming);
    expect(started.binding.connection, same(first.connection));
    expect(started.resumeToken, isNotNull);
    gateway.replyTo(
      gateway.requests.lastWhere(
        (request) => request['method'] == 'session.resume',
      ),
      {
        'session_id': 'rt-1',
        'stored_session_id': 'stored-1',
        'todo_state': {'revision': 5, 'todos': []},
        'messages': ['private transcript'],
      },
    );
    await second;
    final established = changes.lastWhere(
      (change) => change.resumeSnapshot != null,
    );
    expect(established.resumeToken, same(started.resumeToken));
    expect(established.binding.connection, same(first.connection));
    expect(established.resumeSnapshot, {
      'todo_state': {'revision': 5, 'todos': []},
    });
    expect(changes.where((change) => change.retired), isEmpty);
  });

  test('socket loss retires its exact token and old optional reads never resume it', () async {
    final gateway = FakeGateway();
    gateway.turn = (g, sid) => g.event('message.complete', sid, {
      'text': 'Done',
      'status': 'complete',
    });
    final transport = HermesGatewayTransport(connect: gateway.connect);
    addTearDown(transport.close);
    final changes = <OwnedSessionChange>[];
    final subscription = transport.ownedSessions.listen(changes.add);
    addTearDown(subscription.cancel);
    await transport.send(text: 'First', profile: 'work').toList();
    final binding = transport.ownedSessionFor('stored-1', profile: 'work')!;
    final resumesBefore = gateway.methods
        .where((method) => method == 'session.resume')
        .length;
    gateway.drop();
    await pumpEventQueue();
    expect(changes.last.connected, isFalse);
    expect(changes.last.binding.connection, same(binding.connection));
    expect(transport.ownedSessionFor('stored-1', profile: 'work'), isNull);
    await expectLater(
      transport.readOwnedSession(binding, 'session.usage'),
      throwsException,
    );
    expect(
      gateway.methods.where((method) => method == 'session.resume'),
      hasLength(resumesBefore),
    );
  });
  test(
    'a reclaimed runtime loses authority without a usage recovery resume',
    () async {
      final gateway = FakeGateway();
      gateway.turn = (g, sid) => g.event('message.complete', sid, {
        'text': 'Done',
        'status': 'complete',
      });
      final transport = HermesGatewayTransport(connect: gateway.connect);
      addTearDown(transport.close);
      final changes = <OwnedSessionChange>[];
      final subscription = transport.ownedSessions.listen(changes.add);
      addTearDown(subscription.cancel);
      await transport.send(text: 'First', profile: 'work').toList();
      final binding = transport.ownedSessionFor('stored-1', profile: 'work')!;
      gateway.event('session.reclaimed', '', {
        'session_id': 'rt-1',
        'stored_session_id': 'stored-1',
        'reason': 'Another client took over',
      });
      await pumpEventQueue();
      expect(changes.last.connected, isFalse);
      expect(changes.last.retired, isTrue);
      expect(transport.ownedSessionFor('stored-1', profile: 'work'), isNull);
      await expectLater(
        transport.readOwnedSession(binding, 'session.usage'),
        throwsException,
      );
      expect(gateway.methods, isNot(contains('session.usage')));
    },
  );
}
