import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/schedules/blueprint_screens.dart';
import 'package:hermes_app/src/schedules/hermes_cron_repository.dart';
import 'package:hermes_app/src/schedules/schedule_detail.dart';
import 'package:hermes_app/src/schedules/schedules_controller.dart';
import 'package:hermes_app/src/schedules/schedules_screen.dart';

import 'support/cron_fixtures.dart';
import 'support/fake_hermes_server.dart';

void main() {
  late FakeHermesServer server;
  late ValueNotifier<bool> activity;
  late SchedulesController controller;
  var disposed = false;

  setUp(() {
    disposed = false;
    activity = ValueNotifier(true);
    server = FakeHermesServer()
      ..on('GET', '/api/profiles/active', {'active': 'work'})
      ..on('GET', '/api/cron/jobs', [cronJobRow()])
      ..on('GET', '/api/cron/jobs/job1', cronJobRow())
      ..on('GET', '/api/cron/jobs/job1/runs', {'runs': []});
    controller = SchedulesController(
      activity: activity,
      repository: HermesCronRepository(server.client().raw),
      profiles: HermesProfilesRepository(server.client().raw),
    );
  });

  tearDown(() {
    if (!disposed) controller.dispose();
    activity.dispose();
  });

  Future<void> detail(WidgetTester tester) async {
    await tester.runAsync(controller.refresh);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScheduleDetail(
            controller: controller,
            job: controller.jobs.single,
            onOpenRun: (_, _) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'held run completion after controller disposal is silently dropped',
    (tester) async {
      await detail(tester);
      final answer = Completer<FakeResponse>();
      server.onRequest(
        'POST',
        '/api/cron/jobs/job1/trigger',
        (_) => answer.future,
      );
      await tester.tap(find.text('Run now'));
      await tester.pump();
      controller.dispose();
      disposed = true;
      answer.complete((status: 200, body: {'ok': true}));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Run requested'), findsNothing);
      expect(
        server.requestsTo('GET', '/api/cron/jobs/job1/runs'),
        hasLength(1),
      );
    },
  );

  testWidgets('retired profile lookup does not open the creation gallery', (
    tester,
  ) async {
    await tester.runAsync(controller.refresh);
    await tester.pumpWidget(
      MaterialApp(
        home: SchedulesScreen(controller: controller, onOpenRun: (_, _) {}),
      ),
    );
    await tester.pumpAndSettle();
    final answer = Completer<FakeResponse>();
    server.onRequest('GET', '/api/profiles', (_) => answer.future);
    await tester.tap(find.byKey(const Key('schedules-new')));
    await tester.pump();
    activity.value = false;
    answer.complete((status: 200, body: {'profiles': []}));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(BlueprintGalleryScreen), findsNothing);
  });

  testWidgets('run history delay cannot follow a retired activity period', (
    tester,
  ) async {
    await detail(tester);
    server.on('POST', '/api/cron/jobs/job1/trigger', {'ok': true});
    await tester.tap(find.text('Run now'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Run requested'), findsOneWidget);
    activity.value = false;
    activity.value = true;
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(server.requestsTo('GET', '/api/cron/jobs/job1/runs'), hasLength(1));
  });
}
