import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/kanban/kanban_models.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_card.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

void main() {
  Future<void> pumpCard(WidgetTester tester, KanbanTask task) =>
      tester.pumpWidget(
        MaterialApp(
          theme: buildHermesLightTheme(),
          home: Scaffold(body: KanbanCard(task: task)),
        ),
      );

  /// A count shown next to the icon that says what it counts.
  Finder meta(IconData icon, String label) => find.ancestor(
    of: find.byIcon(icon),
    matching: find.widgetWithText(Row, label),
  );

  testWidgets('shows the tenant, comments and warnings of a task', (
    tester,
  ) async {
    await pumpCard(
      tester,
      const KanbanTask(
        id: 't1',
        title: 'Rotate keys',
        status: 'todo',
        tenant: 'acme',
        commentCount: 4,
        warningCount: 2,
      ),
    );

    expect(find.text('acme'), findsOneWidget);
    expect(meta(Icons.chat_bubble_outline, '4'), findsOneWidget);
    expect(meta(Icons.warning_amber_rounded, '2'), findsOneWidget);
  });

  testWidgets('leaves out the facts a task does not have', (tester) async {
    await pumpCard(
      tester,
      const KanbanTask(id: 't1', title: 'Rotate keys', status: 'todo'),
    );

    expect(find.byIcon(Icons.chat_bubble_outline), findsNothing);
    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    expect(find.byIcon(Icons.person_outline), findsNothing);
    expect(find.textContaining(RegExp(r'^P\d')), findsNothing);
  });
}
