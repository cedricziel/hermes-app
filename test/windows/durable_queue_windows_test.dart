import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/queue_storage/durable_queue_store.dart';
import 'package:hermes_app/src/chat/queue_storage/queue_record.dart';
import 'package:hermes_app/src/windows/conversation_windows.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_conversation_window_host.dart';
import '../support/fake_queue_keys.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late DurableQueueStore store;
  late FakeConversationWindowHost host;
  late ConversationWindows windows;
  late ValueNotifier<bool> allowed;
  String? profile;
  const scope = QueueScope(
    serverKey: 'https://hermes.test',
    accountKey: 'owner',
    profile: 'work',
    conversationId: 'stored',
  );
  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    directory = await Directory.systemTemp.createTemp('queue-window-test-');
    store = DurableQueueStore(directory: directory, keys: FakeQueueKeys());
    host = FakeConversationWindowHost();
    allowed = ValueNotifier(true);
    profile = 'work';
    windows = ConversationWindows(
      host: host,
      store: ConversationWindowStore(SharedPreferencesAsync()),
      connection: () => (baseUrl: scope.serverKey, authRequired: true),
      ownerKey: () => scope.accountKey,
      headers: ({rejected}) async => const {},
      queueStore: () async => store,
      queueAllowed: () => allowed.value,
    )..bindQueueAccess(allowed);
    windows.currentProfile = () => profile;
  });
  tearDown(() async {
    windows.dispose();
    allowed.dispose();
    await directory.delete(recursive: true);
  });
  Future<Map> call(
    String operation,
    Map<String, Object?> args, {
    String window = 'w0',
  }) async =>
      (await host.call('queue.$operation', {'window_id': window, ...args}))
          as Map;

  test('conversation channel keeps exact scope and invalidates leases across lock cycle', () async {
    await windows.open('stored', profile: 'work', title: 'Synthetic');
    final lease = (await call('lease', {'scope': scope.toJson()}))['lease'];
    expect(lease, isA<String>());
    expect(
      (await call('commit', {
        'scope': {...scope.toJson(), 'conversation': 'other'},
        'lease': lease,
        'text': 'refused',
      }))['ok'],
      false,
    );
    allowed.value = false;
    expect(
      (await call('load', {'scope': scope.toJson(), 'lease': lease}))['ok'],
      false,
    );
    allowed.value = true;
    expect(
      (await call('commit', {
        'scope': scope.toJson(),
        'lease': lease,
        'text': 'stale',
      }))['ok'],
      false,
    );
    final fresh = (await call('lease', {'scope': scope.toJson()}))['lease'];
    expect(fresh, isNot(lease));
    expect(
      (await call('commit', {
        'scope': scope.toJson(),
        'lease': fresh,
        'text': 'retained',
      }))['ok'],
      true,
    );
    expect((await store.load(scope)).records.single.text, 'retained');
  });

  test(
    'quick panel active-profile change revokes earlier conversation lease',
    () async {
      await windows.togglePanel();
      final lease = (await call('lease', {
        'scope': scope.toJson(),
      }, window: 'p0'))['lease'];
      expect(lease, isA<String>());
      profile = 'personal';
      expect(
        (await call('load', {
          'scope': scope.toJson(),
          'lease': lease,
        }, window: 'p0'))['ok'],
        false,
      );
      expect(
        (await call('lease', {'scope': scope.toJson()}, window: 'p0'))['ok'],
        false,
      );
      final personal = QueueScope(
        serverKey: scope.serverKey,
        accountKey: scope.accountKey,
        profile: profile,
        conversationId: 'stored',
      );
      final fresh = (await call('lease', {
        'scope': personal.toJson(),
      }, window: 'p0'))['lease'];
      expect(
        (await call('commit', {
          'scope': personal.toJson(),
          'lease': fresh,
          'text': 'personal',
        }, window: 'p0'))['ok'],
        true,
      );
      expect((await store.load(scope)).records, isEmpty);
      expect((await store.load(personal)).records.single.text, 'personal');
    },
  );

  test('unresolved quick panel profile cannot issue a lease', () async {
    profile = null;
    await windows.togglePanel();
    final unknown = QueueScope(
      serverKey: scope.serverKey,
      accountKey: scope.accountKey,
      profile: null,
      conversationId: 'stored',
    );
    expect(
      (await call('lease', {'scope': unknown.toJson()}, window: 'p0'))['ok'],
      false,
    );
    expect(await directory.list().toList(), isEmpty);
  });
}
