import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/widgets/grouped_form.dart';
import 'package:hermes_app/src/kanban/kanban_models.dart';
import 'package:hermes_app/src/kanban/widgets/task_panel/kanban_task_attachments.dart';
import 'package:hermes_app/src/kanban/widgets/task_panel/kanban_task_comments.dart';
import 'package:hermes_app/src/kanban/widgets/task_panel/kanban_task_runs.dart';

import '../support/screenshot_recorder.dart';
import '../support/workflow_app.dart';

void main() {
  for (final (name, platform, size, brightness) in [
    ('ios', TargetPlatform.iOS, phoneSize, Brightness.light),
    ('ios-dark', TargetPlatform.iOS, phoneSize, Brightness.dark),
    ('mac', TargetPlatform.macOS, desktopSize, Brightness.light),
    ('mac-dark', TargetPlatform.macOS, desktopSize, Brightness.dark),
  ]) {
    testWidgets('$name: task activity preserves recovery and actions', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final shots = ScreenshotRecorder('task-activity-$name');
      var accept = false;
      final sent = <String>[];
      var terminated = 0;
      var saved = 0;
      var removed = 0;
      await pumpScreen(
        tester,
        shots,
        Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  KanbanTaskComments(
                    comments: const [
                      KanbanComment(
                        author: 'Example worker',
                        body: 'The example guide is ready for review.',
                      ),
                    ],
                    onSend: (text) async {
                      sent.add(text);
                      return accept;
                    },
                  ),
                  KanbanTaskAttachments(
                    attachments: const [
                      KanbanAttachment(
                        id: 1,
                        filename:
                            'example-migration-guide-with-a-long-file-name.txt',
                        size: 1024,
                      ),
                    ],
                    onAttach: () {},
                    onDownload: (_) => saved++,
                    onRemove: (_) => removed++,
                  ),
                  KanbanTaskRuns(
                    runs: const [
                      KanbanRun(
                        id: 1,
                        status: 'done',
                        summary: 'Prepared the example guide.',
                      ),
                      KanbanRun(id: 2, status: 'running'),
                    ],
                    events: const [
                      KanbanEvent(kind: 'created'),
                      KanbanEvent(kind: 'claimed'),
                    ],
                    taskRunning: true,
                    onTerminate: (_) => terminated++,
                    onShowLog: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
        size: size,
        platform: platform,
        brightness: brightness,
      );
      await shots.capture(tester, 'activity');
      final field = find.descendant(
        of: find.byType(GroupedTextFieldRow),
        matching: find.byType(EditableText),
      );
      await tester.enterText(field, ' Retry this comment ');
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();
      expect(find.text(' Retry this comment '), findsOneWidget);
      await shots.capture(tester, 'comment-refused');
      accept = true;
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();
      expect(sent, ['Retry this comment', 'Retry this comment']);
      expect(tester.widget<EditableText>(field).controller.text, isEmpty);
      await tester.scrollUntilVisible(
        find.byTooltip('Save attachment'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byTooltip('Save attachment'));
      await tester.tap(find.byTooltip('Remove attachment'));
      expect((saved, removed), (1, 1));
      expect(
        find.bySemanticsLabel(
          'Save example-migration-guide-with-a-long-file-name.txt',
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'Remove example-migration-guide-with-a-long-file-name.txt',
        ),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('Runs (2)'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Runs (2)'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Terminate'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Terminate'), findsOneWidget);
      expect(find.bySemanticsLabel('Terminate'), findsOneWidget);
      await tester.tap(find.text('Terminate'));
      expect(terminated, 1);
      await tester.scrollUntilVisible(
        find.text('History'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('created'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester.getTopLeft(find.text('claimed')).dy,
        lessThan(tester.getTopLeft(find.text('created')).dy),
      );
      await shots.capture(tester, 'runs-history');
      semantics.dispose();
    });
  }
}
