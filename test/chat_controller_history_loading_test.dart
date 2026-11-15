import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';
import 'support/fake_notification_service.dart';

/// The history status of a stored chat, through the controller alone.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ValueNotifier<bool> activity;
  late FakeChatTransport transport;
  late FakeHermesServer server;
  late List<String> reports;
  late ChatController chat;
  // One gate per read of s2's messages, in order.
  late List<Completer<FakeResponse>> s2Reads;

  FakeResponse failure() => (status: 500, body: {'detail': 'boom'});
  FakeResponse emptyPage() =>
      (status: 200, body: messageListBody('s2', const []));

  ChatThread thread(String id) => chat.threads.firstWhere((t) => t.id == id);
  ChatHistoryStatus? status(String id) => chat.historyStatusOf(thread(id));
  Future<void> flush() async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    activity = ValueNotifier(true);
    transport = FakeChatTransport();
    reports = [];
    s2Reads = [];
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          sessionRow(id: 's1', title: 'One', lastActive: 1780000600),
          sessionRow(id: 's2', title: 'Two', lastActive: 1780000500),
        ]),
      )
      ..on(
        'GET',
        '/api/sessions/s1/messages',
        messageListBody('s1', [
          messageRow(id: 1, role: 'user', content: 'hello'),
        ]),
      )
      ..onRequest('GET', '/api/sessions/s2/messages', (_) {
        final read = Completer<FakeResponse>();
        s2Reads.add(read);
        return read.future;
      });
    final notifications = FakeNotificationService();
    final attention = AttentionNotifier(
      service: notifications,
      settings: null,
      onOpen: (_) {},
    );
    chat = ChatController(
      activity: activity,
      transport: transport,
      repository: HermesChatRepository(server.client().raw),
      attention: attention,
      report: reports.add,
    );
    addTearDown(chat.dispose);
    addTearDown(activity.dispose);
    addTearDown(notifications.dispose);
    addTearDown(attention.dispose);
    await chat.loadThreads();
    await flush();
    chat.select('s1');
    await flush();
  });

  test(
    'pausing mid-read keeps the chat loading, even after the read ends',
    () async {
      chat.select('s2');
      await flush();
      expect(status('s2'), ChatHistoryStatus.loading);

      activity.value = false;
      await flush();
      expect(status('s2'), ChatHistoryStatus.loading);

      s2Reads.first.complete(emptyPage());
      await flush();
      expect(status('s2'), ChatHistoryStatus.loading);
    },
  );

  test(
    'a failed read is announced to listeners as failed, not loading',
    () async {
      chat.select('s2');
      await flush();
      final seen = <ChatHistoryStatus?>[];
      chat.addListener(() => seen.add(status('s2')));

      s2Reads.first.complete(failure());
      await flush();

      expect(seen, isNotEmpty);
      expect(seen.first, ChatHistoryStatus.failed);
      expect(seen, isNot(contains(ChatHistoryStatus.loading)));
    },
  );

  test('a failed first page raises no snackbar, selected or left', () async {
    chat.select('s2');
    await flush();
    s2Reads.first.complete(failure());
    await flush();
    expect(status('s2'), ChatHistoryStatus.failed);
    expect(reports, isEmpty);

    chat.select('s1');
    await flush();
    chat.select('s2');
    await flush();
    chat.select('s1');
    await flush();
    s2Reads.last.complete(failure());
    await flush();
    expect(reports, isEmpty);
  });

  test('reloading the list drops an earlier failure', () async {
    chat.select('s2');
    await flush();
    s2Reads.first.complete(failure());
    await flush();
    chat.select('s1');
    await flush();
    expect(status('s2'), ChatHistoryStatus.failed);

    await chat.loadThreads();
    await flush();

    expect(chat.selectedThread?.id, isNot('s2'));
    expect(status('s2'), isNull);
  });

  test('Retry then an empty page ends on the welcome view', () async {
    chat.select('s2');
    await flush();
    s2Reads.first.complete(failure());
    await flush();

    chat.retryHistory(thread('s2'));
    await flush();
    expect(status('s2'), ChatHistoryStatus.loading);
    s2Reads.last.complete(emptyPage());
    await flush();

    expect(status('s2'), isNull);
  });

  test('a read that fails after the list reloaded is ignored', () async {
    chat.select('s2');
    await flush();
    await chat.loadThreads();
    await flush();
    reports.clear();

    s2Reads.first.complete(failure());
    await flush();

    expect(status('s2'), isNot(ChatHistoryStatus.failed));
    expect(reports, isEmpty);
  });

  test('Retry on a chat that is not selected reads nothing', () async {
    chat.select('s2');
    await flush();
    s2Reads.first.complete(failure());
    await flush();
    final stale = thread('s2');
    chat.select('s1');
    await flush();
    final reads = s2Reads.length;

    chat.retryHistory(stale);
    await flush();

    expect(s2Reads, hasLength(reads));
    expect(chat.selectedThread?.id, 's1');
  });

  test('Retry on a chat that did not fail reads nothing', () async {
    chat.select('s2');
    await flush();
    final reads = s2Reads.length;

    chat.retryHistory(thread('s2'));
    await flush();

    expect(s2Reads, hasLength(reads));
  });

  test(
    'Retry neither cancels a pending open nor refreshes the active list',
    () async {
      chat.select('s2');
      await flush();
      s2Reads.first.complete(failure());
      await flush();
      final open = chat.openGeneration;
      final asked = transport.activeAsked.length;

      chat.retryHistory(thread('s2'));
      await flush();

      expect(chat.openGeneration, open);
      expect(transport.activeAsked, hasLength(asked));
      expect(s2Reads, hasLength(2));
    },
  );

  group('earlier messages after a send', () {
    ChatEarlierMessagesStatus? earlier() =>
        chat.earlierMessagesStatusOf(thread('s2'));

    FakeResponse page() => (
      status: 200,
      body: messageListBody('s2', [
        messageRow(id: 1, role: 'user', content: 'older question'),
        messageRow(id: 2, role: 'assistant', content: 'older answer'),
      ]),
    );

    Future<void> failThenSend() async {
      chat.select('s2');
      await flush();
      s2Reads.first.complete(failure());
      await flush();
      chat.submit('a new question', const []);
      await flush();
    }

    test('the row shows once a message was sent after the failure, and not '
        'before', () async {
      chat.select('s2');
      await flush();
      s2Reads.first.complete(failure());
      await flush();
      expect(status('s2'), ChatHistoryStatus.failed);
      expect(earlier(), isNull);

      chat.submit('a new question', const []);
      await flush();

      expect(thread('s2').messages, isNotEmpty);
      expect(status('s2'), isNull);
      expect(earlier(), ChatEarlierMessagesStatus.failed);
      expect(s2Reads, hasLength(1), reason: 'nothing reads again on its own');
    });

    test('Retry shows retrying, merges the page above and removes the '
        'row', () async {
      await failThenSend();

      chat.retryHistory(thread('s2'));
      await flush();
      expect(earlier(), ChatEarlierMessagesStatus.retrying);
      expect(s2Reads, hasLength(2));

      s2Reads.last.complete(page());
      await flush();

      expect(earlier(), isNull);
      final texts = thread('s2').messages.map((m) => m.content).toList();
      expect(texts.take(2), ['older question', 'older answer']);
      expect(texts, contains('a new question'));
    });

    test(
      'a second failure brings Retry back, and reads once per tap',
      () async {
        await failThenSend();

        chat.retryHistory(thread('s2'));
        await flush();
        s2Reads.last.complete(failure());
        await flush();
        expect(earlier(), ChatEarlierMessagesStatus.failed);
        expect(s2Reads, hasLength(2));

        chat.retryHistory(thread('s2'));
        await flush();
        expect(earlier(), ChatEarlierMessagesStatus.retrying);
        expect(s2Reads, hasLength(3));
        s2Reads.last.complete(page());
        await flush();
        expect(earlier(), isNull);
      },
    );

    test('a chat that never failed has no row', () async {
      expect(chat.earlierMessagesStatusOf(thread('s1')), isNull);
    });
  });

  test('reselecting a chat while its page is being read waits for that read '
      'before following it', () async {
    chat.select('s2');
    await flush();
    chat.select('s1');
    await flush();
    final follows = transport.followUpCalls;

    chat.select('s2');
    await flush();
    expect(s2Reads, hasLength(1), reason: 'no second read');
    expect(transport.followUpCalls, follows, reason: 'still reading');

    s2Reads.first.complete(emptyPage());
    await flush();
    expect(transport.followUpCalls, follows + 1);
  });
}
