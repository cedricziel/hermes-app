import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/slash_command.dart';
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

  test('a full-screen Retry made stale by a list reload does not bring the '
      'failure back for a chat that is no longer kept', () async {
    chat.select('s2');
    await flush();
    s2Reads.first.complete(failure());
    await flush();
    chat.retryHistory(thread('s2'));
    await flush();
    chat.select('s1');
    await flush();
    await chat.loadThreads();
    await flush();

    s2Reads.last.complete(failure());
    await flush();

    expect(status('s2'), isNot(ChatHistoryStatus.failed));
  });

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

    test('Retry resends nothing: the transport sees no new send', () async {
      await failThenSend();
      final sends = transport.sends.length;
      final messages = thread('s2').messages.length;

      chat.retryHistory(thread('s2'));
      await flush();
      expect(transport.sends, hasLength(sends));
      s2Reads.last.complete(page());
      await flush();
      expect(transport.sends, hasLength(sends));
      final queued = thread('s2').messages
          .where(
            (m) => m.role == ChatRole.user && m.content == 'a new question',
          )
          .length;
      expect(queued, 1);
      expect(chat.queuedIn(thread('s2')), isEmpty);
      // Only the two older messages came in, nothing was added by Retry.
      expect(thread('s2').messages, hasLength(messages + 2));
    });

    test('a list reload while a message is sending keeps the row, and Retry '
        'still reads', () async {
      await failThenSend();
      expect(earlier(), ChatEarlierMessagesStatus.failed);

      await chat.loadThreads();
      await flush();
      // The reload reads the open chat's page again, and the row says so.
      expect(earlier(), ChatEarlierMessagesStatus.retrying);
      expect(s2Reads, hasLength(2));
      s2Reads.last.complete(failure());
      await flush();

      expect(earlier(), ChatEarlierMessagesStatus.failed);
      chat.retryHistory(thread('s2'));
      await flush();
      expect(s2Reads, hasLength(3));
      expect(earlier(), ChatEarlierMessagesStatus.retrying);
    });

    test('a list reload that fails while Retry reads does not lose the '
        'row', () async {
      await failThenSend();
      chat.retryHistory(thread('s2'));
      await flush();
      server.on('GET', '/api/sessions', {'detail': 'boom'}, status: 500);

      await chat.loadThreads();
      await flush();
      s2Reads.last.complete(failure());
      await flush();

      expect(earlier(), ChatEarlierMessagesStatus.failed);
      chat.retryHistory(thread('s2'));
      await flush();
      expect(s2Reads, hasLength(3));
    });

    for (final (name, staleFails) in [
      ('a stale failure', true),
      ('a stale success', false),
    ]) {
      test('$name of a Retry the reload replaced changes nothing, and the '
          'newer read decides', () async {
        await failThenSend();
        chat.retryHistory(thread('s2'));
        await flush();
        await chat.loadThreads();
        await flush();
        // Read 1 failed, read 2 was the Retry, read 3 is the reload's.
        expect(s2Reads, hasLength(3));
        expect(earlier(), ChatEarlierMessagesStatus.retrying);

        s2Reads[1].complete(staleFails ? failure() : page());
        await flush();
        expect(earlier(), ChatEarlierMessagesStatus.retrying);

        s2Reads[2].complete(page());
        await flush();
        expect(earlier(), isNull);
        expect(
          thread('s2').messages.map((m) => m.content),
          contains('older question'),
        );
      });
    }

    test('a first page that lands through a slash command refresh ends the '
        'failure and the retry for good', () async {
      await failThenSend();
      chat.retryHistory(thread('s2'));
      await flush();
      server.on('GET', '/api/sessions', {'detail': 'boom'}, status: 500);
      await chat.loadThreads();
      await flush();
      transport.slashResult = const SlashCommandResult(
        threadId: 's2',
        output: 'ok',
        prefill: 'draft',
      );
      final running = chat.runSlashCommand('/review');
      await flush();

      // The Retry read, made stale by the failed reload, fails; the refresh
      // behind the command then reads the page itself.
      s2Reads[1].complete(failure());
      await flush();
      s2Reads.last.complete(page());
      await running;
      await flush();

      expect(earlier(), isNull);
      expect(status('s2'), isNull);
      final reads = s2Reads.length;
      chat.retryHistory(thread('s2'));
      await flush();
      expect(s2Reads, hasLength(reads), reason: 'nothing left to retry');
    });

    test('a stale Retry read that ends after a slash command refresh landed '
        'the page does not bring the failure back', () async {
      await failThenSend();
      chat.retryHistory(thread('s2'));
      await flush();
      final retry = s2Reads.last;
      // A pause drops the read from the controller's view and makes it stale.
      activity.value = false;
      await flush();
      activity.value = true;
      await flush();
      final before = s2Reads.length;
      transport.slashResult = const SlashCommandResult(
        threadId: 's2',
        output: 'ok',
        prefill: 'draft',
      );
      final running = chat.runSlashCommand('/review');
      await flush();
      expect(before, greaterThan(0));

      // Every other read of the page lands it; the stale Retry read is last.
      for (var i = 0; i < 5; i++) {
        for (final read in s2Reads) {
          if (!identical(read, retry) && !read.isCompleted) {
            read.complete(page());
          }
        }
        await flush();
      }
      await running;
      retry.complete(failure());
      await flush();

      expect(earlier(), isNull);
      expect(status('s2'), isNull);
    });

    for (final (name, retryFails) in [('failure', true), ('success', false)]) {
      test('a Retry read overtaken by a refresh in the same load does not '
          'decide the row: its $name is ignored', () async {
        await failThenSend();
        transport.slashResult = const SlashCommandResult(
          threadId: 's2',
          output: 'ok',
          prefill: 'draft',
        );
        final running = chat.runSlashCommand('/review');
        await flush();
        // Read 1 failed; read 2 is the refresh behind the command.
        expect(s2Reads, hasLength(2));
        chat.retryHistory(thread('s2'));
        await flush();
        expect(s2Reads, hasLength(3));

        s2Reads[1].complete(page());
        await running;
        await flush();
        expect(earlier(), isNull);
        final landed = thread('s2').messages.map((m) => m.content).toList();
        expect(landed, contains('older question'));

        s2Reads[2].complete(
          retryFails
              ? failure()
              : (
                  status: 200,
                  body: messageListBody('s2', [
                    messageRow(id: 8, role: 'user', content: 'stale question'),
                  ]),
                ),
        );
        await flush();

        expect(earlier(), isNull);
        expect(status('s2'), isNull);
        expect(
          thread('s2').messages.map((m) => m.content).toList(),
          landed,
          reason: 'the newer page is kept as it was',
        );
        final reads = s2Reads.length;
        chat.retryHistory(thread('s2'));
        await flush();
        expect(s2Reads, hasLength(reads), reason: 'nothing left to retry');
      });
    }

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
