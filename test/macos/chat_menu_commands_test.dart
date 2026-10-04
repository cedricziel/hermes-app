import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/macos/mac_commands.dart';

import '../support/fake_hermes_server.dart';
import '../support/pump_chat.dart';

/// The chat screen's menu bar commands, carried out through the registry as
/// the Mac menu bar does.
void main() {
  late FakeHermesServer server;
  late MacCommandRegistry commands;

  setUp(() {
    commands = MacCommandRegistry();
    server = FakeHermesServer();
    server.on(
      'GET',
      '/api/sessions',
      sessionListBody([
        sessionRow(id: 's1', title: 'Run failure', lastActive: 1780000600),
        sessionRow(id: 's2', title: 'Release notes', lastActive: 1780000100),
      ]),
    );
    for (final id in ['s1', 's2']) {
      server.on(
        'GET',
        '/api/sessions/$id/messages',
        messageListBody(id, [messageRow(id: 1, role: 'user', content: 'hi')]),
      );
    }
  });

  Future<void> pump(WidgetTester tester) =>
      pumpChatScreen(tester, server: server, commands: commands);

  Future<void> run(WidgetTester tester, MacCommand command) async {
    expect(commands.invoke(command), isTrue, reason: '$command is offered');
    await tester.pumpAndSettle();
  }

  bool enabled(MacCommand command) =>
      commands.handlerFor(command)?.enabled ?? false;

  testWidgets('thread commands wait for a selected thread', (tester) async {
    await pump(tester);
    expect(enabled(MacCommand.newChat), isTrue);
    expect(enabled(MacCommand.find), isTrue);
    for (final command in [
      MacCommand.pinThread,
      MacCommand.renameThread,
      MacCommand.copyTranscript,
      MacCommand.archiveThread,
      MacCommand.deleteThread,
    ]) {
      expect(enabled(command), isFalse, reason: '$command');
    }

    await openThread(tester, 'Release notes');
    expect(enabled(MacCommand.pinThread), isTrue);
    expect(enabled(MacCommand.deleteThread), isTrue);
    expect(enabled(MacCommand.copyTranscript), isTrue);
    expect(commands.handlerFor(MacCommand.pinThread)!.title, 'Pin');
  });

  testWidgets('Pin pins the selected thread and becomes Unpin', (tester) async {
    server.on(
      'PATCH',
      '/api/sessions/s2',
      sessionPatchBody(flags: {'pinned': true}),
    );
    await pump(tester);
    await openThread(tester, 'Release notes');

    await run(tester, MacCommand.pinThread);

    expect(jsonBody(server.requestsTo('PATCH', '/api/sessions/s2').single), {
      'pinned': true,
    });
    expect(commands.handlerFor(MacCommand.pinThread)!.title, 'Unpin');
  });

  testWidgets('Delete… asks first, then deletes the selected thread', (
    tester,
  ) async {
    server.on('DELETE', '/api/sessions/s2', {'ok': true});
    await pump(tester);
    await openThread(tester, 'Release notes');

    await run(tester, MacCommand.deleteThread);
    expect(find.text('Delete this chat?'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Delete'),
      ),
    );
    await tester.pumpAndSettle();

    expect(server.requestsTo('DELETE', '/api/sessions/s2'), hasLength(1));
  });

  testWidgets('New Chat leaves the selected thread', (tester) async {
    await pump(tester);
    await openThread(tester, 'Release notes');
    await run(tester, MacCommand.newChat);
    expect(enabled(MacCommand.pinThread), isFalse);
  });
}
