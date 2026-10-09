import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../widgets/grouped_dialog.dart';
import '../widgets/grouped_list.dart';
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
    return GroupedDialog(
      title: 'App lock',
      children: [
        GroupedSection(
          footer:
              'Hermes asks for Face ID, Touch ID, fingerprint or your device '
              'passcode when you open it and when you come back to it.',
          children: [
            GroupedSwitchRow(
              key: const Key('app-lock-switch'),
              title: 'Require Face ID or Touch ID',
              value: lock.enabled,
              onChanged: lock.available || lock.enabled
                  ? lock.setEnabled
                  : null,
            ),
          ],
        ),
        if (!lock.available)
          const GroupedDialogNote(
            'Set up Face ID, Touch ID or a passcode in system settings to '
            'use app lock. This device does not offer one right now.',
          ),
      ],
    );
  }
}
