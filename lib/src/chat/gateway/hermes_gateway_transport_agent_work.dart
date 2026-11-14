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
    final owner = (profile, threadId);
    final binding = ownedSessionFor(threadId, profile: profile);
    final GatewayRpcClient client;
    final String runtimeId;
    if (binding != null) {
      client = binding.connection as GatewayRpcClient;
      runtimeId = binding.runtimeId;
    } else {
      // Not attached on the current connection, whatever an earlier
      // connection knew: attach it, as the server only honours its holder.
      // Actions started together share one resume.
      try {
        (
          client,
          runtimeId,
        ) = await (_agentResumes[owner] ??= _attachForAgent(owner).whenComplete(
          () {
            // A block body: returning the removed future would wait on itself.
            _agentResumes.remove(owner);
          },
        ));
      } on Object catch (error) {
        throw AgentActionNotSent(error);
      }
    }
    return client.requestWithin(method, {
      ...params,
      'session_id': runtimeId,
    }, timeout: timeout);
  }

  /// Resumes the session on the current connection and records it as held
  /// here, so reads that follow (the re-read after a stop) see it attached.
  /// A resume that gets no answer abandons the call and keeps the socket.
  Future<(GatewayRpcClient, String)> _attachForAgent(_ThreadOwner owner) async {
    final client = await _client();
    final session = await client.requestWithin('session.resume', {
      'session_id': owner.$2,
      'profile': ?owner.$1,
      'source': gatewaySessionSource,
    }, timeout: requestTimeout);
    final id = session['session_id'];
    if (id is! String || id.isEmpty) throw StateError('No runtime session');
    if (_connected() == client) _establishOwned(owner, client, id);
    return (client, id);
  }
}
