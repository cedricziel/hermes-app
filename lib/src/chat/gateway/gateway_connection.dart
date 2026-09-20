import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../api/hermes_api_client.dart';
import '../../telemetry/gateway_telemetry.dart';
import 'hermes_gateway_transport.dart';

/// The WebSocket URL of [path] (the gateway's `/api/ws` unless told
/// otherwise) on the dashboard at [baseUrl], with the credential [query]
/// (`token` or `ticket`).
Uri gatewayUri(
  String baseUrl,
  Map<String, String> query, {
  String path = '/api/ws',
}) {
  final base = Uri.parse(baseUrl);
  return base.replace(
    scheme: base.scheme == 'https' ? 'wss' : 'ws',
    path: '${base.path}$path',
    queryParameters: query,
  );
}

Future<StreamChannel<String>> _openWebSocket(Uri uri) async {
  final channel = WebSocketChannel.connect(uri);
  await channel.ready;
  return channel.cast<String>();
}

/// Opens a WebSocket to a dashboard [path], optionally with extra [query]
/// parameters beside the credential.
typedef SocketConnect = Future<StreamChannel<String>> Function([
  Map<String, String> query,
]);

/// Connects to a dashboard WebSocket: with a single-use ticket when the
/// dashboard is gated ([authRequired]), else with the page's session token.
/// Credentials are fetched per connection, since a ticket works only once.
SocketConnect hermesSocketConnect({
  required String baseUrl,
  required bool authRequired,
  required HermesApiClient api,
  String path = '/api/ws',
  GatewayTelemetry? telemetry,
  Future<StreamChannel<String>> Function(Uri uri) open = _openWebSocket,
}) {
  Future<Map<String, String>> credential() async {
    if (authRequired) {
      final response = await api.raw.authWsTicketApiAuthWsTicketPost();
      return {'ticket': (response.data as Map)['ticket'] as String};
    }
    final token = await api.fetchSessionToken();
    if (token == null) {
      throw StateError('The dashboard page carries no session token');
    }
    return {'token': token};
  }

  return ([query = const {}]) async {
    final uri = gatewayUri(baseUrl, {
      ...query,
      ...await credential(),
    }, path: path);
    return telemetry == null
        ? open(uri)
        : telemetry.connecting(() => open(uri), route: path);
  };
}

/// Connects to the dashboard's chat gateway (`/api/ws`).
GatewayConnect hermesGatewayConnect({
  required String baseUrl,
  required bool authRequired,
  required HermesApiClient api,
  GatewayTelemetry? telemetry,
  Future<StreamChannel<String>> Function(Uri uri) open = _openWebSocket,
}) {
  final connect = hermesSocketConnect(
    baseUrl: baseUrl,
    authRequired: authRequired,
    api: api,
    telemetry: telemetry,
    open: open,
  );
  return () => connect();
}
