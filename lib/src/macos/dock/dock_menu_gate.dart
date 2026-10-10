import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../app_lock/app_lock_controller.dart';
import '../../auth/auth_controller.dart';
import 'dock_menu_bridge.dart';
import 'dock_menu_controller.dart';

/// Tells the Dock menu whether it may show chats: not while signed out or
/// disconnected, and only the New Chat entry while the app is locked.
///
/// It follows the controllers' listeners instead of rebuilding, so the menu
/// is already unlocked when [AppLockController.unlock] returns, which a New
/// Chat waiting for it relies on.
class DockMenuGate extends StatefulWidget {
  const DockMenuGate({super.key, required this.child});

  final Widget child;

  @override
  State<DockMenuGate> createState() => _DockMenuGateState();
}

class _DockMenuGateState extends State<DockMenuGate> {
  DockMenuController? _dock;
  AuthController? _auth;
  AppLockController? _lock;

  @override
  void initState() {
    super.initState();
    _dock = context.read<DockMenuController?>();
    if (_dock == null) return;
    _auth = context.read<AuthController>()..addListener(_sync);
    _lock = context.read<AppLockController>()..addListener(_sync);
    // The controller's own provider is rebuilding around this build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sync();
    });
  }

  void _sync() {
    final auth = _auth!;
    _dock!.configure(
      auth.state != HermesConnectionState.ready
          ? DockMenuState.off
          : _lock!.covered
          ? DockMenuState.locked
          : DockMenuState.ready,
    );
  }

  @override
  void dispose() {
    _auth?.removeListener(_sync);
    _lock?.removeListener(_sync);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
