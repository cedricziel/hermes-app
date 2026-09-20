import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_hermes_server.dart';
import 'support/pump_chat.dart';

/// A session longer than one page: the newest rows load first and scrolling to
/// the top reads the older ones.
void main() {
  late FakeHermesServer server;

  String line(int id) => 'line-${id.toString().padLeft(3, '0')}';

  setUp(() {
    server = FakeHermesServer();
    server.on(
      'GET',
      '/api/sessions',
      sessionListBody([sessionRow(id: 's1', title: 'Long chat')]),
    );
    server.onRequest('GET', '/api/sessions/s1/messages', (request) {
      const total = 130;
      final limit = request.queryParameters['limit'] as int;
      final offset = request.queryParameters['offset'] as int;
      final newest = total - offset;
      final oldest = newest - limit + 1 < 1 ? 1 : newest - limit + 1;
      return (
        status: 200,
        body: messageListBody('s1', [
          for (var id = oldest; id <= newest; id++)
            messageRow(id: id, role: 'user', content: line(id)),
        ]),
      );
    });
  });

  Finder inTranscript(String text) => find.descendant(
    of: find.byType(Chat),
    matching: find.textContaining(text, findRichText: true),
  );

  Future<void> scrollToTop(WidgetTester tester) async {
    for (var i = 0; i < 40; i++) {
      await tester.drag(find.byType(Chat), const Offset(0, 2000));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
  }

  testWidgets('opens on the newest rows without reading the whole session', (
    tester,
  ) async {
    await pumpChatScreen(tester, server: server);
    await openThread(tester, 'Long chat');

    expect(inTranscript(line(130)), findsOneWidget);
    final requests = server.requestsTo('GET', '/api/sessions/s1/messages');
    expect(requests, hasLength(1));
    expect(requests.single.queryParameters['offset'], 0);
  });

  testWidgets('reads older rows when the top is reached', (tester) async {
    await pumpChatScreen(tester, server: server);
    await openThread(tester, 'Long chat');

    await scrollToTop(tester);

    final requests = server.requestsTo('GET', '/api/sessions/s1/messages');
    expect(requests, hasLength(2));
    expect(requests.last.queryParameters['offset'], lessThan(100));
    expect(inTranscript(line(1)), findsOneWidget);
  });

  testWidgets('holds a message once though two pages both read it', (
    tester,
  ) async {
    await pumpChatScreen(tester, server: server);
    await openThread(tester, 'Long chat');

    await scrollToTop(tester);

    final held = tester.widget<Chat>(find.byType(Chat)).chatController.messages;
    expect(held.map((m) => m.id).toSet(), hasLength(130));
    expect(held, hasLength(130));
  });

  testWidgets('stops asking once the oldest row is in', (tester) async {
    await pumpChatScreen(tester, server: server);
    await openThread(tester, 'Long chat');

    await scrollToTop(tester);
    await scrollToTop(tester);

    expect(server.requestsTo('GET', '/api/sessions/s1/messages'), hasLength(2));
  });
}
