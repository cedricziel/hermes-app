import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/auth/verified_session_owner.dart';
import 'package:hermes_app/src/chat/queue_storage/durable_queue_store.dart';
import 'package:hermes_app/src/chat/queue_storage/queue_persistence.dart';
import 'package:hermes_app/src/chat/queue_storage/queue_record.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../support/fake_device_authenticator.dart';
import '../../support/fake_queue_keys.dart';
import '../../support/fake_session_auth.dart';

class _Store extends DurableQueueStore {
  _Store(Directory directory)
    : super(directory: directory, keys: FakeQueueKeys());
  final deleted = Completer<void>();
  @override
  Future<void> deleteAccount(QueueScope scope) async {
    await super.deleteAccount(scope);
    deleted.complete();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late FakeSessionAuth auth;
  late AppLockController lock;
  late _Store store;
  late QueuePersistence persistence;
  late QueueScope scope;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    directory = await Directory.systemTemp.createTemp('queue-access-test-');
    auth = FakeSessionAuth();
    lock = AppLockController(authenticator: FakeDeviceAuthenticator());
    await lock.load();
    store = _Store(directory);
    persistence = QueuePersistence(
      auth: auth,
      lock: lock,
      factory: () async => store,
    )..start();
    scope = persistence.scopeFor('stored', 'work')!;
    await store.commit(scope, 'retained draft');
  });
  tearDown(() async {
    persistence.dispose();
    lock.dispose();
    auth.dispose();
    await directory.delete(recursive: true);
  });

  test('durable scope requires an explicit profile and protected owner', () {
    expect(persistence.scopeFor('stored', null), isNull);
    expect(persistence.scopeFor('stored', ''), isNull);
    expect(
      persistence.scopeFor('stored', 'work')?.accountKey,
      scope.accountKey,
    );
    auth.expire();
    expect(persistence.allowed, false);
    expect(persistence.scopeFor('stored', 'work'), isNull);
  });

  test(
    'expiry preserves ciphertext until explicit same-owner sign-out',
    () async {
      final other = QueueScope(
        serverKey: scope.serverKey,
        accountKey: 'other-owner',
        profile: scope.profile,
        conversationId: scope.conversationId,
      );
      await store.commit(other, 'other account');
      auth.expire();
      expect((await store.load(scope)).records.single.text, 'retained draft');
      expect(store.deleted.isCompleted, false);
      auth.depart();
      await store.deleted.future.timeout(const Duration(seconds: 5));
      expect((await store.load(scope)).records, isEmpty);
      expect((await store.load(other)).records.single.text, 'other account');
    },
  );

  test(
    'another verified owner never acquires the retained namespace',
    () async {
      auth.expire();
      auth.recover(
        const VerifiedSessionOwner(
          server: 'https://queue.test',
          user: 'other',
          organization: '',
          provider: 'oidc',
        ),
      );
      final next = persistence.scopeFor('stored', 'work')!;
      expect(next.accountKey, isNot(scope.accountKey));
      expect((await store.load(next)).records, isEmpty);
      expect((await store.load(scope)).records.single.text, 'retained draft');
    },
  );
}
