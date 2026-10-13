import 'dart:async';

import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/chat/gateway_connection_transport.dart';

class FakeChangeFeed implements GatewayConnectionTransport {
  final frames = StreamController<GatewayConnectionEvent>.broadcast(sync: true);
  Object? current = Object();
  @override
  Stream<GatewayConnectionEvent> get connectionEvents => frames.stream;
  @override
  Object? get gatewayConnection => current;
  @override
  bool ownsGatewayConnection(Object connection) =>
      identical(current, connection);
  void hint(String type, {Object? connection}) => frames.add(
    GatewayConnectionEvent.received(
      connection ?? current!,
      GatewayEvent(type: type, sessionId: '', payload: const {}),
    ),
  );
  Future<void> close() => frames.close();
}
