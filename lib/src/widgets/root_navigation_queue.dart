import 'dart:async';

import 'package:flutter/widgets.dart';

import '../navigation/desktop_navigation_history.dart';

/// Delivers the latest requested action after routes above [root] allow Back.
class RootNavigationQueue {
  RootNavigationQueue({
    required this.navigator,
    required this.root,
    required this.canNavigate,
    this.history,
  });

  final DesktopNavigationHistory? history;
  final NavigatorState navigator;
  final Route<dynamic> root;
  final bool Function() canNavigate;
  final _disposed = Completer<void>();
  var _cancelled = Completer<void>();
  void Function(bool waited)? _pending;
  Route<dynamic>? _guardedRoute;
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
    _cancelled.complete();
    _cancelled = Completer<void>();
    if (!_running) _waited = false;
  }

  Future<void> _drain() async {
    _running = true;
    final release = history?.suppressExternalNavigation();
    try {
      while (_pending != null && !_disposed.isCompleted && canNavigate()) {
        if (!navigator.mounted || !root.isActive) return;
        Route<dynamic>? top;
        navigator.popUntil((route) {
          top = route;
          return true;
        });
        if (top == root) {
          _guardedRoute = null;
          final action = _pending!;
          _pending = null;
          final waited = _waited;
          _waited = false;
          history?.clear();
          action(waited);
          continue;
        }
        final route = top;
        if (route == null) return;
        _waited = true;
        final cancellation = _cancelled;
        final guarded = _guardedRoute;
        if (guarded != null && guarded.isActive) {
          // A replaced request must keep waiting for the guard it already
          // started, including any confirmation route it put above this page.
          await Future.any<void>([
            guarded.popped.then<void>((_) {}),
            _disposed.future,
            cancellation.future,
          ]);
          if (_disposed.isCompleted || cancellation.isCompleted) continue;
          _guardedRoute = null;
          continue;
        }
        _guardedRoute = route;
        // maybePop reports handled even while async discard confirmation stays open.
        await Future.any<void>([
          navigator.maybePop().then<void>((_) {}),
          _disposed.future,
          cancellation.future,
        ]);
        if (_disposed.isCompleted || cancellation.isCompleted) continue;
        await Future.any<void>([
          route.popped.then<void>((_) {}),
          _disposed.future,
          cancellation.future,
        ]);
        if (_disposed.isCompleted || cancellation.isCompleted) continue;
        _guardedRoute = null;
      }
    } finally {
      release?.call();
      _running = false;
      if (_pending == null) _waited = false;
    }
  }

  void dispose() {
    _pending = null;
    _guardedRoute = null;
    if (!_disposed.isCompleted) _disposed.complete();
  }
}
