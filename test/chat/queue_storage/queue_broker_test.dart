import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/queue_storage/durable_queue_store.dart';
import 'package:hermes_app/src/chat/queue_storage/queue_broker.dart';
import 'package:hermes_app/src/chat/queue_storage/queue_keys.dart';
import 'package:hermes_app/src/chat/queue_storage/queue_record.dart';

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

const _scope = QueueScope(
  serverKey: 'server',
  accountKey: 'account',
  profile: 'work',
  conversationId: 'thread',
);
void main() {
  late Directory directory;
  late _Keys keys;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('queue-broker-test-');
    keys = _Keys();
  });
  tearDown(() => directory.delete(recursive: true));
  for (final profile in <String?>[null, '']) {
    test(
      'broker refuses unresolved profile $profile without creating storage',
      () async {
        final scope = QueueScope(
          serverKey: 'server',
          accountKey: 'account',
          profile: profile,
          conversationId: 'thread',
        );
        final store = DurableQueueStore(directory: directory, keys: keys);
        final broker = QueueOperationBroker(
          scope: scope,
          lease: 'current',
          store: () async => store,
          valid: () => true,
        );
        expect(
          (await broker.handle('lease', {'scope': scope.toJson()}))['ok'],
          false,
        );
        expect(keys.values, isEmpty);
        expect(await directory.list().toList(), isEmpty);
      },
    );
  }

  test('bound broker refuses another profile and stale lease', () async {
    final store = DurableQueueStore(directory: directory, keys: keys);
    final broker = QueueOperationBroker(
      scope: _scope,
      lease: 'current',
      store: () async => store,
      valid: () => true,
    );
    final wrongScope = QueueScope(
      serverKey: 'server',
      accountKey: 'account',
      profile: 'personal',
      conversationId: 'thread',
    );
    expect(
      (await broker.handle('commit', {
        'scope': wrongScope.toJson(),
        'lease': 'current',
        'text': 'private',
      }))['ok'],
      false,
    );
    expect(
      (await broker.handle('commit', {
        'scope': _scope.toJson(),
        'lease': 'old',
        'text': 'private',
      }))['ok'],
      false,
    );
    expect((await store.load(_scope)).records, isEmpty);
  });
  test(
    'authorized remote client persists through main store without local keys',
    () async {
      final store = DurableQueueStore(directory: directory, keys: keys);
      final broker = QueueOperationBroker(
        scope: _scope,
        lease: 'current',
        store: () async => store,
        valid: () => true,
      );
      final client = BrokerQueueStore(broker.handle);
      await client.commit(_scope, 'retained');
      expect((await client.load(_scope)).records.single.text, 'retained');
      expect((await store.load(_scope)).records.single.text, 'retained');
    },
  );
  test(
    'identity invalidated while committing cannot return queue payload',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      var valid = true;
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
      final broker = QueueOperationBroker(
        scope: _scope,
        lease: 'current',
        store: () async => store,
        valid: () => valid,
      );
      final pending = broker.handle('commit', {
        'scope': _scope.toJson(),
        'lease': 'current',
        'text': 'private payload',
      });
      await entered.future;
      valid = false;
      release.complete();
      final result = await pending;
      expect(result['ok'], false);
      expect(result.toString(), isNot(contains('private payload')));
    },
  );
  test(
    'invalidated exact claim restores only its own pre-RPC dispatch',
    () async {
      final store = DurableQueueStore(directory: directory, keys: keys);
      final record = await store.commit(_scope, 'retained');
      var checks = 0;
      final broker = QueueOperationBroker(
        scope: _scope,
        lease: 'current',
        store: () async => store,
        valid: () => ++checks <= 2,
      );
      final response = await broker.handle('begin', {
        'scope': _scope.toJson(),
        'lease': 'current',
        'id': record.id,
        'claim': 'a' * 32,
      });
      expect(response['ok'], false);
      expect(
        (await store.load(_scope)).records.single.state,
        QueueRecordState.queued,
      );
    },
  );

  test('a losing broker claim cannot reset another dispatch owner', () async {
    final store = DurableQueueStore(directory: directory, keys: keys);
    final record = await store.commit(_scope, 'possibly submitted');
    await store.beginSubmission(_scope, record.id, 'a' * 32);
    final broker = QueueOperationBroker(
      scope: _scope,
      lease: 'current',
      store: () async => store,
      valid: () => true,
    );
    expect(
      (await broker.handle('begin', {
        'scope': _scope.toJson(),
        'lease': 'current',
        'id': record.id,
        'claim': 'b' * 32,
      }))['ok'],
      false,
    );
    expect(
      (await broker.handle('notSubmitted', {
        'scope': _scope.toJson(),
        'lease': 'current',
        'id': record.id,
        'claim': 'b' * 32,
      }))['ok'],
      false,
    );
    expect(
      (await store.load(_scope)).records.single.state,
      QueueRecordState.submissionStarted,
    );
  });
}
