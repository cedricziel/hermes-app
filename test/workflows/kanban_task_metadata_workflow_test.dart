import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/kanban/kanban_repository.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_task_panel.dart';

import '../support/fake_hermes_server.dart';
import '../support/kanban_fixtures.dart';
import '../support/screenshot_recorder.dart';
import '../support/workflow_app.dart';

void main() {
  const diagnosticTitle =
      'Configuration requires an example destination, an approved migration guide and a verified connection before processing can begin';
  const childTitle =
      'Write the migration guide with every environment and destination the example release needs to cover';
  for (final (name, platform, size, brightness) in [
    ('ios', TargetPlatform.iOS, phoneSize, Brightness.light),
    ('ios-dark', TargetPlatform.iOS, phoneSize, Brightness.dark),
    ('mac', TargetPlatform.macOS, desktopSize, Brightness.light),
    ('mac-dark', TargetPlatform.macOS, desktopSize, Brightness.dark),
  ]) {
    testWidgets('$name: task metadata and notification recovery', (
      tester,
    ) async {
      final shots = ScreenshotRecorder('task-metadata-$name');
      final detail =
          kanbanTaskDetailBody(
              kanbanTaskRow(
                  id: 'example',
                  title: 'Prepare the example release',
                  status: 'todo',
                )
                ..['body'] =
                    'Check the configuration and prepare a migration guide.'
                ..['result'] = 'Draft guide prepared.'
                ..['model_override'] = 'example/model-with-a-long-name'
                ..['reasoning_effort'] = 'high',
              parents: ['parent-example'],
            )
            ..['child_results'] = [
              {
                'id': 'child-example',
                'title': childTitle,
                'status': 'done',
                'summary': 'Guide prepared and checked.',
              },
            ];
      (detail['task'] as Map<String, Object?>)['diagnostics'] = [
        {
          'title': diagnosticTitle,
          'severity': 'warning',
          'detail':
              'The example environment needs a destination before processing.',
        },
      ];
      final server = FakeHermesServer()
        ..on('GET', '/api/plugins/kanban/tasks/example', detail)
        ..on('GET', '/api/plugins/kanban/home-channels', {
          'home_channels': [
            {
              'platform': 'telegram',
              'name': 'Example team',
              'subscribed': false,
            },
          ],
        })
        ..on('GET', '/api/plugins/kanban/assignees', {'assignees': []})
        ..on('DELETE', '/api/plugins/kanban/links', {'ok': true})
        ..on(
          'POST',
          '/api/plugins/kanban/tasks/example/home-subscribe/telegram',
          {'detail': 'Example destination unavailable'},
          status: 500,
        );
      await pumpScreen(
        tester,
        shots,
        Scaffold(
          body: Center(
            child: SizedBox(
              width: 560,
              child: KanbanTaskPanel(
                repository: KanbanRepository(server.client()),
                taskId: 'example',
                board: 'ops',
              ),
            ),
          ),
        ),
        size: size,
        platform: platform,
        brightness: brightness,
      );
      expect(find.text(diagnosticTitle), findsOneWidget);
      expect(
        tester
            .renderObject<RenderParagraph>(find.text(diagnosticTitle))
            .didExceedMaxLines,
        isFalse,
      );
      await shots.capture(tester, 'metadata');
      await tester.ensureVisible(
        find.byTooltip('Remove dependency parent-example'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Remove dependency parent-example'));
      await tester.pumpAndSettle();
      expect(
        server
            .requestsTo('DELETE', '/api/plugins/kanban/links')
            .single
            .queryParameters,
        {'parent_id': 'parent-example', 'child_id': 'example', 'board': 'ops'},
      );
      await tester.ensureVisible(find.text(childTitle));
      await tester.pumpAndSettle();
      expect(
        tester
            .renderObject<RenderParagraph>(find.text(childTitle))
            .didExceedMaxLines,
        isFalse,
      );
      await shots.capture(tester, 'dependencies');
      await tester.ensureVisible(find.text('Post updates to Example team'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      expect(find.text('Example destination unavailable'), findsOneWidget);
      await shots.capture(tester, 'notification-recovery');
    });
  }
}
