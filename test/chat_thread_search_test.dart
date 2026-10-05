import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/thread_search.dart';
import 'package:hermes_app/src/chat/thread_list_preferences.dart';
import 'package:hermes_app/src/chat/widgets/thread_search_view.dart';
import 'package:hermes_app/src/chat/widgets/thread_sidebar.dart';

import 'support/accessibility.dart';
import 'support/fake_hermes_server.dart';
import 'support/pump_chat.dart';

void main() {
  late FakeHermesServer server;

  setUp(() {
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 'recent', title: 'Recent chat')]),
      )
      ..on('GET', '/api/sessions/search', {
        'results': [
          {
            'session_id': 'old',
            'id': 'old',
            'title': 'Nightly backup',
            'snippet': 'set up a >>>backup<<< of the notes',
            'session_started': 1780000000,
          },
        ],
      })
      ..on(
        'GET',
        '/api/sessions/old',
        sessionRow(id: 'old', title: 'Nightly backup'),
      )
      ..on(
        'GET',
        '/api/sessions/old/messages',
        messageListBody('old', [
          messageRow(id: 1, role: 'assistant', content: 'the old transcript'),
        ]),
      );
  });

  Finder inSidebar(Finder finder) =>
      find.descendant(of: find.byType(ThreadSidebar), matching: finder);

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const Key('thread-search-field')), text);
    await tester.pump(ThreadSearch.defaultDebounce);
    await tester.pumpAndSettle();
  }

  testWidgets('results replace the thread list while the field holds text', (
    tester,
  ) async {
    await pumpChatScreen(tester, server: server);

    await type(tester, 'backup');

    final request = server.requestsTo('GET', '/api/sessions/search').single;
    expect(request.queryParameters['q'], 'backup');
    expect(find.byType(ThreadSearchResults), findsOneWidget);
    expect(inSidebar(find.text('Nightly backup')), findsOneWidget);
    expect(inSidebar(find.text('Recent chat')), findsNothing);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();

    expect(inSidebar(find.text('Recent chat')), findsOneWidget);
    expect(find.byType(ThreadSearchResults), findsNothing);
  });

  testWidgets(
    'search replaces folder sections and clearing restores grouping',
    (tester) async {
      await pumpChatScreen(tester, server: server);
      await tester.tap(find.byTooltip('Group chats'));
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .ancestor(
              of: find.text('Folder'),
              matching: find.byType(CheckedPopupMenuItem<ThreadGrouping>),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(inSidebar(find.text('No folder')), findsOneWidget);
      await type(tester, 'backup');
      expect(find.byType(ThreadSearchResults), findsOneWidget);
      expect(inSidebar(find.text('No folder')), findsNothing);
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(inSidebar(find.text('No folder')), findsOneWidget);
      expect(inSidebar(find.text('Recent chat')), findsOneWidget);
    },
  );

  testWidgets('a result older than the loaded pages opens', (tester) async {
    await pumpChatScreen(tester, server: server);
    await type(tester, 'backup');

    await tester.tap(inSidebar(find.text('Nightly backup')));
    await tester.pumpAndSettle();

    expect(server.requestsTo('GET', '/api/sessions/old'), hasLength(1));
    expect(find.text('the old transcript'), findsOneWidget);
  });

  testWidgets('a failed search says so', (tester) async {
    server.on('GET', '/api/sessions/search', {
      'detail': 'Search failed',
    }, status: 500);
    await pumpChatScreen(tester, server: server);

    await type(tester, 'backup');

    expect(find.textContaining('Search failed'), findsOneWidget);
  });

  testWidgets('no match says so', (tester) async {
    server.on('GET', '/api/sessions/search', {'results': []});
    await pumpChatScreen(tester, server: server);

    await type(tester, 'zebra');

    expect(find.text('No chats match "zebra".'), findsOneWidget);
  });

  testWidgets('screen readers get Clear search by name', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpChatScreen(tester, server: server);
    await type(tester, 'backup');

    expect(
      tester.getSemantics(inSidebar(find.byIcon(Icons.close))),
      namedButton('Clear search'),
    );
    handle.dispose();
  });
}
