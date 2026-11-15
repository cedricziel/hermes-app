import 'package:flutter/material.dart';

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_api_client.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';
import 'support/pump_chat.dart';

/// Pulling the chat list down reads its first page again (D7). The Mac has
/// View > Reload and no pull to refresh.
void main() {
  late FakeHermesServer server;

  List<({String? offset})> listReads() => [
    for (final r in server.requestsTo('GET', '/api/sessions'))
      (offset: r.queryParameters['offset']?.toString()),
  ];

  setUp(() {
    server = FakeHermesServer()
      ..on('GET', '/api/profiles/active', activeProfileBody(active: 'default'))
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          sessionRow(id: 's2', title: 'Release notes', lastActive: 1780000100),
        ]),
      )
      ..on(
        'GET',
        '/api/sessions/s2/messages',
        messageListBody('s2', [messageRow(id: 1, role: 'user', content: 'hi')]),
      );
  });

  final row = find.byKey(const ValueKey('thread-s2'));
  const failedTitle = "Couldn't refresh your chats.";

  Future<void> pull(WidgetTester tester) async {
    await tester.drag(row, const Offset(0, 400));
    await tester.pumpAndSettle();
  }

  testWidgets('on iOS a pull reads the first page and shows the new chat', (
    tester,
  ) async {
    await pumpChatScreen(
      tester,
      server: server,
      withProfiles: true,
      platform: TargetPlatform.iOS,
    );
    expect(find.byType(RefreshIndicator), findsOneWidget);
    final before = listReads().length;
    expect(find.text('Fresh chat'), findsNothing);
    server.on(
      'GET',
      '/api/sessions',
      sessionListBody([
        sessionRow(id: 's3', title: 'Fresh chat', lastActive: 1780000200),
        sessionRow(id: 's2', title: 'Release notes', lastActive: 1780000100),
      ]),
    );

    await pull(tester);

    final reads = listReads();
    expect(reads.length - before, 1);
    expect(reads.last.offset, anyOf(isNull, '0'));
    expect(find.text('Fresh chat'), findsOneWidget);
    expect(find.text(failedTitle), findsNothing);
  });

  testWidgets('a failed pull keeps the list and shows a notice', (
    tester,
  ) async {
    await pumpChatScreen(
      tester,
      server: server,
      withProfiles: true,
      platform: TargetPlatform.iOS,
    );
    server.on('GET', '/api/sessions', {'detail': 'boom'}, status: 500);

    await pull(tester);

    expect(find.text(failedTitle), findsOneWidget);
    expect(find.text('Pull down to try again.'), findsOneWidget);
    expect(find.text('Release notes'), findsOneWidget);

    server.on(
      'GET',
      '/api/sessions',
      sessionListBody([
        sessionRow(id: 's2', title: 'Release notes', lastActive: 1780000100),
      ]),
    );
    await pull(tester);

    expect(find.text(failedTitle), findsNothing);
  });

  testWidgets('on macOS the list has no refresh indicator', (tester) async {
    await pumpChatScreen(
      tester,
      server: server,
      withProfiles: true,
      platform: TargetPlatform.macOS,
    );

    expect(find.byType(RefreshIndicator), findsNothing);
  });

  group('the controller while the list cannot take a read', () {
    late ChatController chat;
    late Completer<void> hold;

    setUp(() async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final attention = AttentionNotifier(
        service: null,
        settings: null,
        onOpen: (_) {},
      );
      chat = ChatController(
        repository: HermesChatRepository(HermesApiClient(server.dio()).raw),
        transport: FakeChatTransport(),
        attention: attention,
        report: (_) {},
      );
      addTearDown(() {
        chat.dispose();
        attention.dispose();
      });
      await chat.loadThreads('default');
      hold = Completer<void>();
      server.onRequest('GET', '/api/sessions', (_) async {
        await hold.future;
        return (
          status: 200,
          body: sessionListBody([
            sessionRow(id: 's3', title: 'Fresh chat', lastActive: 1780000200),
          ]),
        );
      });
    });

    test('waits for the list to settle, then reads and merges', () async {
      unawaited(chat.loadThreads('default'));
      await pumpEventQueue();
      expect(chat.threadListInvalidationBlocked, isTrue);

      var done = false;
      final result = chat.pullRefreshThreadList().whenComplete(
        () => done = true,
      );
      await pumpEventQueue();
      expect(done, isFalse);

      hold.complete();

      expect(await result, ThreadListRefreshResult.refreshed);
      expect(chat.threads.map((t) => t.id), contains('s3'));
      expect(chat.threadListRefreshFailed, isFalse);
    });

    test('ends as a failure when the list never settles', () async {
      chat.threadListRefreshTimeout = const Duration(milliseconds: 50);
      unawaited(chat.loadThreads('default'));
      await pumpEventQueue();

      expect(
        await chat.pullRefreshThreadList(),
        ThreadListRefreshResult.failed,
      );
      expect(chat.threadListRefreshFailed, isTrue);
      hold.complete();
    });
  });
}
