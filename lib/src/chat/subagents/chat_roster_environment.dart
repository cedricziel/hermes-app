import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../gateway_connection_transport.dart';
import 'subagent_roster.dart';

/// What a chat's rosters know of the app: the gateway connection, whether the
/// chat's activity gate is open, and App Lock. One serves all the rosters of
/// a `ChatController`.
class ChatRosterEnvironment extends ChangeNotifier
    with WidgetsBindingObserver
    implements RosterEnvironment {
  ChatRosterEnvironment({
    required Object? transport,
    this.activity,
    this.covered,
    Listenable? lockChanges,
  }) : _source = transport is GatewayConnectionTransport ? transport : null {
    _last = connection;
    try {
      WidgetsBinding.instance.addObserver(this);
      _lifecycle = WidgetsBinding.instance.lifecycleState;
    } on Object {
      // No binding (a unit test): the app counts as in front.
    }
    activity?.addListener(_notify);
    _lockChanges = lockChanges?..addListener(_notify);
    // Every frame arrives here; only a change of connection is news.
    _subscription = _source?.connectionEvents.listen((_) {
      final now = connection;
      if (identical(now, _last)) return;
      _last = now;
      _notify();
    }, onError: (Object _) {});
  }

  /// With no gateway connection to look at (a transport of another kind), the
  /// app counts as connected.
  static final _unknown = Object();

  final GatewayConnectionTransport? _source;
  final ValueListenable<bool>? activity;

  /// Whether App Lock covers the app.
  final bool Function()? covered;
  Listenable? _lockChanges;
  StreamSubscription<GatewayConnectionEvent>? _subscription;
  Object? _last;
  AppLifecycleState? _lifecycle;
  var _disposed = false;

  @override
  Listenable get changes => this;

  @override
  Object? get connection =>
      _source == null ? _unknown : _source.gatewayConnection;

  @override
  bool get foreground =>
      (activity?.value ?? true) &&
      (_lifecycle == null || _lifecycle == AppLifecycleState.resumed);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    _notify();
  }

  @override
  bool get unlocked => !(covered?.call() ?? false);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    try {
      WidgetsBinding.instance.removeObserver(this);
    } on Object {
      // No binding.
    }
    activity?.removeListener(_notify);
    _lockChanges?.removeListener(_notify);
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
