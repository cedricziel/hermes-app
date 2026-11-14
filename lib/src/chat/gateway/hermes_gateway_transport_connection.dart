part of 'hermes_gateway_transport.dart';

/// The connection: calls, probes, opening it, and server request handlers.
extension _Connection on HermesGatewayTransport {
  /// Sends [method] and gives up on a gateway that does not answer: the
  /// connection is dropped, so the next send opens a new one.
  Future<Map<String, Object?>> _call(
    GatewayRpcClient client,
    String method,
    Map<String, Object?> params, {
    bool Function()? authorize,
  }) async {
    try {
      final request = authorize == null
          ? client.request(method, params)
          : client.requestGuarded(method, params, authorize: authorize);
      return await request.timeout(requestTimeout);
    } on TimeoutException {
      _drop(client);
      throw const GatewayConnectionClosed();
    }
  }

  /// Forgets [client] and closes it. Not awaited: closing a channel whose peer
  /// has left can wait forever, and a failure to close is of no use to anyone.
  void _drop(GatewayRpcClient client) {
    if (_open == client) _open = null;
    unawaited(client.close().catchError((Object _) {}));
  }

  Future<bool> _alive(GatewayRpcClient client) =>
      _probes[client] ??= client.isResponsive(probeTimeout).whenComplete(() {
        // A block body: returning the removed future would wait on itself.
        _probes.remove(client);
      });

  /// The open connection, or null. The gateway matches a server-to-client
  /// answer by its request id on any connection, so after a reconnect the
  /// answer goes out on the new socket, the one open now.
  GatewayRpcClient? _connected() {
    final open = _open;
    return open == null || open.isClosed ? null : open;
  }

  Future<GatewayRpcClient> _client() async {
    if (_closed) throw const GatewayConnectionClosed();
    final open = _connected();
    if (open != null && open.isStale && !await _alive(open)) {
      // Nothing was pinging it, so a socket the OS dropped meanwhile would
      // fail the send after the request timeout.
      _drop(open);
    }
    final current = _connected();
    if (current != null) return current;
    return _opening ??= _openNew().whenComplete(() => _opening = null);
  }

  Future<StreamChannel<String>> _connectBounded() {
    final pending = _connect();
    return pending.timeout(
      connectTimeout,
      onTimeout: () {
        // A channel that opens after the deadline would otherwise leak.
        unawaited(
          pending.then(
            (channel) => channel.sink.close(),
            onError: (Object _) {},
          ),
        );
        throw const GatewayConnectionClosed();
      },
    );
  }

  Future<GatewayRpcClient> _openNew() async {
    // With the heartbeat, a socket the OS dropped while the app slept closes
    // itself once it goes quiet, and the reply in flight reconnects.
    final channel = await _connectBounded();
    if (_closed) {
      // close() ran while the socket was opening; nothing would close it.
      unawaited(channel.sink.close());
      throw const GatewayConnectionClosed();
    }
    final client = GatewayRpcClient(
      channel,
      telemetry: _telemetry,
      heartbeat: true,
    );
    // Not awaited: a gateway that predates the call answers with an error and
    // carries on with events, and none of them may hold up the first send.
    unawaited(
      client
          .request('client.capabilities', {'server_requests': true})
          .then((_) {}, onError: (Object _) {}),
    );
    // Another client attached to a session may answer its requests, and the
    // first response settles one for all of them: only refuse those of a
    // session this app is replying in.
    final unmapped = _unmapped = UnmappedEvents();
    client.serverRequests
        .where((request) => !handledServerRequests.contains(request.method))
        .listen((request) {
          if (_requestHandlers[request.method] case final handler?) {
            unawaited(_answerWithHandler(client, request, handler));
            return;
          }
          _reportUnmapped(request.method, serverRequest: true, on: unmapped);
          if (registrableServerRequests.contains(request.method) ||
              _replying.containsKey(request.sessionId)) {
            client.respondError(
              request.id,
              kGatewayMethodNotFound,
              'Method not found',
            );
          }
        });
    client.events.listen(
      (event) {
        if (!_connectionEvents.isClosed && ownsGatewayConnection(client)) {
          _connectionEvents.add(GatewayConnectionEvent.received(client, event));
        }
      },
      onDone: () {
        if (!_connectionEvents.isClosed) {
          _connectionEvents.add(GatewayConnectionEvent.lost(client));
        }
      },
    );
    _billingUnavailable.clear();
    return _open = client;
  }

  Future<void> _answerWithHandler(
    GatewayRpcClient client,
    GatewayServerRequest request,
    ServerRequestHandler handler,
  ) async {
    try {
      client.respond(request.id, await handler(request, client));
    } on GatewayRpcException catch (error) {
      client.respondError(request.id, error.code, error.message);
    } on Object {
      client.respondError(request.id, -32603, 'Internal error');
    }
  }

  ChatEvent? _fromServerRequest(GatewayServerRequest request) {
    return switch (request.method) {
      'approval' => ApprovalRequested(toApproval(request.id, request.params)),
      'clarify' => ClarifyRequested(toClarify(request.id, request.params)),
      'vault.save_login' => _vault(
        request.id,
        VaultKind.saveLogin,
        request.params,
      ),
      'vault.unlock_prompt' => _vault(
        request.id,
        VaultKind.unlock,
        request.params,
      ),
      'vault.code' => _vault(request.id, VaultKind.code, request.params),
      'sudo' => unsupportedRequest(request.id, UnsupportedKind.sudo),
      'secret' => unsupportedRequest(request.id, UnsupportedKind.secret),
      _ => null,
    };
  }

  /// A masked vault prompt: the login to save for a site, an external
  /// password manager's master password, or a one-time code.
  VaultRequested _vault(
    String requestId,
    VaultKind kind,
    Map<String, Object?> fields,
  ) => VaultRequested(
    VaultRequest(
      requestId: requestId,
      kind: kind,
      origin: fields['origin'] as String? ?? '',
      site: fields['site'] as String? ?? '',
      backend: fields['backend'] as String? ?? '',
      displayName: fields['display_name'] as String? ?? '',
      hint: fields['hint'] as String? ?? '',
    ),
  );
}
