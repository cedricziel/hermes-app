import 'dart:async';

import 'gateway/gateway_rpc_client.dart';

class GatewayConnectionEvent {
  const GatewayConnectionEvent.received(this.connection, this.event)
    : connected = true;
  const GatewayConnectionEvent.lost(this.connection)
    : connected = false,
      event = null;
  final Object connection;
  final GatewayEvent? event;
  final bool connected;
}

abstract interface class GatewayConnectionTransport {
  /// Raw notifications before runtime filtering, tagged with their physical client.
  Stream<GatewayConnectionEvent> get connectionEvents;

  /// Reads the current client token without opening or resuming a connection.
  Object? get gatewayConnection;
  bool ownsGatewayConnection(Object connection);
}
