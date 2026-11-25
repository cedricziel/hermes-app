import 'package:flutter/foundation.dart' show TargetPlatform;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/widgets/chat_branch_notice.dart';
import 'package:hermes_app/src/macos/mac_commands.dart';

import '../support/fake_hermes_server.dart';
import '../support/accessibility_announcements.dart';
import '../support/pump_chat.dart';

String _descendant(String id) => '/api/sessions/$id/latest-descendant';

FakeHermesServer _server() {
  final server = FakeHermesServer()
    ..on(
      'GET',
      '/api/sessions',
      sessionListBody([
        sessionRow(id: 'b1', title: 'Try another way', lastActive: 1780000500)
          ..['_branched_from'] = 'p1',
        sessionRow(id: 'b2', title: 'Another branch', lastActive: 1780000400)
          ..['_branched_from'] = 'p2',
        sessionRow(id: 'p1', title: 'The original', lastActive: 1780000300),
        sessionRow(id: 'plain', title: 'A plain chat', lastActive: 1780000200),
      ]),
    )
    ..on('GET', _descendant('p1'), {
      'requested_session_id': 'p1',
      'session_id': 'p1',
      'path': ['p1'],
      'changed': false,
    });
  for (final id in ['b1', 'b2', 'p1', 'plain']) {
    server.on('GET', '/api/sessions/$id/messages', messageListBody(id, []));
  }
  return server;
}

void main() {
  group('on the chat screen', () {
    testWidgets('a branch shows the row, and a tap opens the original', (
      tester,
    ) async {
      final server = _server();
      await pumpChatScreen(tester, server: server);

      await openThread(tester, 'A plain chat');
      expect(find.byType(ChatBranchNotice), findsNothing);

      await openThread(tester, 'Try another way');
      expect(find.byType(ChatBranchNotice), findsOneWidget);
      expect(find.text('The original'), findsWidgets);
      expect(
        find.bySemanticsLabel(
          'Branched from The original. Opens the original chat.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.byType(ChatBranchNotice));
      await tester.pumpAndSettle();

      expect(server.requestsTo('GET', _descendant('p1')), hasLength(1));
      // The original is not a branch, so the row is gone with the selection.
      expect(find.byType(ChatBranchNotice), findsNothing);
    });

    testWidgets('Chat > Open Parent Chat opens it, and is off elsewhere', (
      tester,
    ) async {
      final server = _server();
      final commands = MacCommandRegistry();
      addTearDown(commands.dispose);
      await pumpChatScreen(
        tester,
        server: server,
        platform: TargetPlatform.macOS,
        commands: commands,
      );

      await openThread(tester, 'A plain chat');
      expect(commands.handlerFor(MacCommand.openParentChat)?.enabled, isFalse);

      await openThread(tester, 'Try another way');
      expect(commands.handlerFor(MacCommand.openParentChat)?.enabled, isTrue);

      commands.invoke(MacCommand.openParentChat);
      await tester.pumpAndSettle();

      expect(server.requestsTo('GET', _descendant('p1')), hasLength(1));
      expect(find.byType(ChatBranchNotice), findsNothing);
      expect(commands.handlerFor(MacCommand.openParentChat)?.enabled, isFalse);
    });

    testWidgets('a tap is announced as it opens and fails, and coming back to '
        'a failed one says nothing', (tester) async {
      final answer = Completer<FakeResponse>();
      final server = _server()
        ..onRequest('GET', _descendant('p1'), (_) => answer.future);
      final said = captureAnnouncements(tester);
      await pumpChatScreen(tester, server: server);
      await openThread(tester, 'Try another way');
      expect(said, isEmpty);

      await tester.tap(find.byType(ChatBranchNotice));
      await tester.pump();
      expect(said.map((a) => a.message), ['Opening the original chat…']);

      answer.complete((status: 404, body: {'detail': 'Session not found'}));
      await tester.pumpAndSettle();
      expect(said.map((a) => a.message), [
        'Opening the original chat…',
        'The original chat was deleted.',
      ]);

      // The same row widget serves the next branch, and then this one again.
      await openThread(tester, 'Another branch');
      await openThread(tester, 'Try another way');
      expect(said, hasLength(2));
    });

    testWidgets('the command is off once Hermes said the original is gone', (
      tester,
    ) async {
      final server = _server()
        ..on('GET', _descendant('p1'), {
          'detail': 'Session not found',
        }, status: 404);
      final commands = MacCommandRegistry();
      addTearDown(commands.dispose);
      await pumpChatScreen(
        tester,
        server: server,
        platform: TargetPlatform.macOS,
        commands: commands,
      );
      await openThread(tester, 'Try another way');

      commands.invoke(MacCommand.openParentChat);
      await tester.pumpAndSettle();

      expect(find.text('The original chat was deleted.'), findsOneWidget);
      expect(commands.handlerFor(MacCommand.openParentChat)?.enabled, isFalse);
      commands.invoke(MacCommand.openParentChat);
      await tester.pumpAndSettle();
      expect(server.requestsTo('GET', _descendant('p1')), hasLength(1));
    });
  });
}
