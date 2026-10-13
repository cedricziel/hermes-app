import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_otel/flutter_otel.dart';

import '../../auth/auth_controller.dart';
import '../../auth/session_activity.dart';
import '../gateway_connection_transport.dart';
import 'change_invalidation_controller.dart';
import 'change_signal.dart';

class ChangeInvalidationBinding with WidgetsBindingObserver {
  ChangeInvalidationBinding({
    required this.source,
    required AuthController auth,
    required this.resource,
    required this.profile,
    AppEventLogger events = noopAppEventLogger,
  }) : _auth = auth,
       _activity = SessionActivity(auth) {
    controller = ChangeInvalidationController(
      activity: _activity,
      events: events,
      scopeIsCurrent: _current,
    );
    _activity.addListener(sync);
    _auth.addListener(sync);
    WidgetsBinding.instance.addObserver(this);
    _subscription = source.connectionEvents.listen(
      _received,
      onError: (Object _) => controller.bind(null),
    );
    sync();
  }
  final GatewayConnectionTransport source;
  final AuthController _auth;
  final SessionActivity _activity;
  final InvalidationResource resource;
  final String? Function() profile;
  late final ChangeInvalidationController controller;
  StreamSubscription<GatewayConnectionEvent>? _subscription;
  bool _disposed = false, _visible = false, _blocked = false;

  bool get foreground {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  Object get ownerPeriod => (
    _auth.verifiedOwner,
    _auth.ownerGeneration,
    _auth.sessionExpiryGeneration,
  );
  bool ownsPeriod(Object period) =>
      !_disposed &&
      _activity.value &&
      _auth.protectedRequestsAllowed &&
      _auth.state == HermesConnectionState.ready &&
      ownerPeriod == period;

  bool _current(ChangeInvalidationScope scope) =>
      !_disposed &&
      _activity.value &&
      _auth.protectedRequestsAllowed &&
      _auth.state == HermesConnectionState.ready &&
      scope.account ==
          (
            _auth.verifiedOwner,
            _auth.ownerGeneration,
            _auth.sessionExpiryGeneration,
          ) &&
      _auth.verifiedOwner?.server == scope.server &&
      profile() == scope.profile &&
      scope.profile != null &&
      scope.profile!.trim().isNotEmpty &&
      source.ownsGatewayConnection(scope.connection);

  ChangeInvalidationScope? _scope() {
    final connection = source.gatewayConnection, owner = _auth.verifiedOwner;
    final selected = profile();
    if (!_activity.value ||
        !_auth.protectedRequestsAllowed ||
        _auth.state != HermesConnectionState.ready ||
        connection == null ||
        owner == null ||
        selected == null ||
        selected.trim().isEmpty ||
        !source.ownsGatewayConnection(connection)) {
      return null;
    }
    return ChangeInvalidationScope(
      connection: connection,
      server: owner.server,
      account: (owner, _auth.ownerGeneration, _auth.sessionExpiryGeneration),
      profile: selected,
    );
  }

  void sync({bool? active, bool? blocked}) {
    if (_disposed) return;
    _visible = active ?? _visible;
    _blocked = blocked ?? _blocked;
    controller.bind(_scope());
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    controller.setActive(
      resource,
      _visible && (lifecycle == null || lifecycle == AppLifecycleState.resumed),
    );
    controller.setBlocked(resource, _blocked);
  }

  void _received(GatewayConnectionEvent frame) {
    if (_disposed) return;
    sync();
    final scope = _scope(), event = frame.event;
    if (!frame.connected ||
        event == null ||
        scope == null ||
        !identical(frame.connection, scope.connection) ||
        !_current(scope)) {
      return;
    }
    final signal = ChangeSignal.decode(event.type, event.payload);
    if (signal != null && signal.resource == resource) {
      controller.invalidate(signal, scope: scope);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => sync();

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _activity.removeListener(sync);
    _auth.removeListener(sync);
    unawaited(_subscription?.cancel());
    controller.dispose();
    _activity.dispose();
  }
}
