import 'package:flutter/material.dart';
import 'package:hermes_app/src/models/model_provider_option.dart';
import 'package:hermes_app/src/schedules/schedule_models.dart';
import 'package:hermes_app/src/schedules/schedule_picker.dart';
import 'package:hermes_app/src/schedules/schedule_spec.dart';
import 'package:hermes_app/src/schedules/widgets/job_group.dart';
import 'package:hermes_app/src/schedules/widgets/schedule_detail_view.dart';
import 'package:hermes_app/src/schedules/widgets/job_model_field.dart';
import 'package:hermes_app/src/schedules/widgets/run_history_empty.dart';
import 'package:hermes_app/src/schedules/widgets/schedule_filter_menu.dart';
import 'package:hermes_app/src/theme/app_icons.dart';
import 'package:hermes_app/src/widgets/row_actions.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';
import 'package:widgetbook/widgetbook.dart';

import 'fixtures.dart';
import 'frame.dart';

Widget _group(List<CronJob> jobs, {bool showProfile = false}) {
  String? selected = jobs.first.key;
  return StatefulBuilder(
    builder: (context, setState) => frame(
      JobGroup(
        jobs: jobs,
        now: DateTime.now(),
        showProfile: showProfile,
        selectedKey: selected,
        onSelect: (job) => setState(() => selected = job.key),
        onPausedChanged: (_, _) {},
        actionsFor: (job) => [
          RowAction(label: 'Run now', icon: AppIcons.play, onPressed: () {}),
          RowAction(
            label: 'Delete',
            icon: AppIcons.delete,
            destructive: true,
            onPressed: () {},
          ),
        ],
      ),
    ),
  );
}

List<WidgetbookUseCase> _picker(String name, ScheduleSpec initial) =>
    onEachPlatform(name, (_) {
      var spec = initial;
      return StatefulBuilder(
        builder: (context, setState) => frame(
          SchedulePicker(
            spec: spec,
            now: DateTime.now(),
            onChanged: (next) => setState(() => spec = next),
          ),
        ),
      );
    });

List<WidgetbookUseCase> _modelField(
  String name, {
  ModelOptions? options = modelOptions,
  String model = '',
  String provider = '',
}) => onEachPlatform(name, (_) {
  var (m, p) = (model, provider);
  return StatefulBuilder(
    builder: (context, setState) => frame(
      GroupedSection(
        children: [
          JobModelField(
            options: options,
            model: m,
            provider: p,
            onChanged: (model, provider) =>
                setState(() => (m, p) = (model, provider)),
          ),
        ],
      ),
    ),
  );
});

List<WidgetbookUseCase> _filterMenu(
  String name, {
  int failingCount = 2,
  ScheduleFilter filter = ScheduleFilter.all,
}) => onEachPlatform(name, (_) {
  var current = filter;
  return StatefulBuilder(
    builder: (context, setState) => frame(
      Align(
        alignment: Alignment.topLeft,
        child: ScheduleFilterMenu(
          filter: current,
          failingCount: failingCount,
          onChanged: (value) => setState(() => current = value),
        ),
      ),
    ),
  );
});

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

Widget _detail(
  CronJob job, {
  List<CronRun>? runs,
  bool runsFailed = false,
  bool muted = false,
}) {
  var mute = muted;
  return StatefulBuilder(
    builder: (context, setState) => ScheduleDetailView(
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

WidgetbookNode schedulesNode() => WidgetbookFolder(
  name: 'Schedules',
  children: [
    WidgetbookComponent(
      name: 'JobGroup',
      useCases: [
        ...onEachPlatform(
          'Every state',
          (_) => _group([
            nightlyJob,
            failingJob,
            deliveryFailedJob,
            blockedJob,
            pausedJob,
            neverRunJob,
          ]),
        ),
        ...onEachPlatform(
          'All profiles, with profiles',
          (_) => _group([nightlyJob, failingJob], showProfile: true),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'ScheduleFilterMenu',
      useCases: [
        ..._filterMenu('Every task'),
        ..._filterMenu('Failing selected', filter: ScheduleFilter.failing),
        ..._filterMenu('Nothing failing', failingCount: 0),
      ],
    ),
    WidgetbookComponent(
      name: 'ScheduleDetailView',
      useCases: [
        ...onEachPlatform('Ok', (_) => _detail(_healthyJob, runs: cronRuns)),
        ...onEachPlatform('Failed', (_) => _detail(failingJob, runs: cronRuns)),
        ...onEachPlatform(
          'Delivery failed',
          (_) => _detail(deliveryFailedJob, runs: cronRuns.take(1).toList()),
        ),
        ...onEachPlatform(
          'Paused, muted',
          (_) => _detail(pausedJob, runs: const [], muted: true),
        ),
        ...onEachPlatform(
          'Blocked before it ran',
          (_) => _detail(blockedJob, runs: const []),
        ),
        ...onEachPlatform('Runs loading', (_) => _detail(_healthyJob)),
        ...onEachPlatform(
          'Runs failed to load',
          (_) => _detail(_healthyJob, runsFailed: true),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'RunHistoryEmpty',
      useCases: [
        WidgetbookUseCase(
          name: 'Never run',
          builder: (_) => frame(RunHistoryEmpty(job: neverRunJob)),
        ),
        WidgetbookUseCase(
          name: 'Blocked before it ran',
          builder: (_) => frame(RunHistoryEmpty(job: blockedJob)),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'SchedulePicker',
      useCases: [
        ..._picker('Every', const EverySpec(30, EveryUnit.minutes)),
        ..._picker('Daily', const DailySpec(9, 0)),
        ..._picker('Weekly', const WeeklySpec({1, 3, 5}, 8, 30)),
        ..._picker(
          'Once',
          OnceSpec(DateTime.now().add(const Duration(days: 2))),
        ),
        ..._picker('Cron expression', const CronSpec('*/15 9-17 * * 1-5')),
        ..._picker('Invalid cron', const CronSpec('nonsense')),
      ],
    ),
    WidgetbookComponent(
      name: 'JobModelField',
      useCases: [
        ..._modelField('Profile default'),
        ..._modelField(
          'Listed model',
          model: 'claude-opus-4',
          provider: 'anthropic',
        ),
        ..._modelField(
          'Model not in the list',
          model: 'my-finetune-v3',
          provider: 'custom:lab',
        ),
        ..._modelField('Model without a provider', model: 'gpt-4o'),
        ..._modelField(
          'List unavailable',
          options: null,
          model: 'claude-opus-4',
          provider: 'anthropic',
        ),
      ],
    ),
  ],
);
