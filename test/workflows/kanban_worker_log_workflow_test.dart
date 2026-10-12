import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/kanban/kanban_repository.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_task_log_dialog.dart';

import '../support/fake_hermes_server.dart';
import '../support/screenshot_recorder.dart';
import '../support/workflow_app.dart';

void main() {
  for (final (name, platform, size, brightness) in [
    ('ios', TargetPlatform.iOS, phoneSize, Brightness.light),
    ('ios-dark', TargetPlatform.iOS, phoneSize, Brightness.dark),
    ('mac', TargetPlatform.macOS, desktopSize, Brightness.light),
    ('mac-dark', TargetPlatform.macOS, desktopSize, Brightness.dark),
    ('material', TargetPlatform.android, phoneSize, Brightness.light),
  ]) {
    testWidgets('$name: worker log reads and closes', (tester) async {
      final shots = ScreenshotRecorder('worker-log-$name');
      final server = FakeHermesServer();
      const path = '/api/plugins/kanban/tasks/example/log';
      await pumpScreen(
        tester,
        shots,
        Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showAdaptiveDialog<void>(
                  context: context,
                  builder: (_) => KanbanTaskLogDialog(
                    repository: KanbanRepository(server.client()),
                    taskId: 'example',
                    board: 'ops',
                  ),
                ),
                child: const Text('Open worker log'),
              ),
            ),
          ),
        ),
        size: size,
        platform: platform,
        brightness: brightness,
      );
      for (final (state, body, status) in [
        (
          'long',
          {
            'exists': true,
            'truncated': true,
            'content': [
              for (var i = 1; i <= 60; i++)
                '[worker] step $i: processing example input',
            ].join('\n'),
          },
          200,
        ),
        ('empty', {'exists': true, 'content': ''}, 200),
        ('not-run', {'exists': false, 'content': ''}, 200),
        ('failed', {'detail': 'unavailable'}, 500),
      ]) {
        server.on('GET', path, body, status: status);
        await tester.tap(find.text('Open worker log'));
        await tester.pumpAndSettle();
        expect(server.requests.last.queryParameters['board'], 'ops');
        final expected = switch (state) {
          'long' => '… (earlier output cut)\n${body['content']}',
          'empty' => '(empty)',
          'not-run' => 'No worker has run this task yet.',
          _ => 'Could not load the log.',
        };
        expect(find.text(expected), findsOneWidget);
        await shots.capture(tester, state);
        await tester.tap(find.widgetWithText(TextButton, 'Close'));
        await tester.pumpAndSettle();
        expect(find.byType(KanbanTaskLogDialog), findsNothing);
      }
    });
  }
}
