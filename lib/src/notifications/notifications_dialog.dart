import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../live_activities/live_activities.dart';
import '../widgets/grouped_dialog.dart';
import '../widgets/grouped_list.dart';
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
    return GroupedDialog(
      title: 'Notifications',
      children: [
        GroupedSection(
          footer:
              'When a reply finishes or Hermes needs you, while the app is not '
              'in front. Replies show a preview. Approvals and questions show '
              'the command or the question and can be answered from the '
              'notification; the text stays hidden on a locked screen when '
              'the system hides previews there.',
          children: [
            GroupedSwitchRow(
              key: const Key('notify-me'),
              title: 'Notify me',
              warning: settings.enabled && settings.permissionDenied
                  ? 'Turn on notifications for Hermes in system settings.'
                  : null,
              value: settings.enabled,
              onChanged: (value) => settings.setEnabled(value),
            ),
          ],
        ),
        GroupedSection(
          footer:
              'When a scheduled task finishes or fails, while the app is open. '
              'Mute single tasks from their page.',
          children: [
            GroupedSwitchRow(
              key: const Key('schedule-alerts'),
              title: 'Scheduled tasks',
              value: settings.scheduleAlerts,
              onChanged: settings.enabled
                  ? (value) => settings.setScheduleAlerts(value)
                  : null,
            ),
          ],
        ),
        if (liveActivities case final activities?)
          GroupedSection(
            footer:
                'Show a reply you sent on the Lock Screen and in the Dynamic '
                'Island while Hermes is running. It only says whether Hermes '
                'is working, waiting for you or done.',
            children: [
              ValueListenableBuilder<bool?>(
                valueListenable: activities.systemAllowed,
                builder: (context, allowed, _) => GroupedSwitchRow(
                  key: const Key('live-activities'),
                  title: 'Live Activities',
                  warning: allowed == false
                      ? 'Turn on Live Activities for Hermes in system '
                            'settings.'
                      : null,
                  value: settings.liveActivities,
                  onChanged: (value) => settings.setLiveActivities(value),
                ),
              ),
            ],
          ),
        const GroupedDialogNote(
          'Alerts arrive while Hermes is running, including for a short '
          'time after you leave it.',
        ),
      ],
    );
  }
}
