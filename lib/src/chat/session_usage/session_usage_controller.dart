import 'package:flutter/foundation.dart';
import 'package:flutter_otel/flutter_otel.dart' show Span;

import '../../telemetry/breadcrumbs.dart';
import '../../telemetry/telemetry.dart';
import '../gateway/gateway_rpc_client.dart';
import 'usage_snapshot.dart';

typedef UsageRequest = Future<Map<String, Object?>> Function(
  String method,
  Map<String, Object?> params,
);

class UsageScope {
  const UsageScope({
    required this.connection,
    required this.sessionId,
    required this.profile,
  });

  /// Opaque attachment token; never substitutes for a runtime lookup.
  final Object connection;
  final String sessionId;
  final String? profile;

  @override
  bool operator ==(Object other) =>
      other is UsageScope &&
      identical(connection, other.connection) &&
      sessionId == other.sessionId &&
      profile == other.profile;
  @override
  int get hashCode =>
      Object.hash(identityHashCode(connection), sessionId, profile);
}

enum UsageFreshness { unavailable, current, stale, unsupported }

enum UsageSource { live, completion, fetch }

enum UsageFailure implements Exception { unsupported, malformed, transport }

class SessionUsageController extends ChangeNotifier {
  SessionUsageController({
    this.telemetry = const ConnectionTelemetry(),
    this.breadcrumbs = Breadcrumbs.none,
  });
  final ConnectionTelemetry telemetry;
  final Breadcrumbs breadcrumbs;
  UsageSnapshot? snapshot;
  UsageSource? source;
  UsageFailure? failure;
  UsageFreshness freshness = UsageFreshness.unavailable;
  bool loading = false;
  UsageScope? _scope;
  UsageRequest? _request;
  int _generation = 0;
  bool _connected = true, _unsupported = false, _disposed = false;
  bool get bound => _scope != null && _request != null;
  bool hasScope(UsageScope scope) => bound && _scope == scope;

  /// Whether there is anything to show: a server without usage has nothing.
  bool get shown => bound && freshness != UsageFreshness.unsupported;
  bool get canRefresh => bound && _connected && !_unsupported && !loading;

  /// Changes ownership and invalidates earlier reads without retaining their data.
  void bind(UsageScope? scope, UsageRequest? request) {
    if (_disposed || _scope == scope && _request == request) return;
    _generation++;
    _scope = scope;
    _request = request;
    snapshot = null;
    source = null;
    failure = null;
    loading = false;
    _unsupported = false;
    _connected = true;
    freshness = UsageFreshness.unavailable;
    notifyListeners();
  }

  void tick(UsageScope scope, Object? payload) =>
      _receive(scope, payload, UsageSource.live);

  void complete(UsageScope scope, Object? payload) {
    if (_disposed || scope != _scope) return;
    if (payload == null) {
      // Pre-completion reads cannot establish fresh final usage.
      _generation++;
      loading = false;
      notifyListeners();
      return;
    }
    _receive(scope, payload, UsageSource.completion);
  }

  void _receive(UsageScope scope, Object? payload, UsageSource origin) {
    if (_disposed || scope != _scope || !_connected) return;
    _generation++;
    loading = false;
    final decoded = payload is UsageSnapshot
        ? payload
        : UsageSnapshot.decode(payload);
    if (decoded == null) {
      failure = UsageFailure.malformed;
      freshness = snapshot == null
          ? UsageFreshness.unavailable
          : UsageFreshness.stale;
    } else {
      snapshot = decoded;
      source = origin;
      failure = null;
      freshness = UsageFreshness.current;
    }
    notifyListeners();
  }

  Future<void> opened() {
    breadcrumbs('chat.usage.open');
    return refresh();
  }

  Future<void> refresh() async {
    final scope = _scope, request = _request;
    if (_disposed || !canRefresh || scope == null || request == null) return;
    final generation = ++_generation;
    loading = true;
    failure = null;
    notifyListeners();
    if (!_current(generation, scope)) return;
    Span? span;
    _quiet(
      () => span = telemetry.tracer?.startSpan(
        'chat.usage.fetch',
        attributes: telemetry.serverAttributes,
      ),
    );
    var outcome = 'obsolete';
    try {
      if (!_current(generation, scope)) return;
      final value = await request('session.usage', {
        'session_id': scope.sessionId,
        'profile': scope.profile,
      });
      if (!_current(generation, scope)) return;
      final decoded = UsageSnapshot.decode(value);
      if (decoded == null) throw UsageFailure.malformed;
      snapshot = decoded;
      source = UsageSource.fetch;
      failure = null;
      freshness = UsageFreshness.current;
      outcome = 'success';
    } on Object catch (error) {
      if (!_current(generation, scope)) return;
      final category = error is UsageFailure
          ? error
          : error is GatewayRpcException && error.code == kGatewayMethodNotFound
          ? UsageFailure.unsupported
          : UsageFailure.transport;
      failure = category;
      _unsupported = category == UsageFailure.unsupported;
      freshness = snapshot != null
          ? UsageFreshness.stale
          : _unsupported
          ? UsageFreshness.unsupported
          : UsageFreshness.unavailable;
      outcome = category.name;
      _quiet(
        () => telemetry.events('chat.usage.fetch_failed', {
          'category': category.name,
        }),
      );
    } finally {
      _quiet(() => span?.setAttribute('outcome', outcome));
      _quiet(() => span?.end());
      if (_current(generation, scope)) {
        loading = false;
        notifyListeners();
      }
    }
  }

  bool _current(int generation, UsageScope scope) =>
      !_disposed && _connected && generation == _generation && scope == _scope;

  void disconnected() {
    if (_disposed) return;
    _generation++;
    _connected = false;
    loading = false;
    freshness = snapshot == null
        ? UsageFreshness.unavailable
        : UsageFreshness.stale;
    notifyListeners();
  }

  Future<void> reconnected() {
    if (_disposed) return Future.value();
    _generation++;
    loading = false;
    _connected = true;
    _unsupported = false;
    return refresh();
  }

  static void _quiet(void Function() action) {
    try {
      action();
    } on Object {
      return;
    }
  }

  int _notificationDepth = 0;

  @override
  void notifyListeners() {
    if (_disposed) return;
    _notificationDepth++;
    try {
      super.notifyListeners();
    } finally {
      _notificationDepth--;
      if (_disposed && _notificationDepth == 0) super.dispose();
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _scope = null;
    _request = null;
    snapshot = null;
    if (_notificationDepth == 0) super.dispose();
  }
}
