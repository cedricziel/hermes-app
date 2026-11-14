import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
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
    final l10n = context.l10n;
    final platform = Theme.of(context).platform;
    final (footer, title, setup) = switch (platform) {
      TargetPlatform.iOS || TargetPlatform.macOS => (
        l10n.appLockFooterApple,
        l10n.appLockSwitchApple,
        l10n.appLockSetupApple,
      ),
      TargetPlatform.windows => (
        l10n.appLockFooterWindows,
        l10n.appLockSwitchWindows,
        l10n.appLockSetupWindows,
      ),
      // No local_auth backend exists, so there is nothing to set up.
      TargetPlatform.linux => (
        l10n.appLockFooterLinux,
        l10n.appLockSwitchLinux,
        l10n.appLockUnavailableLinux,
      ),
      TargetPlatform.android || TargetPlatform.fuchsia => (
        l10n.appLockFooterAndroid,
        l10n.appLockSwitchAndroid,
        l10n.appLockSetupAndroid,
      ),
    };
    return GroupedDialog(
      title: l10n.appLockTitle,
      children: [
        GroupedSection(
          footer: footer,
          children: [
            GroupedSwitchRow(
              key: const Key('app-lock-switch'),
              title: title,
              value: lock.enabled,
              onChanged: lock.available || lock.enabled
                  ? lock.setEnabled
                  : null,
            ),
          ],
        ),
        if (!lock.available) GroupedDialogNote(setup),
      ],
    );
  }
}
