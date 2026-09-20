import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/hermes_theme.dart';
import 'app_lock_controller.dart';

/// Covers [child] with a lock screen while the app is locked. The child stays
/// mounted underneath, so a chat that is streaming carries on.
class AppLockGate extends StatelessWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final lock = context.watch<AppLockController>();
    final covered = !lock.loaded || lock.locked;
    return Stack(
      fit: StackFit.expand,
      children: [
        Offstage(offstage: covered, child: child),
        if (covered) _LockScreen(onUnlock: lock.loaded ? lock.unlock : null),
      ],
    );
  }
}

class _LockScreen extends StatelessWidget {
  const _LockScreen({required this.onUnlock});

  final VoidCallback? onUnlock;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              size: 48,
              color: context.hermesColors.subtleText,
            ),
            if (onUnlock != null) ...[
              const SizedBox(height: 16),
              const Text('Hermes is locked'),
              const SizedBox(height: 16),
              FilledButton(onPressed: onUnlock, child: const Text('Unlock')),
            ],
          ],
        ),
      ),
    );
  }
}
