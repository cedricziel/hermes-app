import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'handoff_activity.dart';
import 'handoff_bridge.dart';

typedef HandoffRestore = Future<bool> Function(
  HandoffActivity activity,
  bool Function() valid,
);

class HandoffController extends ChangeNotifier {
  HandoffController(this.bridge);
  final HandoffBridge bridge;
  HandoffActivity? pending;
  String? setupUrl;
  String? error;
  bool retryable = false;
  bool _ready = false,
      _unlocked = false,
      _initializing = true,
      _fixedServer = false;
  bool _attempted = false, _busy = false, _disposed = false;
  String? _server;
  bool covered = false;
  bool _acceptedChange = false;
  int _generation = 0, _userGeneration = 0;
  HandoffRestore? _restore;
  HandoffActivity? _visible;
  String? _published;
  Future<void> _publishing = Future.value();

  bool get unlocked => _unlocked;
  bool get needsConnection =>
      !_initializing &&
      pending != null &&
      _server != pending!.serverUrl &&
      error == null &&
      setupUrl == null;

  Future<void> start() async {
    bridge.onIncoming = receive;
    final raw = await bridge.take();
    if (!_disposed && raw != null) receive(raw);
  }

  void receive(Object? raw) {
    if (raw == null || _disposed) return;
    _generation++;
    pending = HandoffActivity.parse(raw);
    error = pending == null ? 'This activity cannot be continued.' : null;
    setupUrl = null;
    retryable = false;
    _attempted = false;
    _publish();
    notifyListeners();
  }

  void configure({
    required String? serverUrl,
    required bool ready,
    required bool unlocked,
    required bool initializing,
    required bool fixedServer,
    required int userGeneration,
  }) {
    final canonical = serverUrl == null
        ? null
        : HandoffActivity.server(serverUrl);
    final changed =
        _server != canonical ||
        _ready != ready ||
        _unlocked != unlocked ||
        _initializing != initializing ||
        _fixedServer != fixedServer;
    final recovered = !_ready && ready;
    _server = canonical;
    _ready = ready;
    _unlocked = unlocked;
    _initializing = initializing;
    _fixedServer = fixedServer;
    if (_userGeneration != userGeneration) {
      _userGeneration = userGeneration;
      if (_acceptedChange) {
        _acceptedChange = false;
      } else {
        cancel();
      }
    }
    if (recovered && setupUrl != null && _server != pending?.serverUrl) {
      setupUrl = null;
    }
    if (recovered && retryable) retry();
    _publish();
    if (changed) notifyListeners();
  }

  void bind(HandoffRestore? restore) {
    _restore = restore;
  }

  void cover(bool value) {
    if (_disposed) return;
    covered = value;
    _publish();
  }

  void advertise(HandoffActivity? activity) {
    if (_disposed) return;
    _visible = activity;
    _publish();
  }

  void _publish() {
    final next =
        _ready && _unlocked && pending == null && error == null && !covered
        ? _visible
        : null;
    if (next?.identity == _published) return;
    _published = next?.identity;
    _publishing = _publishing.then((_) => bridge.publish(next));
  }

  void cancel() {
    if (_disposed) return;
    _acceptedChange = false;
    _generation++;
    pending = null;
    setupUrl = null;
    error = null;
    retryable = false;
    _attempted = false;
    _publish();
    notifyListeners();
  }

  void retry() {
    error = null;
    retryable = false;
    _attempted = false;
    notifyListeners();
  }

  void acceptConnection() {
    if (_fixedServer) {
      error = 'This build uses a fixed development dashboard.';
      notifyListeners();
      return;
    }
    _acceptedChange = true;
    setupUrl = pending?.serverUrl;
    notifyListeners();
  }

  Future<void> drive() async {
    if (_disposed ||
        !_ready ||
        !_unlocked ||
        _busy ||
        _attempted ||
        error != null ||
        needsConnection ||
        _restore == null ||
        pending == null ||
        _server != pending!.serverUrl) {
      return;
    }
    final target = pending!;
    final generation = _generation;
    bool valid() =>
        !_disposed &&
        _generation == generation &&
        _unlocked &&
        _ready &&
        _server == target.serverUrl;
    _busy = true;
    _attempted = true;
    try {
      final opened = await _restore!(target, valid);
      if (!valid()) return;
      if (opened) {
        pending = null;
        setupUrl = null;
      } else {
        error = 'This chat is unavailable.';
      }
    } on Object catch (failure) {
      if (!valid()) return;
      retryable =
          failure is! DioException ||
          failure.response == null ||
          (failure.response?.statusCode ?? 0) >= 500;
      error = retryable
          ? 'Could not reach the dashboard. Try again.'
          : 'This chat is unavailable.';
    } finally {
      if (!valid() && pending != null) _attempted = false;
      _busy = false;
      if (!_disposed) {
        _publish();
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    bridge.dispose();
    super.dispose();
  }
}
