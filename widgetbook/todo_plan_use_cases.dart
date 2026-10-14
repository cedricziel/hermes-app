import 'package:hermes_app/src/chat/todo_plan/todo_plan_card.dart';
import 'package:hermes_app/src/chat/todo_plan/todo_plan_state.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

TodoPlanState _plan(List<Object?>? entries) {
  final scope = TodoScope(
    connection: Object(),
    runtimeId: 'fixture',
    profile: null,
  );
  final state = TodoPlanState()..adopt(scope);
  if (entries != null) state.updated(scope, {'revision': 1, 'todos': entries});
  return state;
}

const _tasks = [
  {'id': 'a', 'content': 'Review the change', 'status': 'completed'},
  {'id': 'b', 'content': 'Implement the change', 'status': 'in_progress'},
  {'id': 'c', 'content': 'Verify the change', 'status': 'pending'},
];

WidgetbookNode todoPlanNode() => WidgetbookComponent(
  name: 'Agent plan',
  useCases: [
    WidgetbookUseCase(
      name: 'Compact plan',
      builder: (_) => frame(TodoPlanCard(state: _plan(_tasks))),
    ),
    WidgetbookUseCase(
      name: 'Expanded plan',
      builder: (_) =>
          frame(TodoPlanCard(state: _plan(_tasks), initiallyOpen: true)),
    ),
    WidgetbookUseCase(
      name: 'Empty plan',
      builder: (_) =>
          frame(TodoPlanCard(state: _plan(const []), initiallyOpen: true)),
    ),
    WidgetbookUseCase(
      name: 'Plan not reported (draws nothing)',
      builder: (_) =>
          frame(TodoPlanCard(state: _plan(null), initiallyOpen: true)),
    ),
    WidgetbookUseCase(
      name: 'Unsupported sibling',
      builder: (_) => frame(
        TodoPlanCard(
          state: _plan([
            _tasks.first,
            {'title': 'Unknown item shape'},
          ]),
          initiallyOpen: true,
        ),
      ),
    ),
    WidgetbookUseCase(
      name: 'Long task',
      builder: (_) => frame(
        TodoPlanCard(
          state: _plan([
            {
              'id': 'a',
              'content': 'Read the reported task details without changing the server plan. This longer entry demonstrates wrapping on narrow conversation windows.',
              'status': 'in_progress',
            },
          ]),
          initiallyOpen: true,
        ),
      ),
    ),
  ],
);
