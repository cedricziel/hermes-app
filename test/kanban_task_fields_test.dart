import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/kanban/kanban_models.dart';
import 'package:hermes_app/src/kanban/widgets/task_panel/kanban_task_fields.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

void main() {
  testWidgets('the model row fits a narrow screen at large text sizes', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(280, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesLightTheme(),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.5)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: KanbanTaskFields(
                detail: const KanbanTaskDetail(
                  task: KanbanTask(
                    id: 't1',
                    title: 'Task',
                    status: 'todo',
                    modelOverride: 'anthropic/claude-opus-4',
                    reasoningEffort: 'xhigh',
                  ),
                ),
                onAddParent: () {},
                onRemoveParent: (_) {},
                onEditModel: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('kanban-task-model')), findsOneWidget);
  });
}
