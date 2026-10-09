import 'package:flutter/material.dart';
import 'package:hermes_app/src/schedules/schedule_models.dart';
import 'package:hermes_app/src/schedules/widgets/schedule_filter_menu.dart';
import 'package:hermes_app/src/schedules/widgets/mac_schedule_detail.dart';
import 'package:hermes_app/src/schedules/widgets/schedules_mac_toolbar.dart';
import 'package:widgetbook/widgetbook.dart';

import 'fixtures.dart';

/// Shown on macOS in either viewport, as these only appear in a Mac window.
Widget _mac(Widget child) => Builder(
  builder: (context) => Theme(
    data: Theme.of(context).copyWith(platform: TargetPlatform.macOS),
    child: Material(child: child),
  ),
);

WidgetbookUseCase _use(String name, Widget Function() build) =>
    WidgetbookUseCase(name: name, builder: (_) => _mac(build()));

final _healthyJob = CronJob(
  id: 'job-1',
  name: 'Nightly backup summary',
  prompt: 'Check last night’s backups and tell me which ones failed.',
  scheduleKind: 'cron',
  scheduleExpr: '0 3 * * *',
  nextRunAt: DateTime.now().add(const Duration(hours: 9)),
  lastRunAt: DateTime.now().subtract(const Duration(hours: 2)),
  lastStatus: 'ok',
  deliver: 'telegram',
  profile: 'work',
  skills: const ['backups'],
);

Widget _toolbar({required bool allProfiles}) {
  var all = allProfiles;
  return StatefulBuilder(
    builder: (context, setState) => Align(
      alignment: Alignment.topCenter,
      child: SchedulesMacToolbar(
        jobCount: all ? 4 : 2,
        allProfiles: all,
        onScopeChanged: (value) => setState(() => all = value),
        filterMenu: ScheduleFilterMenu(
          filter: ScheduleFilter.all,
          failingCount: 1,
          onChanged: (_) {},
        ),
        onRefresh: () {},
        onNew: () {},
      ),
    ),
  );
}

Widget _detail(
  CronJob job, {
  List<CronRun>? runs,
  bool runsFailed = false,
  bool muted = false,
}) {
  var mute = muted;
  return StatefulBuilder(
    builder: (context, setState) => MacScheduleDetail(
      job: job,
      now: DateTime.now(),
      runs: runs,
      runsFailed: runsFailed,
      muted: mute,
      onMutedChanged: (value) => setState(() => mute = value),
      onRunNow: () {},
      onEdit: () {},
      onTogglePaused: () {},
      onDelete: () {},
      onOpenRun: (_) {},
      onRetryRuns: () {},
      onShowMoreRuns: runs != null && runs.length > 3 ? () {} : null,
    ),
  );
}

WidgetbookNode schedulesMacNode() => WidgetbookFolder(
  name: 'Schedules (macOS)',
  children: [
    WidgetbookComponent(
      name: 'SchedulesMacToolbar',
      useCases: [
        _use('This profile', () => _toolbar(allProfiles: false)),
        _use('All profiles', () => _toolbar(allProfiles: true)),
      ],
    ),
    WidgetbookComponent(
      name: 'MacScheduleDetail',
      useCases: [
        _use('Ok', () => _detail(_healthyJob, runs: cronRuns)),
        _use('Failed', () => _detail(failingJob, runs: cronRuns)),
        _use(
          'Delivery failed',
          () => _detail(deliveryFailedJob, runs: cronRuns.take(1).toList()),
        ),
        _use(
          'Paused, muted',
          () => _detail(pausedJob, runs: const [], muted: true),
        ),
        _use(
          'Blocked before it ran',
          () => _detail(blockedJob, runs: const []),
        ),
        _use('Runs loading', () => _detail(_healthyJob)),
        _use(
          'Runs failed to load',
          () => _detail(_healthyJob, runsFailed: true),
        ),
      ],
    ),
  ],
);
