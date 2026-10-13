import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/auth/session_activity.dart';
import 'package:hermes_app/src/auth/verified_session_owner.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/queue_storage/durable_queue_store.dart';
import 'package:hermes_app/src/chat/queue_storage/queue_persistence.dart';
import 'package:hermes_app/src/chat/queue_storage/queue_record.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../support/fake_device_authenticator.dart';
import '../../support/fake_hermes_server.dart';
import '../../support/fake_queue_keys.dart';
import '../../support/fake_queue_transport.dart';
import '../../support/fake_session_auth.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late FakeQueueKeys keys;
  late DurableQueueStore store;
  late FakeSessionAuth auth;
  late AppLockController lock;
  late QueuePersistence persistence;
  late SessionActivity activity;
  late FakeQueueTransport transport;
  late AttentionNotifier attention;
  late ChatController chat;
  late QueueScope scope;
  Future<void> queueRestored() async {
    bool ready() {
      final thread = chat.selectedThread;
      return thread != null &&
          chat.queuedIn(thread).isNotEmpty &&
          !chat.queueBusy(thread);
    }

    if (ready()) return;
    final done = Completer<void>();
    void changed() {
      if (ready() && !done.isCompleted) done.complete();
    }

    chat.addListener(changed);
    try {
      await done.future.timeout(const Duration(seconds: 5));
    } finally {
      chat.removeListener(changed);
    }
  }

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    directory = await Directory.systemTemp.createTemp('queue-auth-test-');
    keys = FakeQueueKeys();
    store = DurableQueueStore(directory: directory, keys: keys);
    auth = FakeSessionAuth();
    lock = AppLockController(authenticator: FakeDeviceAuthenticator());
    await lock.load();
    persistence = QueuePersistence(
      auth: auth,
      lock: lock,
      factory: () async => store,
    )..start();
    activity = SessionActivity(auth);
    scope = persistence.scopeFor('stored', 'work')!;
    await store.commit(scope, 'retained draft');
    final server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 'stored', title: 'Synthetic')]),
      )
      ..on(
        'GET',
        '/api/sessions/stored/messages',
        messageListBody('stored', []),
      );
    transport = FakeQueueTransport();
    attention = AttentionNotifier(
      service: null,
      settings: null,
      onOpen: (_) {},
    );
    chat = ChatController(
      repository: HermesChatRepository(server.client().raw),
      transport: transport,
      activity: activity,
      attention: attention,
      report: (_) {},
      queueStore: persistence.open,
      queueScope: (thread, profile) => persistence.scopeFor(thread.id, profile),
      queueChanges: persistence,
      canShowQueues: () => persistence.visible,
    );
    await chat.loadThreads('work');
    chat.select('stored');
    await queueRestored();
  });
  tearDown(() async {
    chat.dispose();
    activity.dispose();
    persistence.dispose();
    lock.dispose();
    auth.dispose();
    attention.dispose();
    await directory.delete(recursive: true);
  });

  test('terminal expiry retains encrypted ownership and same owner restores paused', () async {
    final original = chat.selectedThread!;
    expect(chat.queuedIn(original).single.text, 'retained draft');
    auth.expire();
    await pumpEventQueue();
    expect(persistence.allowed, false);
    expect(persistence.scopeFor('stored', 'work'), isNull);
    expect(chat.queuedIn(original), isEmpty);
    expect((await store.load(scope)).records.single.text, 'retained draft');
    auth.recover();
    await queueRestored();
    final restored = chat.selectedThread!;
    expect(chat.queuedIn(restored).single.text, 'retained draft');
    expect(chat.queueNeedsReview(restored), true);
    expect(transport.sends, isEmpty);
  });

  test(
    'explicit sign-out after expiry deletes only the remembered owner data',
    () async {
      final other = QueueScope(
        serverKey: scope.serverKey,
        accountKey: 'other-owner',
        profile: scope.profile,
        conversationId: scope.conversationId,
      );
      await store.commit(other, 'other account');
      auth.expire();
      await pumpEventQueue();
      expect((await store.load(scope)).records.single.text, 'retained draft');
      auth.depart();
      await pumpEventQueue();
      expect((await store.load(scope)).records, isEmpty);
      expect((await store.load(other)).records.single.text, 'other account');
    },
  );

  test(
    'another owner after expiry cannot acquire retained old queue scope',
    () async {
      auth.expire();
      await pumpEventQueue();
      auth.recover(
        const VerifiedSessionOwner(
          server: 'https://queue.test',
          user: 'other',
          organization: '',
          provider: 'oidc',
        ),
      );
      await pumpEventQueue();
      expect(activity.retired, true);
      expect(chat.queuedIn(chat.selectedThread!), isEmpty);
      final next = persistence.scopeFor('stored', 'work')!;
      expect(next.accountKey, isNot(scope.accountKey));
      expect((await store.load(next)).records, isEmpty);
      expect((await store.load(scope)).records.single.text, 'retained draft');
      expect(transport.sends, isEmpty);
    },
  );
}
