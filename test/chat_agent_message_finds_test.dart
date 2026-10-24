import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/agent_messages/agent_message_watcher.dart';
import 'package:hermes_app/src/chat/widgets/thread_sidebar.dart';
import 'package:provider/provider.dart';

import 'support/fake_hermes_server.dart';
import 'support/pump_chat.dart';

/// A message from Hermes found for the shown profile puts its chat in the
/// list without a refresh, and leaves the open chat as it was.
void main() {
  late FakeHermesServer server;
  late AgentMessageFinds finds;

  void list(List<Map<String, Object?>> rows) => server.on(
    'GET',
    '/api/sessions',
    sessionListBody(rows),
    query: {'profile': 'work'},
  );

  setUp(() {
    finds = AgentMessageFinds();
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/profiles',
        profileListBody([
          profileRow(name: 'work', isDefault: true),
          profileRow(name: 'home'),
        ]),
      )
      ..on('GET', '/api/profiles/active', activeProfileBody(active: 'work'))
      ..on(
        'GET',
        '/api/sessions/recent/messages',
        messageListBody('recent', [
          messageRow(id: 1, role: 'assistant', content: 'the recent chat'),
        ]),
      );
    list([sessionRow(id: 'recent', title: 'Recent chat')]);
  });

  tearDown(() => finds.dispose());

  Future<void> pump(WidgetTester tester) => pumpChatScreen(
    tester,
    server: server,
    withProfiles: true,
    providers: [ChangeNotifierProvider.value(value: finds)],
  );

  Finder inSidebar(String title) => find.descendant(
    of: find.byType(ThreadSidebar),
    matching: find.text(title),
  );

  int lists() => server.requestsTo('GET', '/api/sessions').length;

  testWidgets(
    'a find in the shown profile adds the chat and keeps the open one',
    (tester) async {
      await pump(tester);
      await openThread(tester, 'Recent chat');
      list([
        sessionRow(
          id: 'hermes-app-1',
          title: 'Message: Report',
          source: 'hermes_app',
          unread: true,
        ),
        sessionRow(id: 'recent', title: 'Recent chat'),
      ]);

      finds.report({'work'});
      await tester.pumpAndSettle();

      expect(inSidebar('Message: Report'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(Chat),
          matching: find.textContaining('the recent chat', findRichText: true),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('a find in another profile reads nothing', (tester) async {
    await pump(tester);
    final before = lists();

    finds.report({'home'});
    await tester.pumpAndSettle();

    expect(lists(), before);
  });
}
