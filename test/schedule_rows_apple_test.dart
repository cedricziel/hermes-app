import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/schedules/hermes_cron_repository.dart';
import 'package:hermes_app/src/schedules/schedules_controller.dart';
import 'package:hermes_app/src/schedules/schedules_list.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

import 'support/cron_fixtures.dart';
import 'support/fake_hermes_server.dart';

void main() {
  late FakeHermesServer server;
  late SchedulesController controller;

  setUp(() {
    server = FakeHermesServer()
      ..on('GET', '/api/profiles/active', {'active': 'work', 'current': 'work'})
      ..on('GET', '/api/cron/jobs', [
        cronJobRow(),
        cronJobRow(id: 'job2', name: 'Price watch'),
      ]);
    controller = SchedulesController(
      repository: HermesCronRepository(server.client().raw),
      profiles: HermesProfilesRepository(server.client().raw),
      now: () => DateTime.utc(2026, 9, 20, 12),
    );
  });

  tearDown(() => controller.dispose());

  Future<void> pumpList(WidgetTester tester, TargetPlatform platform) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    unawaited(controller.refresh());
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildHermesLightTheme().copyWith(platform: platform),
        home: Scaffold(
          body: SchedulesList(controller: controller, onSelect: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('row layout', () {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
      testWidgets('jobs are rows of one inset grouped list on $platform', (
        tester,
      ) async {
        await pumpList(tester, platform);

        expect(find.byType(CupertinoListSection), findsOneWidget);
        expect(find.text('Morning brief'), findsOneWidget);
        expect(find.text('Price watch'), findsOneWidget);
        expect(find.text('Weekdays at 08:00'), findsNWidgets(2));
      });
    }

    testWidgets('jobs stay separate cards on Android', (tester) async {
      await pumpList(tester, TargetPlatform.android);

      expect(find.byType(CupertinoListSection), findsNothing);
      expect(find.text('Morning brief'), findsOneWidget);
    });
  });

  group('row actions', () {
    testWidgets('swiping a job left deletes it after confirming', (
      tester,
    ) async {
      server.on('DELETE', '/api/cron/jobs/job1', {'ok': true});
      await pumpList(tester, TargetPlatform.iOS);

      await tester.drag(find.text('Morning brief'), const Offset(-300, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(server.requestsTo('DELETE', '/api/cron/jobs/job1'), isEmpty);
      await tester.tap(find.widgetWithText(CupertinoDialogAction, 'Delete'));
      await tester.pumpAndSettle();

      expect(server.requestsTo('DELETE', '/api/cron/jobs/job1'), hasLength(1));
      expect(find.text('Morning brief'), findsNothing);
    });

    testWidgets('cancelling the confirmation keeps the job', (tester) async {
      await pumpList(tester, TargetPlatform.iOS);

      await tester.drag(find.text('Morning brief'), const Offset(-300, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(server.requests.any((r) => r.method == 'DELETE'), isFalse);
      expect(find.text('Morning brief'), findsOneWidget);
    });

    testWidgets('a long press offers run now, pause and delete', (
      tester,
    ) async {
      server.on('POST', '/api/cron/jobs/job1/trigger', {'ok': true});
      await pumpList(tester, TargetPlatform.iOS);

      await tester.longPress(find.text('Morning brief'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActionSheet), findsOneWidget);
      expect(find.text('Pause'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      await tester.tap(find.text('Run now'));
      await tester.pumpAndSettle();

      expect(
        server.requestsTo('POST', '/api/cron/jobs/job1/trigger'),
        hasLength(1),
      );
    });

    testWidgets('a paused job offers resume', (tester) async {
      server.on('GET', '/api/cron/jobs', [cronJobRow(state: 'paused')]);
      await pumpList(tester, TargetPlatform.iOS);

      await tester.longPress(find.text('Morning brief'));
      await tester.pumpAndSettle();

      expect(find.text('Resume'), findsOneWidget);
      expect(find.text('Pause'), findsNothing);
    });

    testWidgets('Android rows do not swipe', (tester) async {
      await pumpList(tester, TargetPlatform.android);

      await tester.drag(find.text('Morning brief'), const Offset(-300, 0));
      await tester.pumpAndSettle();

      expect(find.text('Delete'), findsNothing);
    });
  });
}
