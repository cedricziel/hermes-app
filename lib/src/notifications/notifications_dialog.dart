import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/hermes_theme.dart';
import 'notification_settings.dart';

Future<void> showNotificationsDialog(BuildContext context) {
  final settings = context.read<NotificationSettings>();
  return showDialog<void>(
    context: context,
    builder: (_) => ChangeNotifierProvider.value(
      value: settings,
      child: const _NotificationsDialog(),
    ),
  );
}

class _NotificationsDialog extends StatelessWidget {
  const _NotificationsDialog();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<NotificationSettings>();
    final subtle = context.hermesColors.subtleText;
    final note = TextStyle(fontSize: 12.5, color: subtle);
    return SimpleDialog(
      title: const Text('Notifications'),
      children: [
        SwitchListTile(
          title: const Text('Notify me'),
          subtitle: const Text(
            'When a reply finishes or Hermes needs you, while the app is not '
            'in front. Replies show a preview; requests only say that Hermes '
            'is waiting.',
          ),
          value: settings.enabled,
          onChanged: (value) => settings.setEnabled(value),
        ),
        SwitchListTile(
          key: const Key('schedule-alerts'),
          title: const Text('Scheduled tasks'),
          subtitle: const Text(
            'When a scheduled task finishes or fails, while the app is open. '
            'Mute single tasks from their page.',
          ),
          value: settings.scheduleAlerts,
          onChanged: settings.enabled
              ? (value) => settings.setScheduleAlerts(value)
              : null,
        ),
        if (settings.enabled && settings.permissionDenied)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
            child: Text(
              'Turn on notifications for Hermes in system settings.',
              style: note.copyWith(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
          child: Text(
            'Alerts arrive while Hermes is running, including for a short '
            'time after you leave it.',
            style: note,
          ),
        ),
      ],
    );
  }
}
