import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../auth/auth_controller.dart';
import '../widgets/route_dismissal.dart';

/// Watches the connection a page was opened for and says when it ended: the
/// session was signed out or expired, another account or server took over,
/// or protected requests were closed.
///
/// Pages are pushed on the root navigator, which outlives the shell, so
/// nothing else removes them when the connection goes. A page that holds
/// anything read with that session listens here and drops it.
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

/// Removes the page's own route when the connection it was opened for ends.
class ConnectionBound extends StatefulWidget {
  const ConnectionBound({super.key, required this.child});

  final Widget child;

  @override
  State<ConnectionBound> createState() => _ConnectionBoundState();
}

class _ConnectionBoundState extends State<ConnectionBound> {
  late final ConnectionGuard _guard;

  @override
  void initState() {
    super.initState();
    AuthController? auth;
    try {
      auth = context.read<AuthController>();
    } on ProviderNotFoundException {
      auth = null;
    }
    _guard = ConnectionGuard(auth, _ended);
  }

  void _ended() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) dismissRoute(context);
  });

  @override
  void dispose() {
    _guard.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
