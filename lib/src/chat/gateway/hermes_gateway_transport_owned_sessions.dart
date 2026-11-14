part of 'hermes_gateway_transport.dart';

/// Owned session bindings, connector operation answers and billing step-up.
extension _OwnedSessions on HermesGatewayTransport {
  Future<Map<String, Object?>> _stepUpBilling(
    OwnedSessionBinding binding, {
    required bool Function() authorize,
  }) async {
    if (!_ownsBinding(binding) ||
        !authorize() ||
        (binding.profile?.isEmpty ?? true)) {
      throw const GatewayConnectionClosed();
    }
    if (!billingVerificationSupported(binding)) {
      throw const GatewayRpcException(
        kGatewayMethodNotFound,
        'Billing verification unavailable',
      );
    }
    if (!_billingPending.add(binding)) {
      throw StateError('Billing verification already pending');
    }
    try {
      final client = binding.connection as GatewayRpcClient;
      final result = await client.requestGuarded('billing.step_up', {
        'session_id': binding.runtimeId,
        'profile': binding.profile,
      }, authorize: () => _ownsBinding(binding) && authorize());
      if (!_ownsBinding(binding)) throw const GatewayConnectionClosed();
      return result;
    } on GatewayRpcException catch (error) {
      if (error.code == kGatewayMethodNotFound) {
        _billingUnavailable.add(binding.connection);
      }
      rethrow;
    } finally {
      _billingPending.remove(binding);
    }
  }

  Future<Map<String, Object?>> _respondToConnectorOperation(
    OwnedSessionBinding binding,
    Map<String, Object?> params, {
    required bool Function() authorize,
  }) async {
    if (!_ownsBinding(binding) ||
        !authorize() ||
        (binding.profile?.isEmpty ?? true)) {
      throw const GatewayConnectionClosed();
    }
    final owner = params['owner'],
        result = params['result'],
        opId = params['op_id'];
    if (owner is! Map ||
        owner['type'] != 'session' ||
        owner['session_id'] != binding.runtimeId ||
        params['profile'] != binding.profile ||
        opId is! String ||
        opId.isEmpty ||
        result is! Map ||
        result.keys.any((key) => key != 'targets' && key != 'settled_by') ||
        result['targets'] is! List ||
        result.containsKey('settled_by') &&
            result['settled_by'] != 'continue') {
      throw ArgumentError('Unsupported connection response');
    }
    final rows = <Map<String, Object?>>[], names = <String>{};
    for (final target in result['targets'] as List) {
      if (target is! Map ||
          target['name'] is! String ||
          (target['name'] as String).isEmpty ||
          target['status'] != 'skipped' ||
          !names.add(target['name'] as String) ||
          target.keys.any((key) => key != 'name' && key != 'status')) {
        throw ArgumentError('Unsupported connection target response');
      }
      rows.add({'name': target['name'], 'status': 'skipped'});
    }
    if (rows.isEmpty && result['settled_by'] != 'continue') {
      throw ArgumentError('Empty connection response');
    }
    final client = binding.connection as GatewayRpcClient;
    final response = await client
        .requestGuarded('connection.respond', {
          'owner': {'type': 'session', 'session_id': binding.runtimeId},
          'op_id': opId,
          'profile': binding.profile,
          'result': {
            'targets': rows,
            if (result['settled_by'] == 'continue') 'settled_by': 'continue',
          },
        }, authorize: () => _ownsBinding(binding) && authorize())
        .timeout(requestTimeout);
    if (!_ownsBinding(binding)) throw const GatewayConnectionClosed();
    return response;
  }

  bool _ownsBinding(OwnedSessionBinding binding) =>
      !_closed &&
      identical(_connected(), binding.connection) &&
      _ownedBindings.values.contains(binding);

  void _establishOwned(
    _ThreadOwner owner,
    GatewayRpcClient client,
    String runtimeId,
  ) {
    final candidate = OwnedSessionBinding(
      connection: client,
      runtimeId: runtimeId,
      profile: owner.$1,
    );
    final current = _ownedBindings[owner];
    _ownedBindings[owner] = current == candidate ? current! : candidate;
  }

  void _loseOwned(
    GatewayRpcClient client,
    String runtimeId, {
    bool retired = false,
  }) {
    final lost = _ownedBindings.entries
        .where(
          (entry) =>
              identical(entry.value.connection, client) &&
              entry.value.runtimeId == runtimeId,
        )
        .toList();
    for (final entry in lost) {
      _ownedBindings.remove(entry.key);
      if (!_ownedSessions.isClosed) {
        _ownedSessions.add(
          OwnedSessionChange(
            entry.key.$2,
            entry.value,
            connected: false,
            retired: retired,
          ),
        );
      }
    }
  }

  Future<Map<String, Object?>> _readOwnedSession(
    OwnedSessionBinding binding,
    String method,
  ) async {
    if (method != 'session.usage') {
      throw UnsupportedError('Not an optional session read');
    }
    if (!_ownsBinding(binding)) throw const GatewayConnectionClosed();
    final client = binding.connection as GatewayRpcClient;
    final result = await client
        .request(method, {
          'session_id': binding.runtimeId,
          'profile': binding.profile,
        })
        .timeout(requestTimeout);
    if (!_ownsBinding(binding)) throw const GatewayConnectionClosed();
    return result;
  }

  void _notifyOwned(
    _ThreadOwner owner,
    _Watch watch, {
    bool connected = true,
    bool retired = false,
    Object? resumeToken,
    Map<String, Object?>? resumeSnapshot,
  }) {
    if (_ownedSessions.isClosed) return;
    final binding = OwnedSessionBinding(
      connection: watch.client,
      runtimeId: watch.runtimeId,
      profile: owner.$1,
    );
    if (connected && !_ownsBinding(binding)) return;
    _ownedSessions.add(
      OwnedSessionChange(
        owner.$2,
        OwnedSessionBinding(
          connection: watch.client,
          runtimeId: watch.runtimeId,
          profile: owner.$1,
        ),
        connected: connected,
        retired: retired,
        resumeToken: resumeToken,
        resumeSnapshot: resumeSnapshot,
      ),
    );
  }

  Object? _beginResume(_ThreadOwner owner) {
    final binding = ownedSessionFor(owner.$2, profile: owner.$1);
    if (binding == null || _ownedSessions.isClosed) return null;
    final token = Object();
    _ownedSessions.add(
      OwnedSessionChange(owner.$2, binding, resuming: true, resumeToken: token),
    );
    return token;
  }

  Map<String, Object?>? _resumeSnapshot(
    Map<String, Object?> result, {
    required String runtimeId,
  }) {
    final snapshot = <String, Object?>{
      if (result.containsKey('todo_state')) 'todo_state': result['todo_state'],
      if (result.containsKey('pending_connection'))
        'pending_connection': ConnectorOperationSnapshot.fromPending(
          result['pending_connection'],
          runtimeId: runtimeId,
        ),
    };
    return snapshot.isEmpty ? null : Map.unmodifiable(snapshot);
  }
}
