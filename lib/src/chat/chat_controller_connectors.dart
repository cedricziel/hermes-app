part of 'chat_controller.dart';

/// Session and account connector operations and their connection lifetime.
extension _ChatControllerConnectors on ChatController {
  ConnectorOperationController? _connectorOperationsInImpl(ChatThread thread) {
    final owner = (_profile, thread.id), source = transport;
    final controller = _connectorOperations[owner],
        binding = _connectorBindings[owner];
    return active &&
            _threads.contains(thread) &&
            source is OwnedSessionTransport &&
            binding != null &&
            controller != null &&
            controller.hasScope(binding) &&
            (source as OwnedSessionTransport).ownedSessionFor(
                  thread.id,
                  profile: _profile,
                ) ==
                binding
        ? controller
        : null;
  }

  ConnectorOperationController? get _connectionOperationsImpl {
    final source = transport,
        connection = _connectorConnection,
        controller = _connectionOperations;
    return active &&
            source is GatewayConnectionTransport &&
            connection != null &&
            controller != null &&
            controller.hasScope(connection) &&
            (source as GatewayConnectionTransport).ownsGatewayConnection(
              connection,
            )
        ? controller
        : null;
  }

  void _removeConnector((String?, String) owner) {
    _connectorBindings.remove(owner);
    _connectorOperations.remove(owner)?.dispose();
  }

  void _clearConnectionOperations() {
    _connectionOperations?.dispose();
    _connectionOperations = null;
    _connectorConnection = null;
  }

  void _clearConnectors() {
    _connectorActivityGeneration++;
    _cancelConnectorActivitySubscription();
    for (final controller in _connectorOperations.values) {
      controller.dispose();
    }
    _connectorOperations.clear();
    _connectorBindings.clear();
    _clearConnectionOperations();
  }

  bool _currentConnector(
    (String?, String) owner,
    ConnectorOperationController controller,
    OwnedSessionBinding binding,
    int epoch,
  ) {
    final source = transport;
    return _currentActivity(epoch) &&
        _profile == owner.$1 &&
        identical(_connectorOperations[owner], controller) &&
        _connectorBindings[owner] == binding &&
        controller.hasScope(binding) &&
        source is OwnedSessionTransport &&
        (source as OwnedSessionTransport).ownedSessionFor(
              owner.$2,
              profile: owner.$1,
            ) ==
            binding;
  }

  ConnectorOperationController _adoptConnector(
    (String?, String) owner,
    OwnedSessionBinding binding,
  ) {
    final existing = _connectorOperations[owner];
    if (existing != null &&
        _connectorBindings[owner] == binding &&
        existing.hasScope(binding)) {
      return existing;
    }
    _removeConnector(owner);
    final source = transport, epoch = _activityEpoch;
    final authorized =
        (binding.profile?.isNotEmpty ?? false) &&
        source is ConnectorOperationTransport;
    late final ConnectorOperationController controller;
    bool current() =>
        _currentConnector(owner, controller, binding, epoch) &&
        _threads.any((thread) => thread.id == owner.$2);
    controller = ConnectorOperationController(
      now: _clock,
      events: events,
      breadcrumbs: breadcrumbs,
      openBrowser: (uri) async {
        if (!authorized || !current()) return false;
        return connectorBrowser?.call(uri) ??
            launchUrl(uri, mode: LaunchMode.externalApplication);
      },
    );
    _connectorBindings[owner] = binding;
    _connectorOperations[owner] = controller;
    controller.bind(
      binding,
      profile: binding.profile,
      actionsAllowed: authorized,
      respond: authorized
          ? (params) async {
              final operation = controller.operations
                  .where(
                    (operation) =>
                        operation.opId == params['op_id'] &&
                        operation.owner.type == 'session' &&
                        operation.owner.sessionId == binding.runtimeId,
                  )
                  .firstOrNull;
              bool allowed() =>
                  current() &&
                  operation != null &&
                  controller.pendingResponseIsCurrent(
                    operation,
                    attachment: binding,
                  );
              if (!allowed()) throw const ConnectorResponseCanceled();
              try {
                return await (source as ConnectorOperationTransport)
                    .respondToConnectorOperation(
                      binding,
                      params,
                      authorize: allowed,
                    );
              } on GatewayConnectionClosed {
                if (!allowed()) throw const ConnectorResponseCanceled();
                rethrow;
              }
            }
          : null,
    );
    controller.addListener(notifyListeners);
    return controller;
  }

