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
}
