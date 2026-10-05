import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_controller.dart';
import '../app_lock/app_lock_controller.dart';
import 'handoff_controller.dart';
import 'handoff_dialog.dart';

class HandoffGate extends StatelessWidget {
  const HandoffGate({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final handoff = context.watch<HandoffController?>();
    if (handoff == null) return child;
    final auth = context.watch<AuthController>();
    final lock = context.watch<AppLockController>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      handoff.configure(
        serverUrl: auth.baseUrl ?? auth.savedServerUrl,
        ready: auth.state == HermesConnectionState.ready,
        unlocked: lock.loaded && !lock.locked,
        initializing: auth.state == HermesConnectionState.initializing,
        fixedServer: auth.hasDevServer,
        userGeneration: auth.userGeneration,
      );
      unawaited(handoff.drive());
    });
    final show =
        lock.loaded &&
        !lock.locked &&
        (handoff.needsConnection || handoff.error != null);
    return Stack(
      fit: StackFit.expand,
      children: [
        AbsorbPointer(absorbing: show, child: child),
        if (show) ...[
          const ModalBarrier(dismissible: false, color: Colors.black54),
          Center(
            child: HandoffDialog(
              serverUrl: handoff.error == null
                  ? handoff.pending?.serverUrl
                  : null,
              error: handoff.error,
              onCancel: handoff.cancel,
              onContinue: handoff.error != null
                  ? (handoff.retryable ? handoff.retry : null)
                  : () async {
                      handoff.acceptConnection();
                      if (handoff.setupUrl != null) await auth.changeServer();
                    },
            ),
          ),
        ],
      ],
    );
  }
}

class HandoffNavigationObserver extends NavigatorObserver {
  HandoffController? handoff;
  void _changed(Route<dynamic>? route, {bool cancel = false}) {
    final controller = handoff;
    if (controller == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.cover(route?.isFirst == false);
      if (cancel) {
        controller.cancel();
      }
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _changed(route, cancel: previousRoute != null && route is PageRoute);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _changed(previousRoute);
}
