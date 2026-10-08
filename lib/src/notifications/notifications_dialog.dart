import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../live_activities/live_activities.dart';
import '../theme/hermes_theme.dart';
import 'notification_settings.dart';

Future<void> showNotificationsDialog(BuildContext context) {
  final settings = context.read<NotificationSettings>();
  LiveActivities? liveActivities;
  try {
    liveActivities = context.read<LiveActivities?>();
  } on ProviderNotFoundException {
    liveActivities = null;
  }
  return showDialog<void>(
    context: context,
    builder: (_) => ChangeNotifierProvider.value(
      value: settings,
      child: _NotificationsDialog(liveActivities: liveActivities),
    ),
  );
}

class _NotificationsDialog extends StatelessWidget {
  const _NotificationsDialog({this.liveActivities});

  /// Null where there are no Live Activities, which hides their switch.
  final LiveActivities? liveActivities;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<NotificationSettings>();
    final subtle = context.hermesColors.subtleText;
    final note = TextStyle(fontSize: 12.5, color: subtle);
    return SimpleDialog(
      title: const Text('Notifications'),
      children: [
        SwitchListTile.adaptive(
          title: const Text('Notify me'),
          subtitle: const Text(
            'When a reply finishes or Hermes needs you, while the app is not '
            'in front. Replies show a preview; requests only say that Hermes '
            'is waiting.',
          ),
          value: settings.enabled,
          onChanged: (value) => settings.setEnabled(value),
        ),
        SwitchListTile.adaptive(
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
        if (liveActivities case final activities?) ...[
          SwitchListTile.adaptive(
            key: const Key('live-activities'),
            title: const Text('Live Activities'),
            subtitle: const Text(
              'Show a reply you sent on the Lock Screen and in the Dynamic '
              'Island while Hermes is running. It only says whether Hermes '
              'is working, waiting for you or done.',
            ),
            value: settings.liveActivities,
            onChanged: (value) => settings.setLiveActivities(value),
          ),
          ValueListenableBuilder<bool?>(
            valueListenable: activities.systemAllowed,
            builder: (context, allowed, _) => allowed == false
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                    child: Text(
                      'Turn on Live Activities for Hermes in system settings.',
                      style: note.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
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
