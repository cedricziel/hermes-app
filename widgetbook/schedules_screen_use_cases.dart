import 'package:flutter/material.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/schedules/blueprint_screens.dart';
import 'package:hermes_app/src/schedules/hermes_cron_repository.dart';
import 'package:hermes_app/src/schedules/job_form_controller.dart';
import 'package:hermes_app/src/schedules/job_form_screen.dart';
import 'package:hermes_app/src/schedules/schedule_detail.dart';
import 'package:hermes_app/src/schedules/schedules_controller.dart';
import 'package:hermes_app/src/schedules/schedules_list.dart';
import 'package:hermes_app/src/schedules/schedules_screen.dart';
import 'package:widgetbook/widgetbook.dart';

import '../test/support/cron_fixtures.dart';
import '../test/support/fake_hermes_server.dart';
import 'host.dart';

String _ago(Duration d) => DateTime.now().subtract(d).toUtc().toIso8601String();

String _in(Duration d) => DateTime.now().add(d).toUtc().toIso8601String();

/// A profile with a healthy, a failing and a paused job, plus blueprints.
FakeHermesServer schedulesServer({bool empty = false}) => FakeHermesServer()
  ..on('GET', '/api/profiles/active', activeProfileBody(active: 'work'))
  ..on(
    'GET',
    '/api/profiles',
    profileListBody([profileRow(name: 'work'), profileRow(name: 'home')]),
  )
  ..on(
    'GET',
    '/api/cron/jobs',
    empty
        ? <Object?>[]
        : [
            cronJobRow(
              id: 'job1',
              name: 'Morning brief',
              lastRunAt: _ago(const Duration(hours: 3)),
              lastStatus: 'ok',
              nextRunAt: _in(const Duration(hours: 21)),
              skills: ['news', 'calendar'],
            ),
            cronJobRow(
              id: 'job2',
              name: 'Check the status page',
              display: 'Every 30 minutes',
              schedule: {'kind': 'interval', 'minutes': 30},
              lastRunAt: _ago(const Duration(minutes: 20)),
              lastStatus: 'error',
              lastError: 'Request timed out',
              nextRunAt: _in(const Duration(minutes: 10)),
            ),
            cronJobRow(id: 'job3', name: 'Weekly digest', state: 'paused'),
          ],
  )
  ..on('GET', '/api/cron/jobs/job1/runs', [
    cronRunRow(
      id: 'run-2',
      startedAt:
          DateTime.now()
              .subtract(const Duration(hours: 3))
              .millisecondsSinceEpoch ~/
          1000,
      endedAt:
          DateTime.now()
              .subtract(const Duration(hours: 3))
              .millisecondsSinceEpoch ~/
          1000,
    ),
  ])
  ..on('GET', '/api/cron/delivery-targets', {
    'targets': [
      {'id': 'local', 'name': 'Local (save only)', 'home_target_set': true},
      {'id': 'telegram', 'name': 'Telegram', 'home_target_set': true},
    ],
  })
  ..on('GET', '/api/cron/blueprints', {
    'blueprints': [
      {
        'key': 'morning-brief',
        'title': 'Morning briefing',
        'description': 'A short daily briefing',
        'category': 'daily',
        'tags': ['daily', 'briefing'],
        'scheduleHuman': 'daily at 08:00',
        'fields': [
          {
            'name': 'time',
            'type': 'time',
            'label': 'What time?',
            'default': '08:00',
          },
          {
            'name': 'deliver',
            'type': 'enum',
            'label': 'Where to deliver?',
            'default': 'origin',
            'options': ['origin', 'local', 'telegram'],
            'strict': false,
          },
        ],
      },
      {
        'key': 'mail',
        'title': 'Important mail',
        'description': 'Check for urgent mail',
        'category': 'email',
        'tags': <String>[],
        'scheduleHuman': 'every hour',
        'fields': <Object?>[],
      },
    ],
  });

HermesCronRepository _cron(FakeHermesServer server) =>
    HermesCronRepository(server.client().raw);

Future<SchedulesController> _controller(FakeHermesServer server) async {
  final controller = SchedulesController(
    repository: _cron(server),
    profiles: HermesProfilesRepository(server.client().raw),
  );
  await controller.refresh();
  return controller;
}

WidgetbookUseCase _withController(
  String name,
  Widget Function(SchedulesController controller) build, {
  bool empty = false,
}) => WidgetbookUseCase(
  name: name,
  builder: (_) => Hosted<SchedulesController>(
    create: () => _controller(schedulesServer(empty: empty)),
    dispose: (controller) => controller.dispose(),
    builder: (_, controller) => build(controller),
  ),
);

WidgetbookNode schedulesScreensNode() => WidgetbookFolder(
  name: 'Schedule screens',
  children: [
    WidgetbookComponent(
      name: 'SchedulesScreen',
      useCases: [
        _withController(
          'Jobs',
          (controller) =>
              SchedulesScreen(controller: controller, onOpenRun: (_, _) {}),
        ),
        _withController(
          'No jobs',
          (controller) =>
              SchedulesScreen(controller: controller, onOpenRun: (_, _) {}),
          empty: true,
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'SchedulesList',
      useCases: [
        _withController(
          'Jobs',
          (controller) => Scaffold(
            body: SchedulesList(controller: controller, onSelect: (_) {}),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'ScheduleDetail',
      useCases: [
        for (final (name, index) in [
          ('Healthy job', 0),
          ('Failing job', 1),
          ('Paused job', 2),
        ])
          _withController(
            name,
            (controller) => Scaffold(
              body: ScheduleDetail(
                controller: controller,
                job: controller.jobs[index],
                onOpenRun: (_, _) {},
              ),
            ),
          ),
      ],
    ),
    WidgetbookComponent(
      name: 'JobFormScreen',
      useCases: [
        WidgetbookUseCase(
          name: 'New task',
          builder: (_) => Hosted<JobFormController>(
            create: () => JobFormController(
              repository: _cron(schedulesServer()),
              profile: 'work',
            ),
            dispose: (controller) => controller.dispose(),
            builder: (_, controller) => JobFormScreen(
              controller: controller,
              profileNames: const ['work', 'home'],
            ),
          ),
        ),
        _withController(
          'Editing a task',
          (controller) => JobFormScreen(
            controller: JobFormController(
              repository: controller.repository,
              editing: controller.jobs.first,
            ),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'BlueprintGalleryScreen',
      useCases: [
        WidgetbookUseCase(
          name: 'Gallery',
          builder: (_) => Hosted<HermesCronRepository>(
            create: () => _cron(schedulesServer()),
            builder: (_, repository) => BlueprintGalleryScreen(
              repository: repository,
              profile: 'work',
              profileNames: const ['work', 'home'],
            ),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'BlueprintFormScreen',
      useCases: [
        WidgetbookUseCase(
          name: 'Morning briefing',
          builder: (_) => Hosted<BlueprintFormController>(
            create: () async {
              final repository = _cron(schedulesServer());
              final blueprints = await repository.blueprints();
              return BlueprintFormController(
                repository: repository,
                blueprint: blueprints.first,
                profile: 'work',
              );
            },
            dispose: (controller) => controller.dispose(),
            builder: (_, controller) =>
                BlueprintFormScreen(controller: controller),
          ),
        ),
      ],
    ),
  ],
);
