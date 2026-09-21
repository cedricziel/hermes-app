import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/skills/skill_detail_screen.dart';
import 'package:hermes_app/src/skills/skills_screen.dart';

import 'support/fake_hermes_server.dart';
import 'support/pump_chat.dart';

/// The Skills entry in the chat sidebar and the message it drafts.
void main() {
  late FakeHermesServer server;

  setUp(() {
    server = FakeHermesServer()
      ..on('GET', '/api/sessions', sessionListBody([]))
      ..on('GET', '/api/skills', [
        skillRow(name: 'pr-review', category: 'github', provenance: 'agent'),
      ])
      ..on('GET', '/api/skills/content', {
        'name': 'pr-review',
        'content': '# Review',
        'path': '/x',
      });
  });

  String composerText(WidgetTester tester) =>
      tester.widget<EditableText>(find.byType(EditableText)).controller.text;

  testWidgets('the sidebar opens the skills of the connected dashboard', (
    tester,
  ) async {
    await pumpChatScreen(tester, server: server, withSkills: true);

    await openSidebarMore(tester);

    await tester.tap(find.text('Skills'));
    await tester.pumpAndSettle();

    expect(find.byType(SkillsScreen), findsOneWidget);
    expect(find.text('pr-review'), findsOneWidget);
  });

  testWidgets('there is no Skills entry without a connection', (tester) async {
    await pumpChatScreen(tester);

    expect(find.text('Skills'), findsNothing);
  });

  testWidgets('asking the agent to delete drafts a message and sends nothing', (
    tester,
  ) async {
    await pumpChatScreen(tester, server: server, withSkills: true);
    await tester.enterText(find.byType(EditableText), 'half a thought');

    await openSidebarMore(tester);

    await tester.tap(find.text('Skills'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('pr-review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ask agent to delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Draft message'));
    await tester.pumpAndSettle();

    expect(find.byType(SkillsScreen), findsNothing);
    expect(
      composerText(tester),
      'half a thought\n${deleteRequestFor('pr-review')}',
    );
    expect(server.requests.where((r) => r.method != 'GET'), isEmpty);
  });
}
