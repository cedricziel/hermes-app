import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_otel/flutter_otel.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway_connection_transport.dart';
import 'package:hermes_app/src/chat/connector_operation_state.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/chat/owned_session_transport.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';

import '../chat/connector_fixtures.dart';
import '../support/fake_gateway.dart';
import '../support/recording_tracer.dart';

void main() {
  test('neutral raw connection feed never opens a socket and precedes runtime filtering', () async {
    final gateway = FakeGateway();
    gateway.turn = (g, sid) => g.event('message.complete', sid, {
      'text': 'Main',
      'status': 'complete',
    });
    final transport = HermesGatewayTransport(connect: gateway.connect);
    addTearDown(transport.close);
    final signals = <GatewayConnectionEvent>[];
    final subscription = transport.connectionEvents.listen(signals.add);
    addTearDown(subscription.cancel);
    expect(transport.gatewayConnection, isNull);
    expect(gateway.requests, isEmpty);
    await transport.send(text: 'First', profile: 'work').toList();
    final binding = transport.ownedSessionFor('stored-1', profile: 'work')!;
    expect(transport.gatewayConnection, same(binding.connection));
    gateway.event('sessions.changed', 'unfollowed-runtime', {
      'hint': 'changed',
    });
    await pumpEventQueue();
    final hint = signals.singleWhere(
      (signal) => signal.event?.type == 'sessions.changed',
    );
    expect(hint.event!.sessionId, 'unfollowed-runtime');
    expect(hint.connection, same(binding.connection));
    expect(transport.ownsGatewayConnection(hint.connection), isTrue);
    gateway.drop();
    await pumpEventQueue();
    expect(transport.gatewayConnection, isNull);
    expect(transport.ownsGatewayConnection(hint.connection), isFalse);
    expect(signals.last.connected, isFalse);
  });

  test('resume projects only the decoded pending operation with confirmed runtime ownership', () async {
    final gateway = FakeGateway();
    gateway.turn = (g, sid) => g.event('message.complete', sid, {
      'text': 'Main',
      'status': 'complete',
    });
    final rawTarget =
        (connectionRequestFixture['targets'] as List).single
            as Map<String, Object?>;
    gateway.resumeResult = {
      'session_id': 'rt-1',
      'session_key': 'stored-1',
      'pending_connection': {
        ...connectionRequestFixture,
        'targets': [
          {
            ...rawTarget,
            'required_env': [
              {'name': 'TOKEN', 'default': 'PRIVATE-TOKEN'},
            ],
          },
        ],
      },
      'messages': ['Private transcript'],
    };
    final transport = HermesGatewayTransport(connect: gateway.connect);
    addTearDown(transport.close);
    final changes = <OwnedSessionChange>[];
    final subscription = transport.ownedSessions.listen(changes.add);
    addTearDown(subscription.cancel);
    await transport
        .send(threadId: 'stored-1', profile: 'work', text: 'Resume')
        .toList();
    final restored = changes
        .firstWhere(
          (change) =>
              change.resumeSnapshot?.containsKey('pending_connection') == true,
        )
        .resumeSnapshot!;
    expect(restored.keys, ['pending_connection']);
    final operation =
        restored['pending_connection']! as ConnectorOperationSnapshot;
    expect(operation.owner.sessionId, 'rt-1');
    expect(operation.toolCallId, 'synthetic-tool');
    expect(operation.targets.single.needsCredentials, isTrue);
    expect(restored.toString(), isNot(contains('PRIVATE-TOKEN')));
    expect(restored.toString(), isNot(contains('Private transcript')));
  });

  test('global account updates stay outside session streams with actual current-client identity', () async {
    final gateway = FakeGateway();
    gateway.turn = (g, sid) => g.event('message.complete', sid, {
      'text': 'Main',
      'status': 'complete',
    });
    final transport = HermesGatewayTransport(connect: gateway.connect);
    addTearDown(transport.close);
    final activity = <GatewayConnectionEvent>[];
    final subscription = transport.connectionEvents.listen(activity.add);
    addTearDown(subscription.cancel);
    final first = await transport.send(text: 'First', profile: 'work').toList();
    final binding = transport.ownedSessionFor('stored-1', profile: 'work')!;
    final follow = <ChatEvent>[];
    final following = transport
        .followUps('stored-1', profile: 'work')
        .listen(follow.add);
    addTearDown(following.cancel);
    gateway.event('connection.update', '', {
      ...connectionUpdateFixture,
      'owner': {'type': 'account'},
    });
    await pumpEventQueue();
    final account = activity.singleWhere(
      (signal) => signal.event?.type == 'connection.update',
    );
    expect(account.event!.sessionId, isEmpty);
    expect((account.event!.payload['owner'] as Map)['type'], 'account');
    expect(account.connection, same(binding.connection));
    expect(transport.ownsGatewayConnection(account.connection), isTrue);
    expect(first.whereType<ConnectorOperationReceived>(), isEmpty);
    expect(follow.whereType<ConnectorOperationReceived>(), isEmpty);
    gateway.drop();
    await pumpEventQueue();
    expect(activity.last.connected, isFalse);
    expect(transport.ownsGatewayConnection(binding.connection), isFalse);
  });

  test('connector responses use exact confirmed session/profile and only skipped or continue results', () async {
    final gateway = FakeGateway();
    gateway.turn = (g, sid) => g.event('message.complete', sid, {
      'text': 'Main',
      'status': 'complete',
    });
    gateway.handlers['connection.respond'] = (_) => {
      'status': 'ok',
      'settled': false,
    };
    final transport = HermesGatewayTransport(connect: gateway.connect);
    addTearDown(transport.close);
    await transport.send(text: 'First', profile: 'work').toList();
    final binding = transport.ownedSessionFor('stored-1', profile: 'work')!;
    final params = <String, Object?>{
      'owner': {'type': 'session', 'session_id': 'rt-1'},
      'op_id': 'operation',
      'profile': 'work',
      'result': {
        'targets': [
          {'name': 'connector', 'status': 'skipped'},
        ],
      },
    };
    await transport.respondToConnectorOperation(
      binding,
      params,
      authorize: () => true,
    );
    expect(gateway.requestOf('connection.respond')['params'], params);
    await expectLater(
      transport.respondToConnectorOperation(binding, {
        ...params,
        'profile': 'other',
      }, authorize: () => true),
      throwsArgumentError,
    );
    await expectLater(
      transport.respondToConnectorOperation(binding, {
        ...params,
        'result': {
          'targets': [
            {
              'name': 'connector',
              'status': 'approved',
              'env': {'TOKEN': 'PRIVATE'},
            },
          ],
        },
      }, authorize: () => true),
      throwsArgumentError,
    );
    expect(
      gateway.methods.where((method) => method == 'connection.respond'),
      hasLength(1),
    );
  });

  test(
    'authorization retired by request telemetry emits no operation mutation',
    () async {
      final gateway = FakeGateway();
      final tracer = _RetiringTracer();
      gateway.turn = (g, sid) => g.event('message.complete', sid, {
        'text': 'Main',
        'status': 'complete',
      });
      gateway.handlers['connection.respond'] = (_) => {
        'status': 'ok',
        'settled': false,
      };
      final transport = HermesGatewayTransport(
        connect: gateway.connect,
        telemetry: gatewayTracer(tracer),
      );
      addTearDown(transport.close);
      await transport.send(text: 'First', profile: 'work').toList();
      final binding = transport.ownedSessionFor('stored-1', profile: 'work')!;
      await expectLater(
        transport.respondToConnectorOperation(binding, {
          'owner': {'type': 'session', 'session_id': 'rt-1'},
          'op_id': 'operation',
          'profile': 'work',
          'result': {'targets': [], 'settled_by': 'continue'},
        }, authorize: () => tracer.authorized),
        throwsException,
      );
      expect(tracer.authorized, isFalse);
      expect(gateway.methods, isNot(contains('connection.respond')));
    },
  );
}

class _RetiringTracer extends RecordingTracer {
  bool authorized = true;
  @override
  Span startSpan(
    String name, {
    SpanKind kind = SpanKind.internal,
    Map<String, Object?>? attributes,
    SpanContext? parentContext,
    List<SpanLink> links = const [],
  }) {
    if (name == 'connection.respond send') authorized = false;
    return super.startSpan(
      name,
      kind: kind,
      attributes: attributes,
      parentContext: parentContext,
      links: links,
    );
  }
}
