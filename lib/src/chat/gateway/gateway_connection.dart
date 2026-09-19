import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../api/hermes_api_client.dart';
import 'hermes_gateway_transport.dart';

/// The `/api/ws` URL for the dashboard at [baseUrl], with the credential
/// [query] (`token` or `ticket`).
Uri gatewayUri(String baseUrl, Map<String, String> query) {
  final base = Uri.parse(baseUrl);
  return base.replace(
    scheme: base.scheme == 'https' ? 'wss' : 'ws',
    path: '${base.path}/api/ws',
    queryParameters: query,
  );
}

Future<StreamChannel<String>> _openWebSocket(Uri uri) async {
  final channel = WebSocketChannel.connect(uri);
  await channel.ready;
  return channel.cast<String>();
}

/// Connects to the dashboard's gateway: with a single-use ticket when the
/// dashboard is gated ([authRequired]), else with the page's session token.
/// Credentials are fetched per connection, since a ticket works only once.
GatewayConnect hermesGatewayConnect({
  required String baseUrl,
  required bool authRequired,
  required HermesApiClient api,
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

  return () async => open(gatewayUri(baseUrl, await credential()));
}
