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
/// An [AuthController] that was not ready when the page opened (a test, the
/// catalog) only ends the connection by changing owner or server.
class ConnectionGuard {
  ConnectionGuard(this._auth, this._onEnded) {
    final auth = _auth;
    if (auth == null) return;
    _wasReady = auth.state == HermesConnectionState.ready;
    _owner = auth.ownerGeneration;
    _server = auth.baseUrl;
    auth.addListener(_check);
  }

  final AuthController? _auth;
  final VoidCallback _onEnded;
  late final bool _wasReady;
  late final int _owner;
  late final String? _server;
  bool _ended = false;

  /// Whether the connection has ended.
  bool get ended => _ended;

  void _check() {
    if (_ended) return;
    final auth = _auth!;
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
