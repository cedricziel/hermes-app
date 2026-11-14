import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_icons.dart';
import '../voice/calls/active_call.dart';
import '../voice/widgets/hands_free_strip.dart';
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
    final covered = lock.covered;
    // A running call is never ended by the lock; the cover only keeps its
    // mark in sight, with End.
    ActiveCallRegistry? call;
    try {
      call = Provider.of<ActiveCallRegistry>(context);
    } on ProviderNotFoundException {
      call = null;
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        // Without tickers the covered app also offers no menu bar commands.
        // And without focus, so what is typed on the lock screen cannot reach a
        // field underneath (a password question left open).
        Offstage(
          offstage: covered,
          child: ExcludeFocus(
            excluding: covered,
            child: TickerMode(enabled: !covered, child: child),
          ),
        ),
        if (covered)
          _LockScreen(
            onUnlock: lock.locked ? lock.unlock : null,
            handsFree: call?.strip == null ? null : call,
          ),
      ],
    );
  }
}

class _LockScreen extends StatelessWidget {
  const _LockScreen({required this.onUnlock, this.handsFree});

  final VoidCallback? onUnlock;

  /// The running call, if any: its mark shows over the lock.
  final ActiveCallRegistry? handsFree;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(
              AppIcons.lock,
              size: 48,
              color: context.hermesColors.subtleText,
            ),
            if (handsFree case final call?) ...[
              const SizedBox(height: 16),
              HandsFreeStrip(
                microphone: call.strip!,
                // A call that ended has nothing to end, and the cover is no
                // place to dismiss its warning.
                onEnd: call.active ? () => unawaited(call.end()) : null,
              ),
            ],
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
