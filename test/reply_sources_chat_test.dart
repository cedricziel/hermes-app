import 'dart:convert';

import 'package:flutter_chat_ui/flutter_chat_ui.dart' show Chat;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_message_kinds.dart';
import 'package:material_ui/material_ui.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/widgets/message_actions.dart';
import 'package:hermes_app/src/chat/widgets/sources_row.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';
import 'support/pump_chat.dart';
import 'support/sources_fixtures.dart';

Map<String, Object?> _answer() => {
  'success': true,
  'data': {
    'web': [
      searchHit('https://news.example/a', title: 'Hit A'),
      searchHit('https://news.example/b', title: 'Hit B'),
    ],
  },
};

/// The row of sources under a reply, through the real chat screen: from a
/// stored chat, whose turn is several assistant rows, and from a live reply.
void main() {
  late FakeChatTransport transport;
  late FakeHermesServer server;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    transport = FakeChatTransport();
    server = FakeHermesServer()
      ..on('GET', '/api/profiles/active', activeProfileBody(active: 'work'))
      ..on('GET', '/api/profiles', profileListBody([profileRow(name: 'work')]))
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          sessionRow(id: 'stored', title: 'Synthetic'),
          sessionRow(id: 'plain', title: 'Plain'),
        ]),
      )
      ..on(
        'GET',
        '/api/sessions/plain/messages',
        messageListBody('plain', [
          messageRow(id: 1, role: 'user', content: 'Hello'),
          messageRow(id: 2, role: 'assistant', content: 'Hi'),
        ]),
      )
      ..on(
        'GET',
        '/api/sessions/stored/messages',
        messageListBody('stored', [
          messageRow(id: 1, role: 'user', content: 'What changed?'),
          messageRow(
            id: 2,
            role: 'assistant',
            content: '',
            toolCalls: [
              {
                'id': 'c1',
                'function': {
                  'name': 'web_search',
                  'arguments': jsonEncode({'query': 'changes'}),
                },
              },
            ],
          ),
          messageRow(
            id: 3,
            role: 'tool',
            toolCallId: 'c1',
            content: jsonEncode(_answer()),
          ),
          messageRow(id: 4, role: 'assistant', content: 'Here is the answer.'),
        ]),
      );
  });

  testWidgets(
    'a stored turn shows its sources under the reply, above its actions',
    (tester) async {
      await pumpChatScreen(
        tester,
        server: server,
        withProfiles: true,
        transport: transport,
        size: const Size(390, 844),
      );
      await openThread(tester, 'Synthetic');

      expect(find.text('Sources · 2'), findsOneWidget);
      expect(find.text('Hit A'), findsOneWidget);
      expect(find.text('Hit B'), findsOneWidget);
      final reply = tester.getBottomLeft(find.text('Here is the answer.')).dy;
      expect(tester.getTopLeft(find.byType(SourcesRow)).dy, greaterThan(reply));
      expect(
        tester.getTopLeft(find.byType(MessageActions)).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(find.byType(SourcesRow)).dy),
      );
    },
  );

  testWidgets('a stored turn keeps its sources when the session is reclaimed', (
    tester,
  ) async {
    await pumpChatScreen(
      tester,
      server: server,
      withProfiles: true,
      transport: transport,
      size: const Size(390, 844),
    );
    await openThread(tester, 'Synthetic');
    await tester.enterText(composerField, 'go');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
    final send = transport.sends.single;
    send
      ..emit(const ReplyStarted())
      ..emit(const SessionReclaimed('rt-1', 'stored', 'Opened elsewhere'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.text('Here is the answer.'), findsOneWidget);
    expect(find.text('Sources · 2'), findsOneWidget);
  });

  testWidgets(
    'a live reply shows them once it is finished, not while it streams',
    (tester) async {
      await pumpChatScreen(
        tester,
        server: server,
        withProfiles: true,
        transport: transport,
        size: const Size(390, 844),
      );
      await openThread(tester, 'Plain');
      await tester.enterText(composerField, 'go');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pump();
      final send = transport.sends.single;
      Future<void> emit(ChatEvent event) async {
        send.emit(event);
        await tester.pump(const Duration(milliseconds: 50));
      }

      await emit(const ReplyStarted());
      await emit(
        const ToolStarted(id: 't1', name: 'web_search', summary: 'changes'),
      );
      await emit(
        ToolFinished(id: 't1', name: 'web_search', resultData: _answer()),
      );
      await emit(const ReplyDelta('Streaming the answer'));

      expect(find.byType(SourcesRow), findsNothing);

      await emit(const ReplyCompleted('Streaming the answer.'));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Sources · 2'), findsOneWidget);
    },
  );

  testWidgets(
    'a turn that began on an older page gets its sources when that page loads',
    (tester) async {
      // One turn over 130 rows: the prompt and the search are older than the
      // newest page, the reply that ends the turn is on it.
      server
        ..on(
          'GET',
          '/api/sessions',
          sessionListBody([sessionRow(id: 'long', title: 'Long chat')]),
        )
        ..onRequest('GET', '/api/sessions/long/messages', (request) {
          const total = 130;
          final limit = request.queryParameters['limit'] as int;
          final offset = request.queryParameters['offset'] as int;
          final newest = total - offset;
          final oldest = newest - limit + 1 < 1 ? 1 : newest - limit + 1;
          Map<String, Object?> row(int id) => switch (id) {
            10 => messageRow(id: id, role: 'user', content: 'Research it'),
            11 => messageRow(
              id: id,
              role: 'assistant',
              content: '',
              toolCalls: [
                {
                  'id': 'c1',
                  'function': {
                    'name': 'web_search',
                    'arguments': jsonEncode({'query': 'it'}),
                  },
                },
              ],
            ),
            12 => messageRow(
              id: id,
              role: 'tool',
              toolCallId: 'c1',
              content: jsonEncode(_answer()),
            ),
            < 10 => messageRow(id: id, role: 'user', content: 'Earlier $id'),
            _ => messageRow(id: id, role: 'assistant', content: 'Step $id'),
          };
          return (
            status: 200,
            body: messageListBody('long', [
              for (var id = oldest; id <= newest; id++) row(id),
            ]),
          );
        });
      await pumpChatScreen(
        tester,
        server: server,
        withProfiles: true,
        transport: transport,
        size: const Size(390, 844),
      );
      await openThread(tester, 'Long chat');
      expect(find.byType(SourcesRow), findsNothing);

      for (var i = 0; i < 40; i++) {
        await tester.drag(find.byType(Chat), const Offset(0, 2000));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();

      // Back at the reply that ends the turn.
      for (var i = 0; i < 80; i++) {
        await tester.drag(find.byType(Chat), const Offset(0, -2000));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();
      expect(find.text('Step 130'), findsOneWidget);
      expect(find.text('Sources · 2'), findsOneWidget);
      // One row for the turn, not one under the older page's last text too.
      expect(
        tester
            .widget<Chat>(find.byType(Chat))
            .chatController
            .messages
            .where((m) => m.metadata?[kMetaSources] != null),
        hasLength(1),
      );
    },
  );
}
