import 'dart:io';
import 'dart:convert';

import 'package:hermes_app/src/chat/chat_transport.dart'
    show kMaxAttachmentBytes;

import '../../support/fake_queue_keys.dart';
import '../../support/recorded_events.dart';
import '../../support/recording_tracer.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/queue_storage/durable_queue_store.dart';
import 'package:hermes_app/src/chat/queue_storage/queue_record.dart';

const scope = QueueScope(
  serverKey: 'server',
  accountKey: 'account',
  profile: 'work',
  conversationId: 'session',
);
void main() {
  late Directory directory;
  late FakeQueueKeys keys;
  DurableQueueStore store() =>
      DurableQueueStore(directory: directory, keys: keys);
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('queue-store-test-');
    keys = FakeQueueKeys();
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });
  test('committed FIFO records survive a fresh store instance', () async {
    await store().commit(scope, 'first', displayText: 'shown first');
    await store().commit(scope, 'second');
    final loaded = await store().load(scope);
    expect(loaded.records.map((record) => record.text), ['first', 'second']);
    expect(loaded.records.first.displayText, 'shown first');
  });
  Future<List<File>> stored(String extension) async =>
      (await directory.list(recursive: true).toList())
          .whereType<File>()
          .where((file) => file.path.endsWith(extension))
          .toList();
  const otherProfile = QueueScope(
    serverKey: 'server',
    accountKey: 'account',
    profile: 'personal',
    conversationId: 'session',
  );
  const otherAccount = QueueScope(
    serverKey: 'server',
    accountKey: 'other-account',
    profile: 'work',
    conversationId: 'session',
  );
  const otherServer = QueueScope(
    serverKey: 'other-server',
    accountKey: 'account',
    profile: 'work',
    conversationId: 'session',
  );

  test('same conversation ID stays isolated by profile and account', () async {
    await store().commit(scope, 'work');
    await store().commit(otherProfile, 'personal');
    await store().commit(otherAccount, 'another account');
    await store().commit(otherServer, 'another server');
    expect((await store().load(scope)).records.single.text, 'work');
    expect((await store().load(otherProfile)).records.single.text, 'personal');
    expect(
      (await store().load(otherAccount)).records.single.text,
      'another account',
    );
    expect(
      (await store().load(otherServer)).records.single.text,
      'another server',
    );
  });

  test('one corrupt envelope preserves another valid record', () async {
    final damaged = await store().commit(scope, 'damaged');
    await store().commit(scope, 'survives');
    final file = (await stored('.rec'))
        .singleWhere((file) => file.path.endsWith('${damaged.id}.rec'));
    await file.writeAsBytes([1, 2, 3]);
    final loaded = await store().load(scope);
    expect(loaded.corruptRecords, 1);
    expect(loaded.records.single.text, 'survives');
  });

  test('discard removes a corrupt envelope and only its owned blobs', () async {
    final source = File('${directory.path}/source.txt');
    await source.writeAsString('attachment bytes');
    final input = QueueAttachmentInput(path: source.path, name: 'source.txt');
    final damaged = await store().commit(scope, 'damaged', files: [input]);
    final survivor = await store().commit(scope, 'survivor', files: [input]);
    final envelope = (await stored('.rec'))
        .singleWhere((file) => file.path.endsWith('${damaged.id}.rec'));
    final blob = (await stored('.blob')).singleWhere(
      (file) => file.path.endsWith(damaged.attachments.single.blobId),
    );
    final unrelated = File('${envelope.parent.path}/${damaged.id}-short.blob');
    await unrelated.writeAsString('not an owned attachment');
    await envelope.writeAsBytes([1, 2, 3]);

    await store().discard(scope, damaged.id);

    expect(await envelope.exists(), false);
    expect(await blob.exists(), false);
    expect(await unrelated.exists(), true);
    final loaded = await store().load(scope);
    expect(loaded.corruptRecords, 0);
    expect(loaded.records.single.id, survivor.id);
    expect(
      await store().readAttachment(
        scope,
        survivor.id,
        survivor.attachments.single.blobId,
      ),
      utf8.encode('attachment bytes'),
    );
  });

  test(
    'explicit discard removes scoped files while keys are unavailable',
    () async {
      final source = File('${directory.path}/source.txt');
      await source.writeAsString('attachment bytes');
      final record = await store().commit(
        scope,
        'discarded',
        files: [QueueAttachmentInput(path: source.path, name: 'source.txt')],
      );
      keys.unavailable = true;

      await store().discard(scope, record.id);

      expect(await stored('.rec'), isEmpty);
      expect(await stored('.blob'), isEmpty);
      expect(keys.values, hasLength(1));
      expect(await source.readAsString(), 'attachment bytes');
    },
  );

  test(
    'discard rejects an unsafe record ID without touching stored files',
    () async {
      final record = await store().commit(scope, 'retained');
      await expectLater(
        store().discard(scope, '../${record.id}'),
        throwsA(isA<QueueStorageException>()),
      );
      expect((await store().load(scope)).records.single.id, record.id);
    },
  );

  test('corrupt index rebuilds from authenticated records', () async {
    await store().commit(scope, 'retained');
    final index = (await stored('index.json')).single;
    await index.writeAsString('corrupt');
    final loaded = await store().load(scope);
    expect(loaded.records.single.text, 'retained');
    expect(
      (jsonDecode(await index.readAsString())
          as Map<String, dynamic>)['version'],
      1,
    );
  });

  test('attachments survive removal of their original file', () async {
    final original = File('${directory.path}/source.txt');
    await original.writeAsString('private attachment bytes');
    final record = await store().commit(
      scope,
      'prompt',
      files: [
        QueueAttachmentInput(
          path: original.path,
          name: 'private-name.txt',
          mimeType: 'text/plain',
        ),
      ],
    );
    await original.delete();
    final recovered = (await store().load(scope)).records.single;
    expect(recovered.attachments.single.name, 'private-name.txt');
    expect(
      utf8.decode(
        await store().readAttachment(
          scope,
          record.id,
          recovered.attachments.single.blobId,
        ),
      ),
      'private attachment bytes',
    );
  });

  test('failed record commit preserves prior record and source file', () async {
    await store().commit(scope, 'prior');
    final original = File('${directory.path}/source.txt');
    await original.writeAsString('source stays');
    final failing = DurableQueueStore(
      directory: directory,
      keys: keys,
      beforeCommit: (operation) async {
        if (operation == 'record') throw StateError('disk full');
      },
    );
    await expectLater(
      failing.commit(
        scope,
        'uncommitted',
        files: [QueueAttachmentInput(path: original.path, name: 'name')],
      ),
      throwsStateError,
    );
    expect((await store().load(scope)).records.single.text, 'prior');
    expect(await original.readAsString(), 'source stays');
    expect(await stored('.blob'), isEmpty);
    expect(await stored('.tmp'), isEmpty);
  });

  test(
    'oversized attachment is refused without losing existing queue',
    () async {
      await store().commit(scope, 'prior');
      final original = File('${directory.path}/large');
      final handle = await original.open(mode: FileMode.write);
      await handle.truncate(kMaxAttachmentBytes + 1);
      await handle.close();
      await expectLater(
        store().commit(
          scope,
          'too big',
          files: [QueueAttachmentInput(path: original.path, name: 'large')],
        ),
        throwsA(
          isA<QueueStorageException>().having(
            (error) => error.reason,
            'reason',
            'attachment_too_large',
          ),
        ),
      );
      expect((await store().load(scope)).records.single.text, 'prior');
      expect(await original.length(), kMaxAttachmentBytes + 1);
    },
  );

  test('index commit failure still recovers committed record', () async {
    final failingIndex = DurableQueueStore(
      directory: directory,
      keys: keys,
      beforeCommit: (operation) async {
        if (operation == 'index') throw StateError('index unavailable');
      },
    );
    await failingIndex.commit(scope, 'committed envelope');
    expect(
      (await store().load(scope)).records.single.text,
      'committed envelope',
    );
  });

  test(
    'concurrent store instances preserve FIFO and one account key',
    () async {
      await Future.wait([
        store().commit(scope, 'first'),
        store().commit(scope, 'second'),
      ]);
      expect((await store().load(scope)).records.map((record) => record.text), [
        'first',
        'second',
      ]);
      expect(keys.values, hasLength(1));
    },
  );

  test(
    'default profile and separate conversation retain exact identities',
    () async {
      const defaultProfile = QueueScope(
        serverKey: 'server',
        accountKey: 'account',
        profile: null,
        conversationId: 'session',
      );
      const anotherConversation = QueueScope(
        serverKey: 'server',
        accountKey: 'account',
        profile: 'work',
        conversationId: 'other-session',
      );
      await store().commit(scope, 'work session');
      await store().commit(defaultProfile, 'default session');
      await store().commit(anotherConversation, 'other session');
      expect(
        (await store().load(defaultProfile)).records.single.text,
        'default session',
      );
      expect(
        (await store().load(anotherConversation)).records.single.text,
        'other session',
      );
      expect((await store().load(scope)).records.single.text, 'work session');
    },
  );

  test(
    'load removes interrupted temporary files and unattached blobs',
    () async {
      final record = await store().commit(scope, 'retained');
      final parent = (await stored('.rec')).single.parent;
      await File('${parent.path}/interrupted.tmp')
          .writeAsString('temporary ciphertext');
      await File('${parent.path}/orphan-unused.blob')
          .writeAsString('orphan ciphertext');
      expect((await store().load(scope)).records.single.id, record.id);
      expect(await stored('.tmp'), isEmpty);
      expect(await stored('.blob'), isEmpty);
    },
  );

  test('locked keys fail closed without replacing payload or key', () async {
    await store().commit(scope, 'retained');
    final prior = await (await stored('.rec')).single.readAsBytes();
    keys.unavailable = true;
    await expectLater(store().load(scope), throwsStateError);
    expect(await (await stored('.rec')).single.readAsBytes(), prior);
    keys.unavailable = false;
    expect((await store().load(scope)).records.single.text, 'retained');
  });

  test(
    'missing key beside ciphertext never generates a replacement key',
    () async {
      await store().commit(scope, 'retained');
      keys.values.clear();
      await expectLater(
        store().commit(scope, 'replacement'),
        throwsA(
          isA<QueueStorageException>().having(
            (error) => error.reason,
            'reason',
            'key_unavailable',
          ),
        ),
      );
      expect(keys.values, isEmpty);
      expect(await stored('.rec'), hasLength(1));
    },
  );

  test(
    'submission started survives restart and cannot reset to unsent',
    () async {
      final record = await store().commit(scope, 'prompt');
      await store().setState(
        scope,
        record.id,
        QueueRecordState.submissionStarted,
      );
      expect(
        (await store().load(scope)).records.single.state,
        QueueRecordState.submissionStarted,
      );
      await expectLater(
        store().setState(scope, record.id, QueueRecordState.queued),
        throwsA(isA<QueueStorageException>()),
      );
    },
  );

  test(
    'failed submission-state commit retains the prior valid state',
    () async {
      final record = await store().commit(scope, 'prompt');
      final failing = DurableQueueStore(
        directory: directory,
        keys: keys,
        beforeCommit: (operation) async {
          if (operation == 'state') throw StateError('stopped');
        },
      );
      await expectLater(
        failing.setState(scope, record.id, QueueRecordState.submissionStarted),
        throwsStateError,
      );
      expect(
        (await store().load(scope)).records.single.state,
        QueueRecordState.queued,
      );
    },
  );

  test(
    'accepted records and their attachments disappear from recovery',
    () async {
      final original = File('${directory.path}/source.txt');
      await original.writeAsString('bytes');
      final record = await store().commit(
        scope,
        'prompt',
        files: [QueueAttachmentInput(path: original.path, name: 'file')],
      );
      await store().setState(
        scope,
        record.id,
        QueueRecordState.submissionStarted,
      );
      await store().setState(scope, record.id, QueueRecordState.accepted);
      expect((await store().load(scope)).records, isEmpty);
      expect(await stored('.rec'), isEmpty);
      expect(await stored('.blob'), isEmpty);
      expect(await original.exists(), isTrue);
    },
  );

  test('conversation deletion preserves another profile queue', () async {
    await store().commit(scope, 'deleted');
    await store().commit(otherProfile, 'retained');
    await store().deleteConversation(scope);
    expect((await store().load(scope)).records, isEmpty);
    expect((await store().load(otherProfile)).records.single.text, 'retained');
  });

  test('account deletion preserves another account key and records', () async {
    await store().commit(scope, 'deleted');
    await store().commit(otherAccount, 'retained');
    await store().deleteAccount(scope);
    expect((await store().load(scope)).records, isEmpty);
    expect((await store().load(otherAccount)).records.single.text, 'retained');
    expect(keys.values, hasLength(1));
  });

  test(
    'server deletion removes all its accounts but keeps another server',
    () async {
      await store().commit(scope, 'deleted');
      await store().commit(otherAccount, 'also deleted');
      await store().commit(otherServer, 'retained');
      await store().deleteServer(scope.serverKey);
      expect((await store().load(scope)).records, isEmpty);
      expect((await store().load(otherAccount)).records, isEmpty);
      expect((await store().load(otherServer)).records.single.text, 'retained');
      expect(keys.values, hasLength(1));
    },
  );

  test(
    'failed account cleanup blocks recovery and retries after unlock',
    () async {
      await store().commit(scope, 'must stay hidden');
      keys.unavailable = true;
      await expectLater(store().deleteAccount(scope), throwsStateError);
      expect(await stored('.delete'), hasLength(1));
      await expectLater(
        store().load(scope),
        throwsA(
          isA<QueueStorageException>().having(
            (error) => error.reason,
            'reason',
            'cleanup_pending',
          ),
        ),
      );
      keys.unavailable = false;
      expect((await store().load(scope)).records, isEmpty);
      expect(await stored('.delete'), isEmpty);
      expect(keys.values, isEmpty);
    },
  );

  test(
    'disk payloads and telemetry omit prompts names identities and key bytes',
    () async {
      final tracer = RecordingTracer();
      final events = RecordedEvents();
      final observed = DurableQueueStore(
        directory: directory,
        keys: keys,
        tracer: tracer,
        events: events.call,
      );
      final record = await observed.commit(
        scope,
        'private prompt text',
        displayText: 'private display',
      );
      final bytes = await (await stored('.rec')).single.readAsBytes();
      final disk = utf8.decode(bytes, allowMalformed: true);
      expect(disk, isNot(contains('private prompt')));
      expect(disk, isNot(contains('private display')));
      expect(disk, isNot(contains('conversation')));
      expect(
        await (await stored('index.json')).single.readAsString(),
        isNot(contains('private')),
      );
      expect(tracer.spans.single.name, 'chat.queue.storage');
      expect(tracer.spans.single.attributes, {
        'operation': 'commit',
        'outcome': 'completed',
        'entries': 1,
        'bytes': 0,
      });
      await expectLater(
        observed.setState(scope, record.id, QueueRecordState.queued),
        completes,
      );
      keys.unavailable = true;
      await expectLater(observed.load(scope), throwsStateError);
      expect(events.named('chat.queue.storage_failed').last, {
        'operation': 'load',
        'reason': 'unavailable',
        'error.type': 'StateError',
      });
    },
  );

  test(
    'throwing telemetry cannot break storage or hide a storage error',
    () async {
      final observed = DurableQueueStore(
        directory: directory,
        keys: keys,
        tracer: ThrowingTracer(),
        events: (name, [attributes = const {}]) =>
            throw StateError('logger failed'),
      );
      await observed.commit(scope, 'retained');
      expect((await observed.load(scope)).records.single.text, 'retained');
      keys.unavailable = true;
      await expectLater(observed.load(scope), throwsStateError);
    },
  );
  test(
    'unclaimed uncertain record cannot be restored without dispatch proof',
    () async {
      final record = await store().commit(scope, 'prompt');
      await store().setState(
        scope,
        record.id,
        QueueRecordState.submissionStarted,
      );
      await expectLater(
        store().restoreUnsentAfterPreSubmitFailure(scope, record.id),
        throwsA(isA<QueueStorageException>()),
      );
      expect(
        (await store().load(scope)).records.single.state,
        QueueRecordState.submissionStarted,
      );
    },
  );

  test(
    'one submission claim owns a record and only its proof can restore it',
    () async {
      final record = await store().commit(scope, 'prompt');
      const first = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      const second = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      await store().beginSubmission(scope, record.id, first);
      await expectLater(
        store().beginSubmission(scope, record.id, second),
        throwsA(isA<QueueStorageException>()),
      );
      await expectLater(
        store().restoreUnsentAfterPreSubmitFailure(
          scope,
          record.id,
          claim: second,
        ),
        throwsA(isA<QueueStorageException>()),
      );
      expect(
        (await store().load(scope)).records.single.state,
        QueueRecordState.submissionStarted,
      );
      await store().beginSubmission(scope, record.id, first);
      await store().restoreUnsentAfterPreSubmitFailure(
        scope,
        record.id,
        claim: first,
      );
      expect(
        (await store().load(scope)).records.single.state,
        QueueRecordState.queued,
      );
    },
  );
}
