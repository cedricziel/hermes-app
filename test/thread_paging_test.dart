import 'package:dio/dio.dart' show RequestOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/chat/widgets/thread_sidebar.dart';

import 'support/fake_hermes_server.dart';
import 'support/pump_chat.dart';

/// The sidebar loading the session list a page at a time. The dashboard adds
/// every pinned session it did not reach to each page, so the fake does too.
void main() {
  late FakeHermesServer server;

  Map<String, Object?> page(int offset, int count) => sessionListBody(
    [
      for (var i = offset; i < offset + count; i++)
        sessionRow(id: 'r$i', title: 'Chat $i', lastActive: 1780000000.0 - i),
      sessionRow(id: 'pin', title: 'Pinned chat', pinned: true),
    ],
    total: 60,
    offset: offset,
  );

  setUp(() {
    server = FakeHermesServer()
      ..onRequest('GET', '/api/sessions', (request) {
        final offset = request.queryParameters['offset'] as int;
        return (status: 200, body: offset == 0 ? page(0, 50) : page(50, 9));
      })
      ..on(
        'GET',
        '/api/sessions/pin/messages',
        messageListBody('pin', [
          messageRow(id: 1, role: 'user', content: 'hi'),
        ]),
      );
  });

  final list = find.descendant(
    of: find.byType(ThreadSidebar),
    matching: find.byType(ListView),
  );

  int itemCount(WidgetTester tester) =>
      (tester.widget<ListView>(list).childrenDelegate
              as SliverChildBuilderDelegate)
          .estimatedChildCount!;

  Future<void> scrollToEnd(WidgetTester tester) async {
    await tester.fling(list, const Offset(0, -6000), 6000);
    await tester.pumpAndSettle();
  }

  Iterable<RequestOptions> sessionListRequests() =>
      server.requestsTo('GET', '/api/sessions');

  testWidgets('loads only the first page until the end is reached', (
    tester,
  ) async {
    await pumpChatScreen(tester, server: server);

    expect(sessionListRequests(), hasLength(1));
    expect(find.text('Chat 49'), findsNothing);
    expect(itemCount(tester), 52);
  });

  testWidgets('scrolling to the end appends the next page once', (
    tester,
  ) async {
    await pumpChatScreen(tester, server: server);

    await scrollToEnd(tester);

    expect(sessionListRequests().map((r) => r.queryParameters['offset']), [
      0,
      50,
    ]);
    expect(itemCount(tester), 60);
    expect(find.text('Chat 58'), findsOneWidget);
    expect(find.byKey(const ValueKey('thread-pin')), findsNothing);
  });

  testWidgets('keeps the pinned thread on top without repeating it', (
    tester,
  ) async {
    await pumpChatScreen(tester, server: server);
    await scrollToEnd(tester);

    await tester.fling(list, const Offset(0, 9000), 9000);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('thread-pin')), findsOneWidget);
    expect(find.byIcon(Icons.push_pin), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('thread-pin'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const ValueKey('thread-r0'))).dy),
    );
  });

  testWidgets('stops asking once every session is loaded', (tester) async {
    await pumpChatScreen(tester, server: server);
    await scrollToEnd(tester);

    await scrollToEnd(tester);

    expect(sessionListRequests(), hasLength(2));
    expect(find.text('Show more'), findsNothing);
  });

  testWidgets('does not fetch the first page or its messages again', (
    tester,
  ) async {
    await pumpChatScreen(tester, server: server);

    await scrollToEnd(tester);

    expect(
      server.requestsTo('GET', '/api/sessions/pin/messages'),
      hasLength(1),
    );
  });

  testWidgets('an archived thread does not make the next page skip one', (
    tester,
  ) async {
    server.on(
      'PATCH',
      '/api/sessions/r0',
      sessionPatchBody(flags: {'archived': true}),
    );
    await pumpChatScreen(tester, server: server);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('thread-r0')),
        matching: find.byTooltip('Chat actions'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();

    await scrollToEnd(tester);

    expect(sessionListRequests().last.queryParameters['offset'], 49);
  });

  testWidgets('later pages come from the profile of the first', (tester) async {
    server.on('GET', '/api/profiles/active', activeProfileBody(active: 'work'));
    await pumpChatScreen(tester, server: server, withProfiles: true);

    await scrollToEnd(tester);

    expect(sessionListRequests().map((r) => r.queryParameters['profile']), [
      'work',
      'work',
    ]);
  });

  testWidgets('a failed page says so and can be retried', (tester) async {
    server.onRequest('GET', '/api/sessions', (request) {
      final offset = request.queryParameters['offset'] as int;
      return offset == 0
          ? (status: 200, body: page(0, 50))
          : (status: 503, body: {'detail': 'busy'});
    });
    await pumpChatScreen(tester, server: server);

    await scrollToEnd(tester);

    expect(find.text('Could not load more chats'), findsOneWidget);
    expect(itemCount(tester), 52);
    server.onRequest(
      'GET',
      '/api/sessions',
      (_) => (status: 200, body: page(50, 9)),
    );
    await tester.tap(find.text('Show more'));
    await tester.pumpAndSettle();
    await scrollToEnd(tester);

    expect(itemCount(tester), 60);
    expect(find.text('Chat 58'), findsOneWidget);
  });
}
