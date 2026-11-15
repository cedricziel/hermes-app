import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/queue_storage/durable_queue_store.dart';
import 'package:hermes_app/src/chat/queue_storage/queue_record.dart';

import '../../support/fake_queue_keys.dart';

const scope = QueueScope(
  serverKey: 'server',
  accountKey: 'account',
  profile: 'work',
  conversationId: 'session',
);
const otherProfile = QueueScope(
  serverKey: 'server',
  accountKey: 'account',
  profile: 'personal',
  conversationId: 'session',
);

void main() {
  late Directory directory;
  late FakeQueueKeys keys;
  DurableQueueStore store() =>
      DurableQueueStore(directory: directory, keys: keys);

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('queue-binding-test-');
    keys = FakeQueueKeys();
    // Creates the account key both scopes share.
    await store().commit(scope, 'creates the account key');
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });

  String hash(String value) => sha256.convert(utf8.encode(value)).toString();
  String id(int n) => n.toRadixString(16).padLeft(32, '0');

  // Writes an envelope the way the store does, but lets a test choose the
  // scope the ciphertext is sealed for, the folder it sits in, the scope
  // written inside it, the file name and the record id inside it.
  Future<void> plant({
    required QueueScope sealedFor,
    required QueueScope inner,
    required String fileId,
    required String recordId,
  }) async {
    final server = hash(sealedFor.serverKey);
    final account = hash('${sealedFor.serverKey}\u0000${sealedFor.accountKey}');
    final aad = utf8.encode(
      'queue.v1/$server/$account/'
      '${hash(jsonEncode(sealedFor.toJson()))}/$fileId.rec',
    );
    // Every planted file sits in otherProfile's folder.
    final folder = Directory(
      '${directory.path}/${hash(otherProfile.serverKey)}/'
      '${hash('${otherProfile.serverKey}\u0000${otherProfile.accountKey}')}/'
      '${hash(jsonEncode(otherProfile.toJson()))}',
    );
    await folder.create(recursive: true);
    final box = await AesGcm.with256bits().encrypt(
      utf8.encode(
        jsonEncode({
          'version': 1,
          'scope': inner.toJson(),
          'record': QueueRecord(
            id: recordId,
            sequence: 1,
            text: 'planted $recordId',
          ).toJson(),
        }),
      ),
      secretKey: SecretKey(keys.values[account]!),
      aad: aad,
    );
    await File('${folder.path}/$fileId.rec').writeAsBytes(box.concatenation());
  }

  Future<void> plantValid() => plant(
    sealedFor: otherProfile,
    inner: otherProfile,
    fileId: id(1),
    recordId: id(1),
  );

  test(
    'a record sealed for one scope does not open under another scope',
    () async {
      await plantValid();
      await plant(
        sealedFor: scope,
        inner: otherProfile,
        fileId: id(2),
        recordId: id(2),
      );
      final loaded = await store().load(otherProfile);
      expect(loaded.records.map((record) => record.id), [id(1)]);
      expect(loaded.corruptRecords, 1);
    },
  );

  test(
    'a record whose scope binding differs from its directory is not loaded',
    () async {
      await plantValid();
      await plant(
        sealedFor: otherProfile,
        inner: scope,
        fileId: id(2),
        recordId: id(2),
      );
      final loaded = await store().load(otherProfile);
      expect(loaded.records.map((record) => record.id), [id(1)]);
      expect(loaded.corruptRecords, 1);
    },
  );

  test(
    'a record whose id does not match its file name is not loaded',
    () async {
      await plantValid();
      await plant(
        sealedFor: otherProfile,
        inner: otherProfile,
        fileId: id(2),
        recordId: id(3),
      );
      final loaded = await store().load(otherProfile);
      expect(loaded.records.map((record) => record.id), [id(1)]);
      expect(loaded.corruptRecords, 1);
    },
  );
}
