import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/skills/skill_editor_screen.dart';

void main() {
  testWidgets('a save completing during dismissal keeps the skills list', (
    tester,
  ) async {
    final saved = Completer<String?>();
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: const Scaffold(body: Text('Chats')),
      ),
    );
    navigator.currentState!.push<void>(
      MaterialPageRoute(builder: (_) => const Scaffold(body: Text('Skills'))),
    );
    navigator.currentState!.push<String>(
      MaterialPageRoute(
        builder: (_) => SkillEditorScreen.edit(
          name: 'example',
          initialText: 'Original skill',
          onSave: (_, _, _) => saved.future,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Updated skill');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    navigator.currentState!.pop();
    saved.complete(null);
    await tester.pumpAndSettle();

    expect(find.text('Skills'), findsOneWidget);
    expect(find.text('Chats'), findsNothing);
  });
}
