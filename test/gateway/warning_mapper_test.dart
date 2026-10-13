import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/gateway/gateway_event_mapper.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';

void main() {
  test('malformed optional warning payloads cannot break the mapper', () {
    expect(
      mapGatewayEvent(
        const GatewayEvent(
          type: 'tool.output_risk',
          sessionId: 's',
          payload: {
            'tool_id': 't',
            'risk': 'secret',
            'findings': 'not a list',
            'redacted': true,
          },
        ),
      ),
      isNull,
    );
    expect(
      mapGatewayEvent(
        const GatewayEvent(
          type: 'notification.show',
          sessionId: 's',
          payload: {'text': 42},
        ),
      ),
      isNull,
    );
    expect(
      mapGatewayEvent(
        const GatewayEvent(
          type: 'notification.clear',
          sessionId: 's',
          payload: {'key': []},
        ),
      ),
      isNull,
    );
  });
  test('gateway warnings reach the owning session instead of disappearing', () {
    final risk = mapGatewayEvent(
      const GatewayEvent(
        type: 'tool.output_risk',
        sessionId: 'session-a',
        payload: {
          'tool_id': 'tool-a',
          'name': 'terminal',
          'risk': 'secret',
          'findings': ['Output contains a credential'],
          'redacted': true,
        },
      ),
    );
    final notice = mapGatewayEvent(
      const GatewayEvent(
        type: 'notification.show',
        sessionId: 'session-a',
        payload: {
          'text': 'Credits are low',
          'level': 'warn',
          'kind': 'sticky',
          'key': 'credit',
        },
      ),
    );
    expect(risk, isNotNull);
    expect(notice, isNotNull);
  });
}
