import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../auth/auth_controller.dart';
import 'widgets/cleartext_server_alert.dart';

/// Asks once about a saved public `http://` server nobody accepted
/// ([AuthController.unconfirmedCleartextServer]) and passes the answer on.
///
/// It asks only on the home screen or the sign-in screen, never while a
/// sign-in or a connect is running, so the question cannot leave either
/// waiting. A question that gets closed by the connection ending, or left
/// unanswered, comes back with the next connection.
class SavedCleartextGate extends StatefulWidget {
  const SavedCleartextGate({super.key, required this.child});

  final Widget child;

  @override
  State<SavedCleartextGate> createState() => _SavedCleartextGateState();
}

class _SavedCleartextGateState extends State<SavedCleartextGate> {
  bool _asking = false;

  static bool _canAsk(AuthController auth) =>
      auth.unconfirmedCleartextServer != null &&
      (auth.state == HermesConnectionState.ready ||
          auth.state == HermesConnectionState.needsLogin);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    if (!_asking && _canAsk(auth)) {
      _asking = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _ask(auth));
    }
    return widget.child;
  }

  Future<void> _ask(AuthController auth) async {
    try {
      final address = auth.unconfirmedCleartextServer;
      if (!mounted || address == null || !_canAsk(auth)) return;
      final keep = await confirmCleartextServer(
        context,
        host: Uri.parse(address).host,
        saved: true,
      );
      // A dialog the connection ending closed is no answer.
      if (auth.unconfirmedCleartextServer != address || !_canAsk(auth)) return;
      await (keep
          ? auth.keepCleartextServer()
          : auth.useHttpsForCleartextServer());
    } finally {
      _asking = false;
    }
  }
}
