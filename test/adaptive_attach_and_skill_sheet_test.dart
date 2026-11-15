import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/attachments/attachment_source.dart';
import 'package:hermes_app/src/chat/attachments/attachment_surface.dart';
import 'package:hermes_app/src/skills/hermes_skills_hub_repository.dart';
import 'package:hermes_app/src/skills/skill_job.dart';
import 'package:hermes_app/src/skills/skill_job_sheet.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/adaptive_sheet.dart';

import 'support/fake_attachment_source.dart';

final _handle = find.byWidgetPredicate(
  (w) => w.runtimeType.toString() == '_DragHandle',
);

void _size(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _surface(FakeAttachmentSource source) => MaterialApp(
  home: AttachmentSurface(
    source: source,
    onAdd: (_) {},
    builder: (context, openMenu) => Scaffold(
      body: TextButton(onPressed: openMenu, child: const Text('Open')),
    ),
  ),
);

void main() {
  for (final (width, wide) in [(1024.0, true), (390.0, false)]) {
    final label = wide ? 'dialog at $width' : 'sheet at $width';

    testWidgets('attach menu shows as a $label and returns the pick', (
      tester,
    ) async {
      _size(tester, width);
      final source = FakeAttachmentSource();
      await tester.pumpWidget(_surface(source));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), wide ? findsOneWidget : findsNothing);
      expect(find.byType(BottomSheet), wide ? findsNothing : findsOneWidget);
      expect(find.byType(ListTile), findsNWidgets(3));
      expect(find.text('Attach'), wide ? findsOneWidget : findsNothing);
      expect(_handle, wide ? findsNothing : findsOneWidget);
      await tester.tap(find.byType(ListTile).at(1));
      await tester.pumpAndSettle();
      expect(source.requested, [AttachOrigin.photos]);
      expect(find.byType(ListTile), findsNothing);
    });

    testWidgets('skill job status shows as a $label', (tester) async {
      _size(tester, width);
      final job = SkillJob(
        title: 'Updating',
        start: () async => const StartedJob(name: 'fixture'),
        status: (_) async => const JobStatus(running: false, exitCode: 0),
      );
      await job.run();
      addTearDown(job.dispose);
      await tester.pumpWidget(
        MaterialApp(
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
      expect(find.byType(Dialog), wide ? findsOneWidget : findsNothing);
      expect(find.byType(BottomSheet), wide ? findsNothing : findsOneWidget);
      expect(_handle, wide ? findsNothing : findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(SkillJobSheet), findsNothing);
    });
  }

  testWidgets('a single origin picks directly without a menu', (tester) async {
    _size(tester, 1024);
    final source = FakeAttachmentSource(origins: [AttachOrigin.files]);
    await tester.pumpWidget(_surface(source));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(source.requested, [AttachOrigin.files]);
    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('a second press while the picker is open opens nothing', (
    tester,
  ) async {
    _size(tester, 1024);
    final source = FakeAttachmentSource(origins: [AttachOrigin.files])
      ..gate = Completer<void>();
    await tester.pumpWidget(_surface(source));
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.tap(find.text('Open'));
    await tester.pump();
    expect(source.requested, [AttachOrigin.files]);
    source.gate!.complete();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(source.requested, [AttachOrigin.files, AttachOrigin.files]);
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final failed in [true, false]) {
      final state = failed ? 'failed' : 'running';
      testWidgets(
        'the phone skill job sheet at 320x568 and x2.0 text, $state on '
        '${platform.name}, scrolls and keeps its button reachable',
        (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = 2.0;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final lines = [
            for (var i = 1; i <= 9; i++)
              'Step $i of 9: copying files into the skill directory',
          ];
          final gate = Completer<void>();
          final job = SkillJob(
            title: 'Installing a skill with a rather long name',
            start: () async => const StartedJob(name: 'j', pid: 1),
            status: (_) async => JobStatus(
              running: !failed,
              exitCode: failed ? 1 : null,
              pid: 1,
              lines: lines,
            ),
            // A running job waits for its next poll; a failed one is done.
            wait: (_) => gate.future,
          );
          addTearDown(job.dispose);
          addTearDown(gate.complete);
          unawaited(job.run());
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          await tester.pumpWidget(
            MaterialApp(
              theme: buildHermesLightTheme(platform: platform),
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
          await tester.pump(const Duration(seconds: 1));
          await tester.pump(const Duration(seconds: 1));
          expect(tester.takeException(), isNull);
          expect(find.byType(BottomSheet), findsOneWidget);
          expect(
            find.descendant(
              of: find.byType(SkillJobSheet),
              matching: find.byType(SingleChildScrollView),
            ),
            findsOneWidget,
          );
          expect(find.byKey(const ValueKey('job-log')), findsOneWidget);
          final label = failed ? 'Close' : 'Run in background';
          expect(job.running, !failed);
          await tester.ensureVisible(find.text(label));
          await tester.pump();
          await tester.tap(find.text(label));
          await tester.pump(const Duration(seconds: 1));
          await tester.pump(const Duration(seconds: 1));
          expect(find.byType(SkillJobSheet), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'a capped bottom sheet on Android at 800 pt is at most 640 wide',
    (tester) async {
      _size(tester, 800);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showAdaptiveSheet<void>(
                  context,
                  maxSheetHeightFraction: 0.9,
                  builder: (_) =>
                      const SizedBox(width: double.infinity, height: 100),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      // 800 pt is below the wide breakpoint, so this is a bottom sheet.
      expect(find.byType(BottomSheet), findsOneWidget);
      // The sheet's own surface, not the full-width slot it is aligned in.
      final surface = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(Material),
      );
      expect(tester.getSize(surface.first).width, lessThanOrEqualTo(640));
    },
  );
}
