import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/slash_command.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';
import 'support/pump_chat.dart';

void main() {
  testWidgets('a running slash command blocks normal sends on a new chat', (
    tester,
  ) async {
    final transport = FakeChatTransport();
    final gate = transport.slashGate = Completer<SlashCommandResult>();
    await pumpChatScreen(tester, transport: transport);
    await tester.tap(find.text('New chat').first);
    await tester.pump();

    await tester.enterText(composerField, '/help');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
    expect(transport.slashRuns, ['/help']);

    await tester.enterText(composerField, 'Normal prompt');
    await tester.pump();
    final send = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.arrow_upward),
        matching: find.byType(IconButton),
      ),
    );
    expect(send.onPressed, isNull);
    expect(transport.sends, isEmpty);

    gate.complete(const SlashCommandResult(threadId: 'command-session'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
    expect(transport.sends.single.threadId, 'command-session');
    expect(transport.sends.single.text, 'Normal prompt');
    transport.sends.single.emit(const ReplyCompleted('Done'));
    await tester.pumpAndSettle();
  });

  testWidgets('prefill restores the draft after a command', (tester) async {
    final transport = FakeChatTransport()
      ..slashResult = const SlashCommandResult(
        threadId: 'command-session',
        output: 'Undid one turn',
        prefill: 'Previous prompt',
      );
    await pumpChatScreen(tester, transport: transport);
    await tester.tap(find.text('New chat').first);
    await tester.pump();

    await tester.enterText(composerField, '/undo');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pumpAndSettle();

    expect(
      tester.widget<EditableText>(composerField).controller.text,
      'Previous prompt',
    );
    expect(transport.sends, isEmpty);
  });

  testWidgets('undo refreshes a remote transcript before restoring its draft', (
    tester,
  ) async {
    var reads = 0;
    final server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 's1', title: 'Existing chat')]),
      )
      ..onRequest('GET', '/api/sessions/s1/messages', (_) {
        reads++;
        return (
          status: 200,
          body: messageListBody('s1', [
            messageRow(
              id: reads == 1 ? 1 : 3,
              role: 'user',
              content: reads == 1 ? 'Undone turn' : 'Earlier turn',
            ),
          ]),
        );
      });
    final transport = FakeChatTransport()
      ..slashResult = const SlashCommandResult(
        threadId: 's1',
        output: 'Undid one turn',
        prefill: 'Undone turn',
      );
    await pumpChatScreen(tester, server: server, transport: transport);
    await tester.tap(find.byKey(const ValueKey('thread-s1')));
    await tester.pumpAndSettle();
    expect(find.text('Undone turn'), findsOneWidget);

    await tester.enterText(composerField, '/undo');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pumpAndSettle();

    expect(reads, 2);
    expect(find.text('Earlier turn'), findsOneWidget);
    expect(
      tester.widget<EditableText>(composerField).controller.text,
      'Undone turn',
    );
    expect(transport.sends, isEmpty);
  });

  testWidgets('suggestions clear when the chat context changes', (
    tester,
  ) async {
    final transport = FakeChatTransport()
      ..availableSlashCommands = const [SlashCommand('/old', 'Old command')];
    await pumpChatScreen(tester, transport: transport);
    await tester.enterText(composerField, '/');
    await tester.pumpAndSettle();
    expect(find.text('/old'), findsOneWidget);

    final next = Completer<List<SlashCommand>>();
    transport.catalogGates.add(next);
    await tester.tap(find.text('New chat').first);
    await tester.pump();
    expect(find.text('/old'), findsNothing);

    next.complete(const [SlashCommand('/newer', 'New command')]);
    await tester.pumpAndSettle();
    expect(find.text('/newer'), findsOneWidget);
  });
}
