import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/skills/hermes_skills_hub_repository.dart';
import 'package:hermes_app/src/skills/skill_job.dart';
import 'package:hermes_app/src/skills/skill_job_sheet.dart';
import 'package:hermes_app/src/skills/skills_hub_controller.dart';
import 'package:hermes_app/src/skills/hermes_skills_repository.dart';
import 'package:hermes_app/src/skills/skills_controller.dart';

import 'support/fake_hermes_server.dart';

void main() {
  testWidgets('short Mac status dialog sizes to its content', (tester) async {
    final job = SkillJob(
      title: 'Updating',
      start: () async => const StartedJob(name: 'fixture'),
      status: (_) async => const JobStatus(running: false, exitCode: 0),
    );
    await job.run();
    addTearDown(job.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.macOS),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showSkillJobStatus(context, job),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(SkillJobSheet)).height, lessThan(250));
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  for (final running in [true, false]) {
    testWidgets(
      'Mac long logs remain scrollable at text scale 2: running=$running',
      (tester) async {
        final waiting = Completer<void>();
        final job = SkillJob(
          title: 'Installing a demonstration skill',
          start: () async => const StartedJob(name: 'fixture'),
          status: (_) async => JobStatus(
            running: running,
            exitCode: running ? null : 0,
            lines: List.filled(
              6,
              'A long invented output line describing installation steps and package verification. ' *
                  8,
            ),
          ),
          wait: (_) => waiting.future,
        );
        unawaited(job.run());
        addTearDown(() {
          job.dispose();
          waiting.complete();
        });
        tester.view.physicalSize = const Size(390, 400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: TargetPlatform.macOS),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showSkillJobStatus(context, job),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.takeException(), isNull);
        final close = find.text(running ? 'Run in background' : 'Close');
        expect(close.hitTestable(), findsOneWidget);
        final scroll = find.byType(SingleChildScrollView);
        final scrollable = tester.state<ScrollableState>(
          find.descendant(of: scroll, matching: find.byType(Scrollable)),
        );
        expect(scrollable.position.maxScrollExtent, greaterThan(0));
        await tester.drag(scroll, const Offset(0, -200));
        await tester.pump();
        expect(scrollable.position.pixels, greaterThan(0));
        expect(close.hitTestable(), findsOneWidget);
        await tester.tap(close);
        await tester.pumpAndSettle();
        expect(find.text('Open'), findsOneWidget);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );
  }
  for (final platform in [
    TargetPlatform.macOS,
    TargetPlatform.iOS,
    TargetPlatform.android,
  ]) {
    testWidgets(
      '$platform job status preserves background work and completion',
      (tester) async {
        final server = FakeHermesServer();
        final skills = SkillsController(
          chatProfile: null,
          repository: HermesSkillsRepository(server.client().raw),
        );
        final completion = Completer<FakeResponse>();
        server.on('POST', '/api/skills/hub/update', {
          'name': 'fixture',
          'pid': 1,
        });
        server.onRequest(
          'GET',
          '/api/actions/fixture/status',
          (_) => completion.future,
        );
        final hub = SkillsHubController(
          repository: HermesSkillsHubRepository(server.client().raw),
          skills: skills,
        );
        addTearDown(() {
          hub.dispose();
          skills.dispose();
        });
        final job = hub.update()!;
        tester.view.physicalSize = const Size(390, 500);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showSkillJobSheet(context, hub),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          find.byType(BottomSheet),
          platform == TargetPlatform.macOS ? findsNothing : findsOneWidget,
        );
        expect(hub.sheetOpen, true);
        await tester.tap(find.text('Run in background'));
        await tester.pumpAndSettle();
        expect(hub.sheetOpen, false);
        expect(hub.job, same(job));
        expect(job.running, true);
        completion.complete((
          status: 200,
          body: jobStatusBody(name: 'fixture', pid: 1),
        ));
        for (var i = 0; i < 100 && job.running; i++) {
          await tester.pump(const Duration(milliseconds: 10));
        }
        expect(job.state, JobState.succeeded);
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        expect(hub.job, isNull);
      },
      variant: TargetPlatformVariant.only(platform),
    );
  }
}
