import 'package:flutter/foundation.dart';

import '../auth/auth_controller.dart';

/// Watches the connection a page was opened for and says when it ended: the
/// session was signed out or expired, another account or server took over,
/// or protected requests were closed.
///
/// The app removes every page above the home route when the connection ends
/// (`navigation/connection_pages.dart`), but that happens a frame later and
/// does not tell the page: a page that holds anything read with that session
/// listens here and drops it at once.
///
/// When the same owner and server are ready again with protected requests
/// allowed (an expiry rescued by a newer stored session), [onRestored] runs
/// and the guard watches again.
///
/// An [AuthController] that was not ready when the page opened (a test, the
/// catalog) only ends the connection by changing owner or server.
class ConnectionGuard {
  ConnectionGuard(this._auth, this._onEnded, {this._onRestored}) {
    final auth = _auth;
    if (auth == null) return;
    _wasReady = auth.state == HermesConnectionState.ready;
    _owner = auth.ownerGeneration;
    _server = auth.baseUrl;
    auth.addListener(_check);
  }

  final AuthController? _auth;
  final VoidCallback _onEnded;
  final VoidCallback? _onRestored;
  late final bool _wasReady;
  late final int _owner;
  late final String? _server;
  bool _ended = false;

  /// Whether the connection has ended.
  bool get ended => _ended;

  void _check() {
    final auth = _auth!;
    if (_ended) {
      // An expiry that another engine's newer session rescued: the same
      // owner and server are ready again, so what the page dropped may be
      // read again. A changed owner or server never comes back.
      if (auth.ownerGeneration == _owner &&
          auth.baseUrl == _server &&
          auth.state == HermesConnectionState.ready &&
          auth.protectedRequestsAllowed) {
        _ended = false;
        _onRestored?.call();
      }
      return;
    }
    final over =
        auth.ownerGeneration != _owner ||
        auth.baseUrl != _server ||
        (_wasReady &&
            (auth.state != HermesConnectionState.ready ||
                !auth.protectedRequestsAllowed));
    if (!over) return;
    _ended = true;
    _onEnded();
  }

  void dispose() => _auth?.removeListener(_check);
}
