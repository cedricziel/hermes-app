import 'package:flutter/material.dart';
import 'package:hermes_app/src/schedules/schedule_models.dart';
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
