import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/queue_storage/durable_queue_store.dart';
import 'package:hermes_app/src/chat/queue_storage/queue_record.dart';

import '../../support/fake_queue_keys.dart';
import '../../support/queue_store_dir.dart';

const _scope = QueueScope(
  serverKey: 'server',
  accountKey: 'account',
  profile: 'work',
  conversationId: 'session',
);

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('queue-settle-test-');
  });
  tearDown(() async {
    if (directory.existsSync()) await directory.delete(recursive: true);
  });
  DurableQueueStore store({
    Future<void> Function(String operation)? beforeCommit,
  }) => DurableQueueStore(
    directory: directory,
    keys: FakeQueueKeys(),
    beforeCommit: beforeCommit,
  );

  test('settle returns at once when nothing ever ran', () async {
    await DurableQueueStore.settle(directory);
  });

  test('settle waits for operations a finished one then enqueues', () async {
    final queue = store();
    final finished = <String>[];
    // The way the chat controller works: each write starts once the one
    // before it has completed, so a load queued behind the first would return
    // before the third is even enqueued.
    unawaited(
      queue
          .commit(_scope, 'first')
          .then((_) {
            finished.add('commit');
            return queue.load(_scope);
          })
          .then((_) {
            finished.add('load');
            return queue.commit(_scope, 'second');
          })
          .then((_) => finished.add('second commit')),
    );
    await DurableQueueStore.settle(directory);
    expect(finished, ['commit', 'load', 'second commit']);
    await deleteQueueStoreDir(directory);
    expect(directory.existsSync(), isFalse);
  });

  test('settle fails after its bound instead of hanging on a held '
      'operation', () async {
    final gate = Completer<void>();
    final queue = store(beforeCommit: (_) => gate.future);
    final held = queue.commit(_scope, 'held');
    await expectLater(
      DurableQueueStore.settle(
        directory,
        timeout: const Duration(milliseconds: 200),
      ),
      throwsStateError,
    );
    gate.complete();
    await held;
    await DurableQueueStore.settle(directory);
  });
}
