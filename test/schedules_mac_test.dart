import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/macos/mac_commands.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/schedules/blueprint_screens.dart';
import 'package:hermes_app/src/schedules/hermes_cron_repository.dart';
import 'package:hermes_app/src/schedules/job_form_screen.dart';
import 'package:hermes_app/src/schedules/schedules_controller.dart';
import 'package:hermes_app/src/schedules/schedules_list.dart';
import 'package:hermes_app/src/schedules/schedules_screen.dart';
import 'package:hermes_app/src/schedules/widgets/mac_schedule_detail.dart';
import 'package:hermes_app/src/schedules/widgets/schedules_mac_toolbar.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/cron_fixtures.dart';
import 'support/fake_hermes_server.dart';
import 'support/mac_commands_builder.dart';

void main() {
  late FakeHermesServer server;
  late SharedPreferencesAsync prefs;
  late SchedulesController controller;

  final now = DateTime.utc(2026, 9, 20, 12);

  final healthy = cronJobRow(
    lastRunAt: '2026-09-20T10:00:00+00:00',
    lastStatus: 'ok',
    nextRunAt: '2026-09-20T15:00:00+00:00',
  );
  final failing = cronJobRow(
    id: 'job2',
    name: 'Price watch',
    lastRunAt: '2026-09-20T11:20:00+00:00',
    lastStatus: 'error',
    lastError: 'Provider timeout',
  );
  final elsewhere = cronJobRow(id: 'job3', name: 'Garden', profile: 'home');

  SchedulesController build() => SchedulesController(
    repository: HermesCronRepository(server.client().raw),
    profiles: HermesProfilesRepository(server.client().raw),
    prefs: prefs,
    now: () => now,
  );

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    prefs = SharedPreferencesAsync();
    server = FakeHermesServer()
      ..on('GET', '/api/profiles/active', {'active': 'work', 'current': 'work'})
      ..on('GET', '/api/cron/jobs', [healthy, failing])
      ..on(
        'GET',
        '/api/cron/jobs',
        [healthy, failing, elsewhere],
        query: {'profile': 'all'},
      )
      ..on('GET', '/api/cron/jobs/job1', healthy)
      ..on('GET', '/api/cron/jobs/job2', failing)
      ..on('GET', '/api/cron/jobs/job1/runs', {'runs': <Object?>[]})
      ..on('GET', '/api/cron/jobs/job2/runs', {'runs': <Object?>[]});
    controller = build();
  });

  tearDown(() => controller.dispose());

  Future<void> pumpScreen(
    WidgetTester tester, {
    TargetPlatform platform = TargetPlatform.macOS,
    Size size = const Size(1000, 800),
    MacCommandRegistry? commands,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesLightTheme().copyWith(platform: platform),
        builder: macCommandsBuilder(commands),
        home: SchedulesScreen(controller: controller, onOpenRun: (_, _) {}),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder profileChip(String name) => find.textContaining(' · $name');

  group('toolbar', () {
    testWidgets('File > New Schedule (command-N) opens the gallery', (
      tester,
    ) async {
      server.on('GET', '/api/profiles', {'profiles': <Object>[]});
      final commands = MacCommandRegistry();
      addTearDown(commands.dispose);
      await pumpScreen(tester, commands: commands);
      expect(commands.handlerFor(MacCommand.newChat)?.title, 'New Schedule');

      expect(commands.invoke(MacCommand.newChat), isTrue);
      await tester.pumpAndSettle();

      expect(find.byType(BlueprintGalleryScreen), findsOneWidget);
    });

    testWidgets('names the page and counts the jobs listed', (tester) async {
      await pumpScreen(tester);

      expect(find.byType(SchedulesMacToolbar), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
      expect(find.text('Schedules'), findsOneWidget);
      expect(find.text('2 jobs'), findsOneWidget);
      expect(find.byTooltip('New Schedule ⌘N'), findsOneWidget);
      expect(find.byTooltip('Refresh'), findsOneWidget);
    });

    testWidgets('Refresh lists the jobs again', (tester) async {
      await pumpScreen(tester);
      final before = server.requestsTo('GET', '/api/cron/jobs').length;

      await tester.tap(find.byTooltip('Refresh'));
      await tester.pumpAndSettle();

      expect(server.requestsTo('GET', '/api/cron/jobs').length, before + 1);
    });
  });

  group('scope', () {
    testWidgets('All profiles lists every profile and names it', (
      tester,
    ) async {
      await pumpScreen(tester);
      expect(find.text('Garden'), findsNothing);
      expect(profileChip('work'), findsNothing);

      await tester.tap(find.text('All profiles'));
      await tester.pumpAndSettle();

      expect(find.text('Garden'), findsOneWidget);
      expect(find.text('3 jobs'), findsOneWidget);
      expect(profileChip('home'), findsOneWidget);
      expect(profileChip('work'), findsWidgets);
    });

    testWidgets('the scope is kept for the next launch', (tester) async {
      await pumpScreen(tester);
      await tester.tap(find.text('All profiles'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      controller.dispose();

      controller = build();
      await pumpScreen(tester);

      expect(find.text('Garden'), findsOneWidget);
      expect(await prefs.getBool('hermes.schedules_all_profiles'), isTrue);
    });

    testWidgets('the filter menu leaves the scope to the toolbar', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.tap(find.byKey(const Key('schedule-filter')));
      await tester.pumpAndSettle();

      expect(find.text('Paused'), findsWidgets);
      expect(find.textContaining('(active)'), findsNothing);
    });

    testWidgets('an empty profile says so', (tester) async {
      server.on('GET', '/api/cron/jobs', <Object?>[]);

      await pumpScreen(tester);

      expect(find.text('No schedules in this profile'), findsOneWidget);
    });
  });

  group('list', () {
    testWidgets('a right click on a job offers its actions', (tester) async {
      await pumpScreen(tester);

      await tester.tap(
        find.widgetWithText(JobTile, 'Morning brief'),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();

      expect(find.text('Run now'), findsNWidgets(2));
      expect(find.text('Delete'), findsOneWidget);
    });
  });

  group('detail', () {
    testWidgets('sits beside the list, even in a compact window', (
      tester,
    ) async {
      await pumpScreen(tester, size: const Size(680, 640));

      expect(find.byType(MacScheduleDetail), findsOneWidget);
      expect(find.text('Morning brief'), findsWidgets);
    });

    testWidgets('shows a failure card only for a failed job', (tester) async {
      await pumpScreen(tester);
      final badge = find.descendant(
        of: find.byType(MacScheduleDetail),
        matching: find.text('Failed'),
      );
      expect(badge, findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(MacScheduleDetail),
          matching: find.text('Provider timeout · 40 min ago'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Morning brief'));
      await tester.pumpAndSettle();

      expect(badge, findsNothing);
    });

    testWidgets('Run now asks the server for a run', (tester) async {
      server.on('POST', '/api/cron/jobs/job2/trigger', {'ok': true});
      await pumpScreen(tester);

      await tester.tap(find.text('Run now'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Run requested'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(
        server.requestsTo('POST', '/api/cron/jobs/job2/trigger'),
        hasLength(1),
      );
    });

    testWidgets('Edit opens the job form', (tester) async {
      server
        ..on('GET', '/api/cron/delivery-targets', {'targets': <Object?>[]})
        ..on('GET', '/api/model/options', {'providers': <Object?>[]});
      await pumpScreen(tester);

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(find.byType(JobFormScreen), findsOneWidget);
    });

    testWidgets('the More menu pauses the job', (tester) async {
      server.on('POST', '/api/cron/jobs/job2/pause', {'ok': true});
      await pumpScreen(tester);

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pause'));
      await tester.pumpAndSettle();

      expect(
        server.requestsTo('POST', '/api/cron/jobs/job2/pause'),
        hasLength(1),
      );
    });
  });

  group('other platforms', () {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      testWidgets('$platform keeps its app bar and filter menu', (
        tester,
      ) async {
        await pumpScreen(tester, platform: platform);

        expect(find.byType(SchedulesMacToolbar), findsNothing);
        expect(find.byType(MacScheduleDetail), findsNothing);
        expect(find.byType(AppBar), findsOneWidget);
        expect(find.byKey(const Key('schedule-filter')), findsOneWidget);
        await tester.tap(find.byKey(const Key('settings-subtitle-menu')));
        await tester.pumpAndSettle();
        expect(find.text('All profiles'), findsOneWidget);
      });
    }
  });
}
