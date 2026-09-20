import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/schedules/hermes_cron_repository.dart';
import 'package:hermes_app/src/schedules/schedule_detail.dart';
import 'package:hermes_app/src/schedules/schedules_controller.dart';
import 'package:hermes_app/src/schedules/schedules_screen.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

import 'support/cron_fixtures.dart';
import 'support/fake_hermes_server.dart';

void main() {
  late FakeHermesServer server;
  late SchedulesController controller;

  final blueprints = {
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
        'tags': [],
        'scheduleHuman': 'every hour',
        'fields': [],
      },
    ],
  };

  setUp(() {
    server = FakeHermesServer()
      ..on('GET', '/api/profiles/active', {'active': 'work', 'current': 'work'})
      ..on(
        'GET',
        '/api/profiles',
        profileListBody([profileRow(name: 'work'), profileRow(name: 'home')]),
      )
      ..on('GET', '/api/cron/jobs', [])
      ..on('GET', '/api/cron/blueprints', blueprints)
      ..on('GET', '/api/cron/delivery-targets', {
        'targets': [
          {'id': 'local', 'name': 'Local (save only)', 'home_target_set': true},
          {'id': 'discord', 'name': 'Discord', 'home_target_set': false},
        ],
      });
    controller = SchedulesController(
      repository: HermesCronRepository(server.client().raw),
      profiles: HermesProfilesRepository(server.client().raw),
      now: () => DateTime(2026, 9, 20, 12),
    );
  });

  tearDown(() => controller.dispose());

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesLightTheme(),
        home: SchedulesScreen(controller: controller, onOpenRun: (_, _) {}),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openGallery(WidgetTester tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();
  }

  Future<void> openCustom(WidgetTester tester) async {
    await openGallery(tester);
    await tester.tap(find.byKey(const Key('custom-task')));
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String key, String text) async {
    final finder = find.byKey(Key(key));
    await tester.ensureVisible(finder);
    await tester.enterText(finder, text);
    await tester.pump();
  }

  group('gallery', () {
    testWidgets('offers a custom task and the server blueprints', (
      tester,
    ) async {
      await openGallery(tester);

      expect(find.text('Custom task'), findsOneWidget);
      expect(find.text('Morning briefing'), findsOneWidget);
      expect(find.text('daily at 08:00'), findsOneWidget);
      expect(find.text('Important mail'), findsOneWidget);
    });

    testWidgets('search narrows the templates', (tester) async {
      await openGallery(tester);

      await tester.enterText(
        find.byKey(const Key('blueprint-search')),
        'urgent',
      );
      await tester.pump();

      expect(find.text('Important mail'), findsOneWidget);
      expect(find.text('Morning briefing'), findsNothing);
    });

    testWidgets('a category chip narrows the templates', (tester) async {
      await openGallery(tester);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Daily'));
      await tester.pump();

      expect(find.text('Morning briefing'), findsOneWidget);
      expect(find.text('Important mail'), findsNothing);
    });

    testWidgets('still offers a custom task when the templates fail', (
      tester,
    ) async {
      server.on('GET', '/api/cron/blueprints', {}, status: 500);

      await openGallery(tester);

      expect(find.text('Custom task'), findsOneWidget);
      expect(find.text('The templates could not be loaded.'), findsOneWidget);
    });
  });

  group('blueprint form', () {
    Future<void> openBlueprint(WidgetTester tester) async {
      await openGallery(tester);
      await tester.tap(find.text('Morning briefing'));
      await tester.pumpAndSettle();
    }

    testWidgets('starts at the defaults and creates the job', (tester) async {
      server
        ..on(
          'POST',
          '/api/cron/blueprints/instantiate',
          cronJobRow(id: 'b', name: 'Morning briefing'),
          query: {'profile': 'work'},
        )
        ..on('GET', '/api/cron/jobs', [
          cronJobRow(id: 'b', name: 'Morning briefing'),
        ])
        ..on(
          'GET',
          '/api/cron/jobs/b',
          cronJobRow(id: 'b', name: 'Morning briefing'),
        )
        ..on('GET', '/api/cron/jobs/b/runs', {'runs': []});
      await openBlueprint(tester);
      expect(find.text('08:00'), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'origin'))
            .selected,
        isTrue,
      );

      await tester.tap(find.widgetWithText(ChoiceChip, 'telegram'));
      await tester.pump();
      await tester.tap(find.text('Create task'));
      await tester.pumpAndSettle();

      expect(
        server.requests.any(
          (r) => r.path == '/api/cron/blueprints/instantiate',
        ),
        isTrue,
      );
      final body = jsonDecode(
        server.requests
                .firstWhere((r) => r.path == '/api/cron/blueprints/instantiate')
                .data
            as String,
      );
      expect(body, {
        'blueprint': 'morning-brief',
        'values': {'time': '08:00', 'deliver': 'telegram'},
      });
      // The created job is on screen.
      expect(find.byType(ScheduleDetail), findsOneWidget);
    });

    testWidgets('shows a refused slot under it and keeps the values', (
      tester,
    ) async {
      server.on('POST', '/api/cron/blueprints/instantiate', {
        'detail': "invalid time '25:00' — use HH:MM (24h)",
      }, status: 422);
      await openBlueprint(tester);

      await tester.tap(find.text('Create task'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('slot-error-time')), findsOneWidget);
      expect(find.text('Create task'), findsOneWidget);
      expect(find.text('08:00'), findsOneWidget);
    });
  });

  group('job form', () {
    testWidgets('creates a job from Every 6 hours', (tester) async {
      server
        ..on(
          'POST',
          '/api/cron/jobs',
          cronJobRow(id: 'new', name: 'GPU'),
          query: {'profile': 'work'},
        )
        ..on('GET', '/api/cron/jobs/new', cronJobRow(id: 'new', name: 'GPU'))
        ..on('GET', '/api/cron/jobs/new/runs', {'runs': []});
      await openCustom(tester);

      await type(tester, 'job-name', 'GPU');
      await type(tester, 'job-prompt', 'Check the price');
      await tester.tap(find.widgetWithText(ChoiceChip, 'Every'));
      await tester.pump();
      await type(tester, 'when-amount', '6');
      await tester.tap(find.byKey(const Key('when-unit')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('hours').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('when-preview')), findsOneWidget);
      await tester.ensureVisible(find.text('Save task'));
      await tester.tap(find.text('Save task'));
      await tester.pumpAndSettle();

      final post = server.requests.lastWhere(
        (r) => r.method == 'POST' && r.path == '/api/cron/jobs',
      );
      expect(jsonDecode(post.data as String), {
        'paused': false,
        'prompt': 'Check the price',
        'schedule': 'every 6h',
        'name': 'GPU',
        'deliver': 'local',
        'no_agent': false,
      });
    });

    testWidgets('weekly writes the chosen days', (tester) async {
      server.on('POST', '/api/cron/jobs', cronJobRow(id: 'w'));
      server.on('GET', '/api/cron/jobs/w', cronJobRow(id: 'w'));
      server.on('GET', '/api/cron/jobs/w/runs', {'runs': []});
      await openCustom(tester);
      await type(tester, 'job-prompt', 'Weekly thing');

      await tester.tap(find.widgetWithText(ChoiceChip, 'Weekly'));
      await tester.pump();
      // Weekdays are chosen to begin with: drop Tue, Wed and Fri.
      for (final day in ['Tue', 'Wed', 'Fri']) {
        await tester.tap(find.widgetWithText(FilterChip, day));
        await tester.pump();
      }
      await tester.ensureVisible(find.text('Save task'));
      await tester.tap(find.text('Save task'));
      await tester.pumpAndSettle();

      final post = server.requests.lastWhere(
        (r) => r.method == 'POST' && r.path == '/api/cron/jobs',
      );
      expect(
        jsonDecode(post.data as String),
        containsPair('schedule', '0 8 * * 1,4'),
      );
    });

    testWidgets('a raw expression has no preview', (tester) async {
      await openCustom(tester);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Cron'));
      await tester.pump();
      await type(tester, 'when-cron', '*/7 9-17 * * 1-5');

      expect(find.byKey(const Key('when-preview')), findsNothing);
      expect(
        find.text('The server works out the next run when you save.'),
        findsOneWidget,
      );
    });

    testWidgets('refuses a task with nothing to run', (tester) async {
      await openCustom(tester);

      await tester.ensureVisible(find.text('Save task'));
      await tester.tap(find.text('Save task'));
      await tester.pump();

      expect(
        find.text('A task needs a prompt, a skill or a script'),
        findsOneWidget,
      );
      expect(server.requests.where((r) => r.method == 'POST'), isEmpty);
    });

    testWidgets('keeps the form and shows the reason on a refusal', (
      tester,
    ) async {
      server.on('POST', '/api/cron/jobs', {
        'detail': 'script must be inside /x/scripts',
      }, status: 400);
      await openCustom(tester);
      await type(tester, 'job-prompt', 'x');
      await tester.ensureVisible(find.byKey(const Key('job-advanced')));
      await tester.tap(find.byKey(const Key('job-advanced')));
      await tester.pumpAndSettle();
      await type(tester, 'job-script', '../evil.sh');

      await tester.ensureVisible(find.text('Save task'));
      await tester.tap(find.text('Save task'));
      await tester.pumpAndSettle();

      expect(find.text('script must be inside /x/scripts'), findsOneWidget);
      expect(find.text('../evil.sh'), findsOneWidget);
      expect(find.text('New task'), findsOneWidget);
    });

    testWidgets('warns when the target has no home channel', (tester) async {
      await openCustom(tester);

      await tester.tap(find.byKey(const Key('job-deliver')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discord').last);
      await tester.pumpAndSettle();

      expect(
        find.text('No home channel is set on the server for this platform.'),
        findsOneWidget,
      );
    });

    testWidgets('offers the profile choice when there are several', (
      tester,
    ) async {
      await openCustom(tester);

      expect(find.byKey(const Key('job-profile')), findsOneWidget);
    });

    testWidgets('asks before discarding entered text', (tester) async {
      await openCustom(tester);
      await type(tester, 'job-prompt', 'half a thought');

      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('New task'), findsOneWidget);

      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.text('New task'), findsNothing);
    });

    testWidgets('closes without asking when nothing was entered', (
      tester,
    ) async {
      await openCustom(tester);

      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsNothing);
      expect(find.text('New task'), findsNothing);
    });
  });

  group('edit', () {
    Future<void> openEdit(WidgetTester tester, Map<String, Object?> row) async {
      server
        ..on('GET', '/api/cron/jobs', [row])
        ..on('GET', '/api/cron/jobs/job1', row)
        ..on('GET', '/api/cron/jobs/job1/runs', {'runs': []});
      await pumpScreen(tester);
      await tester.tap(find.text('Morning brief'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
    }

    testWidgets('opens with the job\'s own values and sends only a change', (
      tester,
    ) async {
      server.on('PUT', '/api/cron/jobs/job1', cronJobRow(prompt: 'New prompt'));
      await openEdit(
        tester,
        cronJobRow(
          prompt: 'Old prompt',
          schedule: {'kind': 'interval', 'minutes': 360},
        ),
      );
      expect(find.text('Old prompt'), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Every'))
            .selected,
        isTrue,
      );
      expect(find.text('6'), findsOneWidget);

      await type(tester, 'job-prompt', 'New prompt');
      await tester.ensureVisible(find.text('Save task'));
      await tester.tap(find.text('Save task'));
      await tester.pumpAndSettle();

      final put = server.requests.lastWhere((r) => r.method == 'PUT');
      expect(jsonDecode(put.data as String), {
        'updates': {'prompt': 'New prompt'},
      });
      expect(put.queryParameters['profile'], 'work');
    });

    testWidgets('shows an unusual expression as Cron with its text', (
      tester,
    ) async {
      await openEdit(
        tester,
        cronJobRow(schedule: {'kind': 'cron', 'expr': '*/7 9-17 * * 1-5'}),
      );

      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Cron'))
            .selected,
        isTrue,
      );
      expect(find.text('*/7 9-17 * * 1-5'), findsOneWidget);
    });

    testWidgets('has no profile choice and no paused switch', (tester) async {
      await openEdit(tester, cronJobRow());

      expect(find.byKey(const Key('job-profile')), findsNothing);
      expect(find.byKey(const Key('job-paused')), findsNothing);
    });
  });
}
