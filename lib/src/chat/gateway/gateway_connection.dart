import 'package:dart_otel_instrumentation_messaging/dart_otel_instrumentation_messaging.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../api/hermes_api_client.dart';
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

/// Opens a WebSocket to [uri] once the server has accepted the upgrade.
Future<StreamChannel<String>> openWebSocket(Uri uri) async {
  final channel = WebSocketChannel.connect(uri);
  await channel.ready;
  return channel.cast<String>();
}

/// Opens a WebSocket to a dashboard [path], optionally with extra [query]
/// parameters beside the credential.
typedef SocketConnect = Future<StreamChannel<String>> Function([
  Map<String, String> query,
]);

/// Opens a WebSocket to [uri] that carries both text and binary frames, as
/// the dashboard's audio sockets do.
Future<StreamChannel<Object?>> openMixedWebSocket(Uri uri) async {
  final channel = WebSocketChannel.connect(uri);
  await channel.ready;
  return channel.cast<Object?>();
}

/// Opens a dashboard WebSocket whose frames are text or bytes.
typedef MixedSocketConnect = Future<StreamChannel<Object?>> Function([
  Map<String, String> query,
]);

/// Builds the URL of a dashboard WebSocket at [path] with a fresh credential:
/// a single-use ticket when the dashboard is gated ([authRequired]), else the
/// page's session token. Credentials are fetched per connection, since a
/// ticket works only once.
Future<Uri> Function([Map<String, String> query]) _dashboardSocketUri({
  required String baseUrl,
  required bool authRequired,
  required HermesApiClient api,
  required String path,
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

  return ([query = const {}]) async =>
      gatewayUri(baseUrl, {...query, ...await credential()}, path: path);
}

/// Connects to a dashboard WebSocket of text frames.
SocketConnect hermesSocketConnect({
  required String baseUrl,
  required bool authRequired,
  required HermesApiClient api,
  String path = '/api/ws',
  MessagingConnectionTracer? telemetry,
  Future<StreamChannel<String>> Function(Uri uri) open = openWebSocket,
}) {
  final socketUri = _dashboardSocketUri(
    baseUrl: baseUrl,
    authRequired: authRequired,
    api: api,
    path: path,
  );
  return ([query = const {}]) async {
    final uri = await socketUri(query);
    return telemetry == null
        ? open(uri)
        : telemetry.connecting(() => open(uri), route: path);
  };
}

/// Connects to a dashboard WebSocket of text and binary frames, such as
/// `/api/audio/transcribe-stream`.
MixedSocketConnect hermesMixedSocketConnect({
  required String baseUrl,
  required bool authRequired,
  required HermesApiClient api,
  required String path,
  Future<StreamChannel<Object?>> Function(Uri uri) open = openMixedWebSocket,
}) {
  final socketUri = _dashboardSocketUri(
    baseUrl: baseUrl,
    authRequired: authRequired,
    api: api,
    path: path,
  );
  return ([query = const {}]) async => open(await socketUri(query));
}

/// Connects to the dashboard's chat gateway (`/api/ws`).
GatewayConnect hermesGatewayConnect({
  required String baseUrl,
  required bool authRequired,
  required HermesApiClient api,
  MessagingConnectionTracer? telemetry,
  Future<StreamChannel<String>> Function(Uri uri) open = openWebSocket,
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
