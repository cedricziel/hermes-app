import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/gateway_event_mapper.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';

import '../chat/billing_fixtures.dart';

void main() {
  test('exact billing verification payload retains actual runtime and physical client', () {
    final connection = Object();
    final mapped = mapGatewayEvent(
      GatewayEvent(
        type: 'billing.step_up.verification',
        sessionId: 'actual-runtime',
        payload: billingVerificationFixture,
      ),
      connection: connection,
    );
    expect(mapped, isA<BillingVerificationReceived>());
    final event = mapped! as BillingVerificationReceived;
    expect(event.runtimeId, 'actual-runtime');
    expect(event.connection, same(connection));
    expect(event.details.userCode, 'PRIVATE-CODE');
    expect(event.details.browserUri!.host, 'billing.invalid');
  });
  test(
    'malformed, missing runtime, and invented aliases have no billing event',
    () {
      for (final frame in [
        GatewayEvent(
          type: 'billing.step_up.verification',
          sessionId: '',
          payload: billingVerificationFixture,
        ),
        GatewayEvent(
          type: 'billing.step_up.verification',
          sessionId: 'runtime',
          payload: {'user_code': 'code'},
        ),
        GatewayEvent(
          type: 'billing.verification',
          sessionId: 'runtime',
          payload: billingVerificationFixture,
        ),
      ]) {
        expect(mapGatewayEvent(frame, connection: Object()), isNull);
      }
    },
  );
}
