import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/hermes_theme.dart';
import 'app_lock_controller.dart';

Future<void> showAppLockDialog(BuildContext context) {
  final lock = context.read<AppLockController>();
  return showDialog<void>(
    context: context,
    builder: (_) => ChangeNotifierProvider.value(
      value: lock,
      child: const _AppLockDialog(),
    ),
  );
}

class _AppLockDialog extends StatelessWidget {
  const _AppLockDialog();

  @override
  Widget build(BuildContext context) {
    final lock = context.watch<AppLockController>();
    final subtle = context.hermesColors.subtleText;
    return SimpleDialog(
      title: const Text('App lock'),
      children: [
        SwitchListTile(
          title: const Text('Require Face ID or Touch ID'),
          subtitle: const Text(
            'Hermes asks for Face ID, Touch ID, fingerprint or your device '
            'passcode when you open it and when you come back to it.',
          ),
          value: lock.enabled,
          onChanged: lock.available || lock.enabled ? lock.setEnabled : null,
        ),
        if (!lock.available)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
            child: Text(
              'Set up Face ID, Touch ID or a passcode in system settings to '
              'use app lock. This device does not offer one right now.',
              style: TextStyle(fontSize: 12.5, color: subtle),
            ),
          ),
      ],
    );
  }
}
