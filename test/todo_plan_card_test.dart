import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/todo_plan/todo_plan_state.dart';
import 'package:hermes_app/src/chat/todo_plan/todo_plan_card.dart';

import 'support/accessibility.dart';

void main() {
  testWidgets(
    'plan disclosure shows read-only statuses and preserves unsupported siblings',
    (tester) async {
      final owner = TodoScope(
        connection: Object(),
        runtimeId: 'runtime',
        profile: 'work',
      );
      final state = TodoPlanState()..adopt(owner);
      addTearDown(state.dispose);
      state.updated(owner, {
        'revision': 1,
        'todos': [
          {
            'id': 'a',
            'content': '[Inspect](https://example.invalid)',
            'status': 'completed',
          },
          {'title': 'Unsupported'},
        ],
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TodoPlanCard(state: state)),
        ),
      );
      expect(find.text('[Inspect](https://example.invalid)'), findsNothing);
      await tester.tap(find.text('Plan · Some task details unavailable'));
      await tester.pumpAndSettle();
      expect(find.text('[Inspect](https://example.invalid)'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Task details unavailable'), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);
    },
  );

  testWidgets('missing and empty plans draw nothing', (tester) async {
    final owner = TodoScope(
      connection: Object(),
      runtimeId: 'runtime',
      profile: null,
    );
    final state = TodoPlanState()..adopt(owner);
    addTearDown(state.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TodoPlanCard(state: state)),
      ),
    );
    expect(find.byType(Text), findsNothing);
    state.updated(owner, {'revision': 1, 'todos': []});
    await tester.pumpAndSettle();
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('plan disclosure remains accessible on narrow screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    final owner = TodoScope(
      connection: Object(),
      runtimeId: 'runtime',
      profile: null,
    );
    final state = TodoPlanState()..adopt(owner);
    addTearDown(state.dispose);
    state.updated(owner, {
      'revision': 1,
      'todos': [
        {
          'id': 'a',
          'content': 'A long task remains readable when the available width is narrow.',
          'status': 'in_progress',
        },
      ],
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TodoPlanCard(state: state)),
      ),
    );
    await tester.tap(find.text('Plan · 0 of 1 completed'));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.text('Plan · 0 of 1 completed')),
      disclosure('Plan · 0 of 1 completed', open: true),
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
