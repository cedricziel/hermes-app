part of 'hermes_gateway_transport.dart';

/// Reads and actions on a session's subagents, over the connection that holds it.
extension _AgentWork on HermesGatewayTransport {
  Future<Map<String, Object?>?> _readAttached(
    String threadId, {
    String? profile,
    required String method,
    required Map<String, Object?> params,
    required Duration timeout,
  }) async {
    if (!kAgentReadMethods.contains(method)) {
      throw ArgumentError.value(method, 'method', 'not an agent read');
    }
    final binding = ownedSessionFor(threadId, profile: profile);
    if (binding == null) return null;
    final result = await (binding.connection as GatewayRpcClient).requestWithin(
      method,
      {...params, 'session_id': binding.runtimeId},
      timeout: timeout,
    );
    // An answer from a connection that was replaced meanwhile is not about
    // the session this caller holds now.
    if (!_ownsBinding(binding)) throw const GatewayConnectionClosed();
    return result;
  }

  Future<Map<String, Object?>> _actOnAgent(
    String threadId, {
    String? profile,
    required String method,
    required Map<String, Object?> params,
    required Duration timeout,
  }) async {
    if (!kAgentActionMethods.contains(method)) {
      throw ArgumentError.value(method, 'method', 'not an agent action');
    }
    final binding = ownedSessionFor(threadId, profile: profile);
    final GatewayRpcClient client;
    final String runtimeId;
    if (binding != null) {
      client = binding.connection as GatewayRpcClient;
      runtimeId = binding.runtimeId;
    } else {
      // Not attached on the current connection, whatever an earlier
      // connection knew: attach it, as the server only honours its holder.
      client = await _client();
      final session = await _call(client, 'session.resume', {
        'session_id': threadId,
        'profile': ?profile,
        'source': gatewaySessionSource,
      });
      final id = session['session_id'];
      if (id is! String || id.isEmpty) throw StateError('No runtime session');
      runtimeId = id;
    }
    return client.requestWithin(method, {
      ...params,
      'session_id': runtimeId,
    }, timeout: timeout);
  }
}
