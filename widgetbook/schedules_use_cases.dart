import 'package:flutter/material.dart';
import 'package:hermes_app/src/schedules/schedule_models.dart';
import 'package:hermes_app/src/schedules/schedule_picker.dart';
import 'package:hermes_app/src/schedules/schedule_spec.dart';
import 'package:hermes_app/src/schedules/schedule_widgets.dart';
import 'package:hermes_app/src/schedules/schedules_list.dart';
import 'package:widgetbook/widgetbook.dart';

import 'fixtures.dart';
import 'frame.dart';

WidgetbookUseCase _tile(
  String name,
  CronJob job, {
  bool showProfile = false,
  bool selected = false,
}) => WidgetbookUseCase(
  name: name,
  builder: (_) => frame(
    JobTile(
      job: job,
      now: DateTime.now(),
      showProfile: showProfile,
      selected: selected,
      onTap: () {},
      onPausedChanged: (_) {},
    ),
  ),
);

WidgetbookUseCase _picker(String name, ScheduleSpec initial) =>
    WidgetbookUseCase(
      name: name,
      builder: (_) {
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
      },
    );

WidgetbookNode schedulesNode() => WidgetbookFolder(
  name: 'Schedules',
  children: [
    WidgetbookComponent(
      name: 'JobTile',
      useCases: [
        _tile('Succeeded', nightlyJob),
        _tile('Failed, with profile', failingJob, showProfile: true),
        _tile('Paused', pausedJob),
        _tile('Never run, no name', neverRunJob),
        _tile('Selected', nightlyJob, selected: true),
      ],
    ),
    WidgetbookComponent(
      name: 'SchedulePicker',
      useCases: [
        _picker('Every', const EverySpec(30, EveryUnit.minutes)),
        _picker('Daily', const DailySpec(9, 0)),
        _picker('Weekly', const WeeklySpec({1, 3, 5}, 8, 30)),
        _picker('Once', OnceSpec(DateTime.now().add(const Duration(days: 2)))),
        _picker('Cron expression', const CronSpec('*/15 9-17 * * 1-5')),
        _picker('Invalid cron', const CronSpec('nonsense')),
      ],
    ),
    WidgetbookComponent(
      name: 'Chips',
      useCases: [
        WidgetbookUseCase(
          name: 'InfoChip and StatusDot',
          builder: (_) => frame(
            const Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StatusDot(color: Colors.green),
                StatusDot(color: Colors.red),
                InfoChip('telegram'),
                InfoChip('work'),
              ],
            ),
          ),
        ),
      ],
    ),
  ],
);
