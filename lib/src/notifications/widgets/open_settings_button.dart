import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';

/// The text button under a denied notification permission that opens the
/// system's settings for the app. A secondary action, never filled, 48 dp
/// tall. Takes only the callback, so a catalog entry or a test can place it
/// without a dialog.
class OpenSettingsButton extends StatelessWidget {
  const OpenSettingsButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: TextButton.icon(
      key: const Key('notifications-open-settings'),
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      onPressed: onPressed,
      icon: const AppIcon(AppIcons.settings, size: 18),
      label: Text(context.l10n.notificationsOpenSettings),
    ),
  );
}