  void _onConnectorOwnership(OwnedSessionChange change, int epoch) {
    final owner = (change.binding.profile, change.threadId);
    if (!change.connected) {
      if (_connectorBindings[owner] == change.binding) {
        _removeConnector(owner);
        notifyListeners();
      }
      if (identical(_connectorConnection, change.binding.connection)) {
        _clearConnectionOperations();
        notifyListeners();
      }
      return;
    }
    final source = transport;
    if (source is! OwnedSessionTransport ||
        (source as OwnedSessionTransport).ownedSessionFor(
              owner.$2,
              profile: owner.$1,
            ) !=
            change.binding) {
      return;
    }
    final controller = _adoptConnector(owner, change.binding);
    if (!_currentConnector(owner, controller, change.binding, epoch)) return;
    final pending = change.resumeSnapshot?['pending_connection'];
    if (pending is ConnectorOperationSnapshot &&
        pending.owner.type == 'session' &&
        pending.owner.sessionId == change.binding.runtimeId) {
      controller.accept(pending, attachment: change.binding);
    }
  }

  ConnectorOperationController? _syncConnector(
    ChatThread thread,
    String? profile,
  ) {
    final source = transport, epoch = _activityEpoch;
    if (!active ||
        _profile != profile ||
        !_threads.contains(thread) ||
        source is! OwnedSessionTransport) {
      return null;
    }
    final binding = (source as OwnedSessionTransport).ownedSessionFor(
      thread.id,
      profile: profile,
    );
    if (binding == null) return null;
    final owner = (profile, thread.id),
        controller = _adoptConnector((profile, thread.id), binding);
    return _currentConnector(owner, controller, binding, epoch)
        ? controller
        : null;
  }

  bool _onConnectorOperation(
    ChatThread thread,
    ChatEvent event,
    String? profile,
  ) {
    if (event is! ConnectorOperationReceived) return false;
    final controller = _syncConnector(thread, profile),
        binding = _connectorBindings[(profile, thread.id)];
    if (controller == null ||
        binding == null ||
        event.runtimeId != binding.runtimeId ||
        !identical(event.connection, binding.connection) ||
        event.operation.owner.type != 'session' ||
        event.operation.owner.sessionId != binding.runtimeId) {
      return true;
    }
    controller.accept(event.operation, attachment: binding);
    return true;
  }

  void _listenConnectionActivity() {
    final source = transport;
    if (!active ||
        source is! GatewayConnectionTransport ||
        _connectorActivitySubscription != null) {
      return;
    }
    final epoch = _activityEpoch, generation = _connectorActivityGeneration;
    bool current() =>
        _currentActivity(epoch) && generation == _connectorActivityGeneration;
    _connectorActivitySubscription = (source as GatewayConnectionTransport)
        .connectionEvents
        .listen(
          (change) {
            if (!current()) return;
            if (!change.connected) {
              if (identical(_connectorConnection, change.connection)) {
                _clearConnectionOperations();
                notifyListeners();
              }
              return;
            }
            final frame = change.event;
            if (frame == null ||
                frame.type != 'connection.update' ||
                frame.sessionId.isNotEmpty) {
              return;
            }
            final operation = ConnectorOperationSnapshot.fromUpdate(
              frame.payload,
            );
            if (operation == null ||
                operation.owner.type != 'account' ||
                !(source as GatewayConnectionTransport).ownsGatewayConnection(
                  change.connection,
                )) {
              return;
            }
            if (!identical(_connectorConnection, change.connection)) {
              _clearConnectionOperations();
              _connectorConnection = change.connection;
              final controller = ConnectorOperationController(
                now: _clock,
                events: events,
                breadcrumbs: breadcrumbs,
              )..bind(change.connection, actionsAllowed: false);
              controller.addListener(notifyListeners);
              _connectionOperations = controller;
            }
            final controller = _connectionOperations;
            if (!current() ||
                controller == null ||
                !controller.hasScope(change.connection) ||
                !(source as GatewayConnectionTransport).ownsGatewayConnection(
                  change.connection,
                )) {
              return;
            }
            controller.accept(operation, attachment: change.connection);
          },
          onError: (Object _) {
            if (current()) {
              _clearConnectionOperations();
              notifyListeners();
            }
          },
          onDone: () {
            if (!current()) return;
            _connectorActivitySubscription = null;
            _clearConnectionOperations();
            notifyListeners();
          },
        );
  }
}
