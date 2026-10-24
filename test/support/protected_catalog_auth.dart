import 'package:hermes_app/src/api/hermes_api_client.dart';

import '../../widgetbook/catalog_auth.dart';
import 'fake_hermes_server.dart';

/// A [CatalogAuth] whose one client talks to [server] and is cleared for
/// protected requests, so screens that check the session (Memory) load.
class ProtectedCatalogAuth extends CatalogAuth {
  ProtectedCatalogAuth(FakeHermesServer server)
    : _client = server.client(),
      super(server: server, gated: true);

  final HermesApiClient _client;

  @override
  HermesApiClient? get api => _client;

  @override
  bool get protectedRequestsAllowed => true;
}
