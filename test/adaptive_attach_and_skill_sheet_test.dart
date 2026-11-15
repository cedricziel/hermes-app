import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/attachments/attachment_source.dart';
import 'package:hermes_app/src/chat/attachments/attachment_surface.dart';
import 'package:hermes_app/src/skills/hermes_skills_hub_repository.dart';
import 'package:hermes_app/src/skills/skill_job.dart';
import 'package:hermes_app/src/skills/skill_job_sheet.dart';

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
}
