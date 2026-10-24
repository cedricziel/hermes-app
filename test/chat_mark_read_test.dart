import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:hermes_app/src/notifications/notification_service.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeHermesServer server;
  late ChatController chat;
  late List<(String, Map<String, Object>)> logged;
  late List<String> reports;

  List<Map<String, Object?>> markReads(String id) => [
    for (final request in server.requestsTo('PATCH', '/api/sessions/$id'))
      jsonBody(request) as Map<String, Object?>,
  ];

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          sessionRow(id: 'unread', title: 'Report', unread: true),
          sessionRow(id: 'read', title: 'Old', unread: false),
        ]),
      )
      ..on(
        'PATCH',
        '/api/sessions/unread',
        sessionPatchBody(flags: {'unread': false}),
      );
    for (final id in ['unread', 'read', 'older']) {
      server.on(
        'GET',
        '/api/sessions/$id/messages',
        messageListBody(id, [
          messageRow(id: 1, role: 'assistant', content: 'Hi'),
        ]),
      );
    }
    logged = [];
    reports = [];
    final attention = AttentionNotifier(
      service: null,
      settings: null,
      onOpen: (_) {},
    );
    chat = ChatController(
      repository: HermesChatRepository(server.client().raw),
      transport: FakeChatTransport(),
      attention: attention,
      report: reports.add,
      events: (name, [attributes = const {}]) => logged.add((name, attributes)),
    );
    addTearDown(() {
      chat.dispose();
      attention.dispose();
    });
  });

  test('opening an unread chat marks it read once', () async {
    await chat.loadThreads('work');

    chat.select('unread');
    await pumpEventQueue();
    chat.select('read');
    chat.select('unread');
    await pumpEventQueue();

    expect(markReads('unread'), [
      {'unread': false, 'profile': 'work'},
    ]);
    expect(chat.threads.firstWhere((t) => t.id == 'unread').unread, isFalse);
  });

  test('opening a read chat sends nothing', () async {
    await chat.loadThreads('work');

    chat.select('read');
    await pumpEventQueue();

    expect(markReads('read'), isEmpty);
  });

  test('a chat fetched on its own is marked read when unread', () async {
    server
      ..on(
        'GET',
        '/api/sessions/older',
        sessionDetailRow(id: 'older', title: 'Delivery', lastReadAt: 0),
      )
      ..on(
        'PATCH',
        '/api/sessions/older',
        sessionPatchBody(flags: {'unread': false}),
      );
    await chat.loadThreads('work');

    chat.open(
      const NotificationTarget(threadId: 'older', profile: 'work'),
      fetchMissing: true,
    );
    await pumpEventQueue();

    expect(chat.selectedId, 'older');
    expect(markReads('older'), [
      {'unread': false, 'profile': 'work'},
    ]);
  });

  test('a failed mark keeps the chat open, says nothing and retries on the '
      'next opening', () async {
    server.on('PATCH', '/api/sessions/unread', {'detail': 'boom'}, status: 500);
    await chat.loadThreads('work');

    chat.select('unread');
    await pumpEventQueue();

    expect(chat.selectedId, 'unread');
    expect(reports, isEmpty);
    expect(chat.threads.firstWhere((t) => t.id == 'unread').unread, isTrue);
    expect(
      [
        for (final (name, attributes) in logged)
          if (name == 'chat.mark_read_failed') attributes,
      ],
      [
        {'error_type': 'DioException'},
      ],
    );

    chat.select('read');
    chat.select('unread');
    await pumpEventQueue();
    expect(markReads('unread'), hasLength(2));
  });

  test('a chat opened while the list loads is marked read', () async {
    final load = chat.loadThreads('work');
    chat.open(
      const NotificationTarget(threadId: 'unread', profile: 'work'),
      fetchMissing: true,
    );
    await load;
    await pumpEventQueue();

    expect(chat.selectedId, 'unread');
    expect(markReads('unread'), [
      {'unread': false, 'profile': 'work'},
    ]);
  });

  test(
    'a chat that became unread since the list loaded is marked read',
    () async {
      server.on(
        'PATCH',
        '/api/sessions/read',
        sessionPatchBody(flags: {'unread': false}),
      );
      await chat.loadThreads('work');
      chat.applyInvalidatedThreads(
        ThreadPage(
          threads: [
            ChatThread(
              id: 'read',
              title: 'Old',
              updatedAt: DateTime(2026),
              remote: true,
              unread: true,
            ),
          ],
          nextOffset: 50,
          hasMore: false,
        ),
        profile: 'work',
        generation: chat.threadListGeneration,
      );

      chat.select('read');
      await pumpEventQueue();

      expect(markReads('read'), hasLength(1));
    },
  );

  test('a chat handed off from another device is marked read', () async {
    server
      ..on(
        'GET',
        '/api/sessions/older',
        sessionDetailRow(id: 'older', lastReadAt: 0),
      )
      ..on(
        'PATCH',
        '/api/sessions/older',
        sessionPatchBody(flags: {'unread': false}),
      );
    await chat.loadThreads('work');

    final restored = await chat.restoreHandoff(
      const NotificationTarget(threadId: 'older', profile: 'work'),
      () => true,
    );
    await pumpEventQueue();

    expect(restored, isTrue);
    expect(markReads('older'), hasLength(1));
  });
}
