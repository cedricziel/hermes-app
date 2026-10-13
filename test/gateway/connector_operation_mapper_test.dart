import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/gateway_event_mapper.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';

import '../chat/connector_fixtures.dart';

void main() {
  test(
    'session requests derive owner only from their actual runtime envelope',
    () {
      final client = Object();
      final event = mapGatewayEvent(
        GatewayEvent(
          type: 'connection.request',
          sessionId: 'runtime-a',
          payload: connectionRequestFixture,
        ),
        connection: client,
      );
      expect(event, isNotNull);
      final request = event! as ConnectorOperationReceived;
      expect(request.operation.owner.sessionId, 'runtime-a');
      expect(request.connection, same(client));
      expect(request.operation.timeoutSeconds, 60);
    },
  );
  test('session updates retain explicit owner while account updates remain globally scoped', () {
    final client = Object();
    final event = mapGatewayEvent(
      GatewayEvent(
        type: 'connection.update',
        sessionId: 'runtime-a',
        payload: connectionUpdateFixture,
      ),
      connection: client,
    );
    expect(event, isNotNull);
    final update = event! as ConnectorOperationReceived;
    expect(update.operation.seq, 4);
    expect(update.operation.owner.sessionId, 'runtime-a');
    final global = mapGatewayEvent(
      GatewayEvent(
        type: 'connection.update',
        sessionId: '',
        payload: {
          ...connectionUpdateFixture,
          'owner': {'type': 'account'},
        },
      ),
      connection: client,
    );
    expect(global, isNotNull);
    final account = global! as ConnectorOperationReceived;
    expect(account.runtimeId, isEmpty);
    expect(account.operation.owner.type, 'account');
    expect(account.connection, same(client));
  });
  test('mismatched session owners and malformed operation payloads cannot borrow a selected owner', () {
    expect(
      mapGatewayEvent(
        GatewayEvent(
          type: 'connection.update',
          sessionId: 'runtime-other',
          payload: connectionUpdateFixture,
        ),
      ),
      isNull,
    );
    expect(
      mapGatewayEvent(
        GatewayEvent(
          type: 'connection.request',
          sessionId: '',
          payload: connectionRequestFixture,
        ),
      ),
      isNull,
    );
    expect(
      mapGatewayEvent(
        GatewayEvent(
          type: 'connection.update',
          sessionId: 'runtime-a',
          payload: {
            ...connectionUpdateFixture,
            'owner': {'type': 'account'},
          },
        ),
      ),
      isNull,
    );
    expect(
      mapGatewayEvent(
        GatewayEvent(
          type: 'connection.request',
          sessionId: 'runtime-a',
          payload: {...connectionRequestFixture, 'seq': 'one'},
        ),
      ),
      isNull,
    );
  });
}
