import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/kanban/kanban_board_controller.dart';
import 'package:hermes_app/src/kanban/kanban_boards_screen.dart';
import 'package:hermes_app/src/kanban/kanban_repository.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_list_rows.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_orchestration_dialog.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_task_panel.dart';
import 'package:stream_channel/stream_channel.dart';

import '../../widgetbook/kanban_screen_use_cases.dart';
import '../support/screenshot_recorder.dart';
import '../support/workflow_app.dart';

void main() {
  for (final (label, size, platform, brightness) in [
    ('phone', phoneSize, TargetPlatform.iOS, Brightness.light),
    ('desktop', desktopSize, TargetPlatform.macOS, Brightness.light),
    ('phone-dark', phoneSize, TargetPlatform.iOS, Brightness.dark),
    ('desktop-dark', desktopSize, TargetPlatform.macOS, Brightness.dark),
  ]) {
    testWidgets('grouped Kanban forms $label', (tester) async {
      final shots = ScreenshotRecorder('kanban-forms-$label');
      final repository = KanbanRepository(kanbanServer().client());
      final controller = KanbanBoardController(
        repository: repository,
        connect: ({required since, board}) async =>
            StreamChannelController<String>().foreign,
      );
      addTearDown(controller.dispose);
      await tester.runAsync(controller.loadBoards);
      await pumpScreen(
        tester,
        shots,
        KanbanBoardsScreen(controller: controller, repository: repository),
        size: size,
        platform: platform,
        brightness: brightness,
      );
      tester
          .widget<KanbanBoardRow>(find.byType(KanbanBoardRow).last)
          .onExport();
      await tester.pumpAndSettle();
      await shots.capture(tester, 'export');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Import a board'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'import');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await pumpScreen(
        tester,
        shots,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) =>
                    KanbanOrchestrationDialog(repository: repository),
              ),
              child: const Text('Orchestration'),
            ),
          ),
        ),
        size: size,
        platform: platform,
        brightness: brightness,
      );
      await tester.tap(find.text('Orchestration'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'orchestration');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await pumpScreen(
        tester,
        shots,
        Scaffold(
          body: KanbanTaskPanel(
            repository: repository,
            taskId: 't_run',
            board: 'ops',
            onChanged: () {},
          ),
        ),
        size: size,
        platform: platform,
        brightness: brightness,
      );
      await tester.tap(find.byTooltip('Edit'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'edit-task');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
}
