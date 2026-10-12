import 'dart:async';

import 'package:flutter/widgets.dart';

/// Delivers the latest requested action after routes above [root] allow Back.
class RootNavigationQueue {
  RootNavigationQueue({
    required this.navigator,
    required this.root,
    required this.canNavigate,
  });

  final NavigatorState navigator;
  final Route<dynamic> root;
  final bool Function() canNavigate;
  final _disposed = Completer<void>();
  void Function(bool waited)? _pending;
  bool _running = false;
  bool _receivedRequest = false;
  bool _waited = false;

  /// False after any request, cancellation, or disposal.
  bool get canAcceptLaunch => !_disposed.isCompleted && !_receivedRequest;

  void request(void Function(bool waited) action, {bool isLaunch = false}) {
    if (_disposed.isCompleted || (isLaunch && _receivedRequest)) return;
    _receivedRequest = true;
    _pending = action;
    resume();
  }

  void resume() {
    if (!_running && !_disposed.isCompleted) unawaited(_drain());
  }

  void cancel() {
    _receivedRequest = true;
    _pending = null;
    if (!_running) _waited = false;
  }

  Future<void> _drain() async {
    _running = true;
    try {
      while (_pending != null && !_disposed.isCompleted && canNavigate()) {
        if (!navigator.mounted || !root.isActive) return;
        Route<dynamic>? top;
        navigator.popUntil((route) {
          top = route;
          return true;
        });
        if (top == root) {
          final action = _pending!;
          _pending = null;
          final waited = _waited;
          _waited = false;
          action(waited);
          continue;
        }
        final route = top;
        if (route == null) return;
        _waited = true;
        await navigator.maybePop();
        // maybePop reports handled even while async discard confirmation stays open.
        await Future.any<void>([
          route.popped.then<void>((_) {}),
          _disposed.future,
        ]);
      }
    } finally {
      _running = false;
      if (_pending == null) _waited = false;
    }
  }

  void dispose() {
    _pending = null;
    if (!_disposed.isCompleted) _disposed.complete();
  }
}
