import 'gateway_connection_transport.dart';
import 'owned_session_transport.dart';

abstract interface class ConnectorOperationTransport
    implements GatewayConnectionTransport {
  Future<Map<String, Object?>> respondToConnectorOperation(
    OwnedSessionBinding binding,
    Map<String, Object?> params, {
    required bool Function() authorize,
  });
}
