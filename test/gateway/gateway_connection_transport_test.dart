import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/gateway_connection_transport.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/chat/session_chat_transport.dart';

import '../support/fake_gateway.dart';

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

  test(
    'session suspension revokes raw connection token and parked delivery',
    () async {
      final gateway = FakeGateway();
      gateway.turn = (g, sid) => g.event('message.complete', sid, {
        'text': 'Main',
        'status': 'complete',
      });
      final transport = SessionChatTransport(
        () => HermesGatewayTransport(connect: gateway.connect),
      );
      addTearDown(transport.close);
      final events = <GatewayConnectionEvent>[];
      final errors = <Object>[];
      final subscription = transport.connectionEvents.listen(
        events.add,
        onError: errors.add,
      );
      addTearDown(subscription.cancel);
      await transport.send(text: 'First', profile: 'work').toList();
      final token = transport.gatewayConnection!;
      subscription.pause();
      gateway.event('sessions.changed', '', const {});
      await pumpEventQueue();
      final suspended = transport.suspend();
      expect(transport.gatewayConnection, isNull);
      expect(transport.ownsGatewayConnection(token), isFalse);
      subscription.resume();
      await suspended;
      await pumpEventQueue();
      expect(
        events.where((event) => event.event?.type == 'sessions.changed'),
        isEmpty,
      );
      expect(errors.single, isA<SessionTransportUnavailable>());
    },
  );
}
