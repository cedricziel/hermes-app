import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../live_activities/live_activities.dart';
import '../background/background_check_controller.dart';
import 'background_check_section.dart';
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
  BackgroundCheckController? checks;
  try {
    checks = context.read<BackgroundCheckController>();
  } on ProviderNotFoundException {
    checks = null;
  }
  if (checks != null) {
    checks.refresh();
  }
  return showDialog<void>(
    context: context,
    builder: (_) => ChangeNotifierProvider.value(
      value: settings,
      child: _NotificationsDialog(
        liveActivities: liveActivities,
        checks: checks,
      ),
    ),
  );
}

class _NotificationsDialog extends StatelessWidget {
  const _NotificationsDialog({this.liveActivities, this.checks});
  final BackgroundCheckController? checks;

  /// Null where there are no Live Activities, which hides their switch.
  final LiveActivities? liveActivities;

  @override
  Widget build(BuildContext context) => checks == null
      ? _build(context)
      : ListenableBuilder(
          listenable: checks!,
          builder: (context, _) => _build(context),
        );

  Widget _build(BuildContext context) {
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
              warning:
                  settings.enabled &&
                      (checks?.permission == false ||
                          (checks?.permission == null &&
                              settings.permissionDenied))
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
        if (checks case final current?)
          ListenableBuilder(
            listenable: current,
            builder: (context, _) => BackgroundCheckSection(
              platform: current.platform,
              permission: current.permission,
              capability: current.capability,
              status: current.status,
            ),
          ),
        const GroupedDialogNote(
          'Alerts arrive while Hermes is running, including for a short '
          'time after you leave it.',
        ),
      ],
    );
  }
}
