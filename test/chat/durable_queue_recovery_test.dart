import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/queue_storage/durable_queue_store.dart';
import 'package:hermes_app/src/chat/queue_storage/queue_keys.dart';
import 'package:hermes_app/src/chat/queue_storage/queue_record.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';

import '../support/fake_queue_transport.dart';
import '../support/fake_hermes_server.dart';

import 'package:hermes_app/src/chat/hermes_chat_repository.dart';

class _Keys implements QueueKeys {
  final values = <String, List<int>>{};
  @override
  Future<List<int>?> read(String account) async => values[account];
  @override
  Future<void> write(String account, List<int> key) async {
    values[account] = key;
  }

  @override
  Future<void> delete(String account) async {
    values.remove(account);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late _Keys keys;
  late FakeQueueTransport transport;
  late AttentionNotifier attention;
  late List<String> reports;
  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    directory = await Directory.systemTemp.createTemp('queue-recovery-test-');
    keys = _Keys();
    transport = FakeQueueTransport();
    attention = AttentionNotifier(
      service: null,
      settings: null,
      onOpen: (_) {},
    );
    reports = [];
  });
  tearDown(() async {
    attention.dispose();
    await directory.delete(recursive: true);
  });
  Future<ChatController> controller(
    DurableQueueStore store, {
    ValueNotifier<String>? owner,
  }) async {
    final server = FakeHermesServer()
      ..on('GET', '/api/sessions', sessionListBody([]));
    final chat = ChatController(
      repository: HermesChatRepository(server.client().raw),
      transport: transport,
      attention: attention,
      report: reports.add,
      queueStore: () async => store,
      queueChanges: owner,
      queueScope: (thread, profile) => QueueScope(
        serverKey: 'server',
        accountKey: owner?.value ?? 'account',
        profile: profile,
        conversationId: thread.id,
      ),
    );
    await chat.loadThreads('work');
    return chat;
  }

  test(
    'enqueue waits for durable commit and refuses concurrent duplicate',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      final store = DurableQueueStore(
        directory: directory,
        keys: keys,
        beforeCommit: (operation) async {
          if (operation == 'record') {
            entered.complete();
            await release.future;
          }
        },
      );
      final chat = await controller(store);
      addTearDown(chat.dispose);
      chat.newThread();
      await chat.submit('first', const []);
      transport.sends.last.emit(const ThreadBound('s1'));
      await pumpEventQueue();
      var completed = false;
      final queued = Future.sync(() => chat.submit('next', const []))
          .then((result) {
            completed = true;
            return result;
          });
      await entered.future;
      expect(completed, false);
      expect(await chat.submit('duplicate', const []), false);
      release.complete();
      expect(await queued, true);
      expect(chat.queuedIn(chat.selectedThread!).single.text, 'next');
    },
  );
  test(
    'failed durable enqueue reports false without adding a local prompt',
    () async {
      final store = DurableQueueStore(
        directory: directory,
        keys: keys,
        beforeCommit: (operation) async {
          if (operation == 'record') {
            throw StateError('disk unavailable');
          }
        },
      );
      final chat = await controller(store);
      addTearDown(chat.dispose);
      chat.newThread();
      await chat.submit('first', const []);
      transport.sends.last.emit(const ThreadBound('s1'));
      await pumpEventQueue();
      expect(await chat.submit('retained composer text', const []), false);
      expect(chat.queuedIn(chat.selectedThread!), isEmpty);
      expect(
        reports,
        contains('Could not queue this prompt. Your draft was kept.'),
      );
    },
  );
  test(
    'first binding keeps enqueue pending then commits stable session scope',
    () async {
      final store = DurableQueueStore(directory: directory, keys: keys);
      final chat = await controller(store);
      addTearDown(chat.dispose);
      chat.newThread();
      await chat.submit('opening', const []);
      var finished = false;
      final queued = Future.sync(() => chat.submit('next', const []))
          .then((value) {
            finished = true;
            return value;
          });
      await pumpEventQueue();
      expect(finished, false);
      transport.sends.first.emit(const ThreadBound('stable-session'));
      expect(await queued, true);
      const scope = QueueScope(
        serverKey: 'server',
        accountKey: 'account',
        profile: 'work',
        conversationId: 'stable-session',
      );
      expect((await store.load(scope)).records.single.text, 'next');
    },
  );
  test(
    'opening failure releases pending enqueue without persisting a local scope',
    () async {
      final store = DurableQueueStore(directory: directory, keys: keys);
      final chat = await controller(store);
      addTearDown(chat.dispose);
      chat.newThread();
      await chat.submit('opening', const []);
      final queued = Future.sync(() => chat.submit('kept draft', const []));
      await pumpEventQueue();
      transport.sends.first
        ..emit(const ReplyCompleted('Opening failed', failed: true))
        ..finish();
      expect(await queued, false);
      expect(chat.queuedIn(chat.selectedThread!), isEmpty);
      expect(
        (await directory.list(recursive: true).toList())
            .whereType<File>()
            .where((file) => file.path.endsWith('.rec')),
        isEmpty,
      );
    },
  );
  test(
    'stop releases pending binding and late binding cannot commit it',
    () async {
      final store = DurableQueueStore(directory: directory, keys: keys);
      final chat = await controller(store);
      addTearDown(chat.dispose);
      chat.newThread();
      await chat.submit('opening', const []);
      final thread = chat.selectedThread!;
      final queued = Future.sync(() => chat.submit('kept draft', const []));
      await pumpEventQueue();
      await chat.stopReply(thread);
      expect(await queued, false);
      transport.sends.first.emit(const ThreadBound('late-session'));
      await pumpEventQueue();
      expect(chat.queuedIn(thread), isEmpty);
    },
  );
  test('reply stopped during durable commit leaves the queue paused', () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    final store = DurableQueueStore(
      directory: directory,
      keys: keys,
      beforeCommit: (operation) async {
        if (operation == 'record') {
          entered.complete();
          await release.future;
        }
      },
    );
    final chat = await controller(store);
    addTearDown(chat.dispose);
    chat.newThread();
    await chat.submit('first', const []);
    transport.sends.first.emit(const ThreadBound('session'));
    await pumpEventQueue();
    final queued = Future.sync(() => chat.submit('next', const []));
    await entered.future;
    transport.sends.first
      ..emit(const ReplyCompleted('Stopped', stopped: true))
      ..finish();
    await pumpEventQueue();
    release.complete();
    expect(await queued, true);
    expect(transport.sends, hasLength(1));
    expect(chat.queuePaused(chat.selectedThread!), true);
  });

  test(
    'owner change releases binding wait without committing any record',
    () async {
      final owner = ValueNotifier('account');
      addTearDown(owner.dispose);
      final store = DurableQueueStore(directory: directory, keys: keys);
      final chat = await controller(store, owner: owner);
      addTearDown(chat.dispose);
      chat.newThread();
      await chat.submit('opening', const []);
      final queued = Future.sync(() => chat.submit('kept draft', const []));
      await pumpEventQueue();
      owner.value = 'another-account';
      expect(await queued, false);
      transport.sends.first.emit(const ThreadBound('late-session'));
      await pumpEventQueue();
      expect(chat.queuedIn(chat.selectedThread!), isEmpty);
    },
  );
  test(
    'normal completion during durable commit drains only after session settles',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      final store = DurableQueueStore(
        directory: directory,
        keys: keys,
        beforeCommit: (operation) async {
          if (operation == 'record') {
            entered.complete();
            await release.future;
          }
        },
      );
      final chat = await controller(store);
      addTearDown(chat.dispose);
      chat.newThread();
      await chat.submit('first', const []);
      transport.sends.single.emit(const ThreadBound('session'));
      await pumpEventQueue();
      final queued = Future.sync(() => chat.submit('next', const []));
      await entered.future;
      transport.sends.single
        ..emit(const ReplyCompleted('Done'))
        ..finish();
      await pumpEventQueue();
      release.complete();
      expect(await queued, true);
      expect(transport.sends, hasLength(1));
      transport.followUpStreams['session']!.emit(
        const SessionInfo(running: false),
      );
      await transport.prepared.timeout(const Duration(seconds: 5));
      await pumpEventQueue();
      expect(transport.sends.map((send) => send.text), ['first', 'next']);
    },
  );
}
