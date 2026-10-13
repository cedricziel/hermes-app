import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/gateway_event_mapper.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';

void main() {
  test('control updates remain separate from assistant completion', () {
    final event = mapGatewayEvent(
      const GatewayEvent(
        type: 'session.control.update',
        sessionId: 'runtime-a',
        payload: {
          'control': {
            'goal': null,
            'loop': null,
            'heartbeat': null,
            'revision': 'opaque',
            'updated_at': 123,
          },
        },
      ),
    );
    expect(event, isNotNull);
    expect(event, isNot(isA<ReplyCompleted>()));
  });

  test('process waits and empty clears are observable session events', () {
    expect(
      mapGatewayEvent(
        const GatewayEvent(
          type: 'status.update',
          sessionId: 'runtime-a',
          payload: {'kind': 'process', 'text': 'Waiting for process'},
        ),
      ),
      isNotNull,
    );
    expect(
      mapGatewayEvent(
        const GatewayEvent(
          type: 'status.update',
          sessionId: 'runtime-a',
          payload: {'kind': 'process', 'text': ''},
        ),
      ),
      isNotNull,
    );
  });

  test('broadcast reclaim identifies the payload owner', () {
    expect(
      mapGatewayEvent(
        const GatewayEvent(
          type: 'session.reclaimed',
          sessionId: '',
          payload: {
            'session_id': 'runtime-a',
            'stored_session_id': 'stored-a',
            'reason': 'Another client reopened this session',
          },
        ),
      ),
      isNotNull,
    );
  });

  test('resume progress is distinct from turn settlement', () {
    expect(
      mapGatewayEvent(
        const GatewayEvent(
          type: 'session.resume_progress',
          sessionId: 'runtime-a',
          payload: {'phase': 'history', 'status': 'loading'},
        ),
      ),
      isNotNull,
    );
  });

  test('malformed optional control and status payloads cannot break chat', () {
    expect(
      mapGatewayEvent(
        const GatewayEvent(
          type: 'session.control.update',
          sessionId: 'runtime-a',
          payload: {'control': 'invalid'},
        ),
      ),
      isNull,
    );
    expect(
      mapGatewayEvent(
        const GatewayEvent(
          type: 'status.update',
          sessionId: 'runtime-a',
          payload: {'kind': 42, 'text': []},
        ),
      ),
      isNull,
    );
  });
}
