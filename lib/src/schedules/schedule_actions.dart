import 'package:flutter/material.dart';

import '../widgets/adaptive_dialog.dart';
import '../widgets/row_actions.dart';
import 'schedule_models.dart';
import 'schedules_controller.dart';

void _say(ScaffoldMessengerState messenger, String message) => messenger
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(message)));

/// Asks before deleting [job], then does it and says so when it could not.
Future<void> deleteScheduleJob(
  BuildContext context,
  SchedulesController controller,
  CronJob job,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final confirmed = await showConfirmDialog(
    context,
    title: 'Delete this task?',
    message: '“${job.title}” will no longer run. Its past runs stay as chats.',
    confirmLabel: 'Delete',
    destructive: true,
    filled: false,
  );
  if (!confirmed) return;
  final message = await controller.delete(job);
  if (message != null) _say(messenger, message);
}

/// The row actions of [job] in the list: run it, pause or resume it, delete it.
List<RowAction> scheduleRowActions(
  BuildContext context,
  SchedulesController controller,
  CronJob job,
) {
  final messenger = ScaffoldMessenger.of(context);
  return [
    RowAction(
      label: 'Run now',
      icon: Icons.play_arrow,
      onPressed: () async {
        final message = await controller.runNow(job);
        _say(messenger, message ?? 'Run requested');
      },
    ),
    if (job.state != CronJobState.completed)
      RowAction(
        label: job.isPaused ? 'Resume' : 'Pause',
        icon: job.isPaused ? Icons.play_circle_outline : Icons.pause,
        onPressed: () async {
          final message = await controller.setPaused(job, !job.isPaused);
          if (message != null) _say(messenger, message);
        },
      ),
    RowAction(
      label: 'Delete',
      icon: Icons.delete_outline,
      destructive: true,
      onPressed: () => deleteScheduleJob(context, controller, job),
    ),
  ];
}
