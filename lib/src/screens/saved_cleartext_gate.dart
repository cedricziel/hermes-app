import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../auth/auth_controller.dart';
import 'widgets/cleartext_server_alert.dart';

/// Asks once about a saved public `http://` server nobody accepted
/// ([AuthController.unconfirmedCleartextServer]) and passes the answer on.
///
/// It asks only on the home screen or the sign-in screen, never while a
/// sign-in or a connect is running, so the question cannot leave either
/// waiting. A question closed without a choice (a tap outside, the back
/// button, the connection ending) is no answer and comes back with the next
/// connection.
class SavedCleartextGate extends StatefulWidget {
  const SavedCleartextGate({super.key, required this.child});

  final Widget child;

  @override
  State<SavedCleartextGate> createState() => _SavedCleartextGateState();
}

class _SavedCleartextGateState extends State<SavedCleartextGate> {
  bool _asking = false;

  /// The address whose question was closed without a choice, not asked again
  /// until the connection is lost or the question is gone.
  String? _declined;

  static bool _isUp(AuthController auth) =>
      auth.state == HermesConnectionState.ready ||
      auth.state == HermesConnectionState.needsLogin;

  bool _canAsk(AuthController auth) =>
      auth.unconfirmedCleartextServer != null &&
      auth.unconfirmedCleartextServer != _declined &&
      _isUp(auth);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    if (auth.unconfirmedCleartextServer == null ||
        !(_isUp(auth) || auth.state == HermesConnectionState.signingIn)) {
      _declined = null;
    }
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
      final host = Uri.parse(address).host;
      final keep = await confirmSavedCleartextServer(context, host: host);
      if (!mounted || auth.unconfirmedCleartextServer != address) return;
      // A dialog closed without a choice is no answer; it stays closed until
      // the connection is lost. One the connection ending closed is dropped.
      if (keep == null) {
        if (_isUp(auth)) _declined = address;
        return;
      }
      if (!_isUp(auth)) return;
      if (keep) {
        await auth.keepCleartextServer();
      } else {
        await _useHttps(auth, host);
      }
    } finally {
      _asking = false;
    }
  }

  /// Switches to https, with a note while it is checked and one when nothing
  /// answers there.
  Future<void> _useHttps(AuthController auth, String host) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = context.l10n;
    messenger?.showSnackBar(
      SnackBar(
        content: Text(l10n.screensCleartextCheckingHttps(host)),
        duration: const Duration(minutes: 1),
      ),
    );
    final outcome = await auth.useHttpsForCleartextServer();
    messenger?.hideCurrentSnackBar();
    if (outcome == HttpsSwitch.unavailable) {
      messenger?.showSnackBar(
        SnackBar(content: Text(l10n.screensCleartextHttpsUnavailable(host))),
      );
    }
  }
}
