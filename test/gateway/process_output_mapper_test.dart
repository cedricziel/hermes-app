import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/gateway_event_mapper.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';

void main() {
  test(
    'pinned process events preserve output and close without exit inference',
    () {
      final connection = Object();
      final mapped = mapGatewayEvent(
        GatewayEvent(
          type: 'agent.terminal.output',
          sessionId: 'runtime',
          payload: {'process_id': 'worker', 'chunk': 'Reported chunk'},
        ),
        connection: connection,
      );
      expect(mapped, isNotNull);
      final output = mapped! as ProcessOutputReceived;
      expect(output.update.chunk, 'Reported chunk');
      expect(output.runtimeId, 'runtime');
      expect(output.connection, same(connection));
      final closed =
          mapGatewayEvent(
                GatewayEvent(
                  type: 'terminal.close',
                  sessionId: 'runtime',
                  payload: {'process_id': 'worker'},
                ),
                connection: connection,
              )!
              as ProcessOutputReceived;
      expect(closed.update.closed, isTrue);
      expect(closed.update.chunk, isNull);
    },
  );
  test(
    'missing identity, malformed chunks and ownerless output stay optional',
    () {
      expect(
        mapGatewayEvent(
          GatewayEvent(
            type: 'agent.terminal.output',
            sessionId: 'runtime',
            payload: {'chunk': 'No process'},
          ),
        ),
        isNull,
      );
      expect(
        mapGatewayEvent(
          GatewayEvent(
            type: 'agent.terminal.output',
            sessionId: 'runtime',
            payload: {'process_id': 'worker', 'chunk': 4},
          ),
        ),
        isNull,
      );
      expect(
        mapGatewayEvent(
          GatewayEvent(
            type: 'terminal.close',
            sessionId: 'runtime',
            payload: {'process_id': ''},
          ),
        ),
        isNull,
      );
      expect(
        mapGatewayEvent(
          GatewayEvent(
            type: 'agent.terminal.output',
            sessionId: '',
            payload: {'process_id': 'worker', 'chunk': 'No owner'},
          ),
        ),
        isNull,
      );
    },
  );
}
