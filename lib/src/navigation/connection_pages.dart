import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../auth/auth_controller.dart';
import '../telemetry/breadcrumbs.dart';

/// Keeps the routes above the first one on the root navigator: pushed pages
/// and everything above them (dialogs, sheets, popup menus).
class PushedRoutes extends NavigatorObserver {
  final _routes = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) _routes.add(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _routes.remove(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _routes.remove(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (index == -1) return;
    if (newRoute == null) {
      _routes.removeAt(index);
    } else {
      _routes[index] = newRoute;
    }
  }

  /// Removes every route above the home route, the top one first, and returns
  /// how many went. A route is taken out of the navigator, not popped: no
  /// `PopScope`, undismissable barrier or running transition can keep it, and
  /// nothing animates, so a screen of the ended connection is never left on
  /// show. A route that is already popping is on its way out and ignores
  /// touches; it is left to finish.
  int removeAll() {
    final navigator = this.navigator;
    if (navigator == null || !navigator.mounted) return 0;
    var removed = 0;
    for (final route in _routes.reversed.toList()) {
      if (!route.isActive) continue;
      navigator.removeRoute(route);
      removed++;
    }
    return removed;
  }
}

/// Closes everything above the home route when the connection ends, so a
/// settings screen of the old server or account (its controller, its
/// repository, what it shows) never outlives it on top of the login or setup
/// screen.
///
/// The connection ends when [AuthController.state] leaves
/// [HermesConnectionState.ready], or while it is ready and
/// [AuthController.ownerGeneration] moves (sign-out, server change, another
/// account on the same server). A token refresh, a retry of a failed refresh
/// and a reconnect that keeps the account change neither. Nothing here signs
/// the user out or touches `AppShell`: the shell's own runs end with the shell.
class ConnectionPageCloser {
  ConnectionPageCloser(this._routes);

  final PushedRoutes _routes;
  Breadcrumbs breadcrumbs = Breadcrumbs.none;
  AuthController? _auth;
  var _open = false;
  var _owner = 0;
  var _disposed = false;

  void bind(AuthController auth) {
    if (identical(_auth, auth)) return;
    _auth?.removeListener(_changed);
    _auth = auth;
    _open = auth.state == HermesConnectionState.ready;
    _owner = auth.ownerGeneration;
    auth.addListener(_changed);
  }

  void _changed() {
    final auth = _auth;
    if (auth == null || _disposed) return;
    final open = auth.state == HermesConnectionState.ready;
    final owner = auth.ownerGeneration;
    final ended = _open && (!open || owner != _owner);
    _open = open;
    _owner = owner;
    if (!ended) return;
    // Before the frame that builds the new home, so a page never meets it.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _close());
    } else {
      _close();
    }
  }

  void _close() {
    if (_disposed) return;
    var closed = _routes.removeAll();
    // A route that went resolves its future with null in a microtask, before
    // the next frame, and the code waiting on it may push another route or
    // show a snackbar then. One more sweep after the frame takes those too.
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        if (_disposed) return;
        closed += _routes.removeAll();
        _note(closed);
      })
      ..ensureVisualUpdate();
  }

  void _note(int closed) {
    if (closed > 0) {
      breadcrumbs('nav.connection_pages_closed', {'count': closed});
    }
  }

  void dispose() {
    _disposed = true;
    _auth?.removeListener(_changed);
    _auth = null;
  }
}
