import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_otel/flutter_otel.dart';

import '../chat_transport.dart' show kMaxAttachmentBytes;
import 'queue_directory.dart';
import 'queue_keys.dart';
import 'queue_record.dart';

class QueueStorageException implements Exception {
  const QueueStorageException(this.reason);
  final String reason;
  @override
  String toString() => 'QueueStorageException($reason)';
}

abstract interface class PromptQueueStore {
  Future<QueueLoad> load(QueueScope scope);
  Future<QueueRecord> commit(
    QueueScope scope,
    String text, {
    String? displayText,
    List<QueueAttachmentInput> files = const [],
  });
  Future<void> setState(QueueScope scope, String id, QueueRecordState state);
  Future<void> beginSubmission(QueueScope scope, String id, String claim);
  Future<void> restoreUnsentAfterPreSubmitFailure(
    QueueScope scope,
    String id, {
    String? claim,
  });
  Future<List<int>> readAttachment(QueueScope scope, String id, String blobId);
  Future<void> discard(QueueScope scope, String id);
  Future<void> deleteConversation(QueueScope scope);
  Future<void> deleteAccount(QueueScope scope);
  Future<void> deleteServer(String serverKey);
}

/// Writes belong to the main Flutter engine; other engines use its broker.
/// Local serialization does not coordinate separate isolates.
class DurableQueueStore implements PromptQueueStore {
  DurableQueueStore({
    required this.directory,
    required this.keys,
    this.tracer,
    this.events = noopAppEventLogger,
    this.beforeCommit,
  });
  final Directory directory;
  final QueueKeys keys;
  final Tracer? tracer;
  final AppEventLogger events;
  final Future<void> Function(String operation)? beforeCommit;
  final _cipher = AesGcm.with256bits();
  static final _locks = <String, Future<void>>{};
  static final _safeName = RegExp(r'^[a-f0-9]{32}$');
  static final _safeBlobName = RegExp(r'^[a-f0-9]{32}-[a-f0-9]{32}\.blob$');

  static Future<DurableQueueStore> open({
    QueueKeys? keys,
    Tracer? tracer,
    AppEventLogger events = noopAppEventLogger,
  }) async => DurableQueueStore(
    directory: await queueDirectory(),
    keys: keys ?? SecureQueueKeys(),
    tracer: tracer,
    events: events,
  );

  String _hash(String value) => sha256.convert(utf8.encode(value)).toString();
  String _server(QueueScope scope) => _hash(scope.serverKey);
  String _account(QueueScope scope) =>
      _hash('${scope.serverKey}\u0000${scope.accountKey}');
  String _scope(QueueScope scope) => _hash(jsonEncode(scope.toJson()));
  Directory _accountDir(QueueScope scope) =>
      Directory('${directory.path}/${_server(scope)}/${_account(scope)}');
  Directory _folder(QueueScope scope) =>
      Directory('${_accountDir(scope).path}/${_scope(scope)}');
  String _id() => List.generate(
    16,
    (_) => Random.secure().nextInt(256),
  ).map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  File _file(QueueScope scope, String name) =>
      File('${_folder(scope).path}/$name');
  String _recordName(String id) {
    if (!_safeName.hasMatch(id)) {
      throw const QueueStorageException('invalid_record');
    }
    return '$id.rec';
  }

  List<int> _aad(QueueScope scope, String name) => utf8.encode(
    'queue.v1/${_server(scope)}/${_account(scope)}/${_scope(scope)}/$name',
  );

  Future<T> _run<T>(String operation, Future<T> Function() body) {
    final previous = _locks[directory.absolute.path] ?? Future.value();
    final result = previous.then((_) async {
      Span? span;
      try {
        span = tracer?.startSpan(
          'chat.queue.storage',
          attributes: {'operation': operation},
        );
      } on Object {
        // Optional telemetry must never affect persistence.
      }
      RandomAccessFile? lock;
      try {
        await directory.create(recursive: true);
        lock = await File('${directory.path}/.lock')
            .open(mode: FileMode.append);
        await lock.lock(FileLock.blockingExclusive);
        await _retryCleanup();
        final value = await body();
        try {
          span?.setAttributes({
            'outcome': 'completed',
            'entries': value is QueueLoad
                ? value.records.length
                : value is QueueRecord
                ? 1
                : 0,
            'bytes': value is List<int>
                ? value.length
                : value is QueueRecord
                ? value.attachments.fold<int>(
                    0,
                    (count, file) => count + file.size,
                  )
                : 0,
          });
        } on Object {
          // Optional telemetry must never affect persistence.
        }
        return value;
      } on Object catch (error) {
        _failure(operation, error);
        try {
          span?.setAttribute('outcome', 'failed');
        } on Object {
          // Optional telemetry must never affect persistence.
        }
        rethrow;
      } finally {
        if (lock != null) {
          await lock.unlock();
          await lock.close();
        }
        try {
          span?.end();
        } on Object {
          // Optional telemetry must never affect persistence.
        }
      }
    });
    _locks[directory.absolute.path] = result.then<void>(
      (_) {},
      onError: (Object _) {},
    );
    return result;
  }

  void _failure(String operation, Object error, {String? reason}) {
    try {
      events('chat.queue.storage_failed', {
        'operation': operation,
        'reason':
            reason ??
            (error is QueueStorageException ? error.reason : 'unavailable'),
        'error.type': error.runtimeType.toString(),
      });
    } on Object {
      // Optional telemetry must never affect persistence.
    }
  }

  Future<SecretKey> _key(QueueScope scope, {bool create = false}) async {
    if (await File('${directory.path}/${_server(scope)}.delete').exists() ||
        await File('${_accountDir(scope).path}.delete').exists() ||
        await File('${_folder(scope).path}.delete').exists()) {
      throw const QueueStorageException('cleanup_pending');
    }
    final raw = await keys.read(_account(scope));
    if (raw != null) {
      if (raw.length != 32) {
        throw const QueueStorageException('invalid_key');
      }
      return SecretKey(raw);
    }
    final account = _accountDir(scope);
    final hasPayload =
        await account.exists() &&
        await account
            .list(recursive: true, followLinks: false)
            .any(
              (entry) =>
                  entry is File &&
                  (entry.path.endsWith('.rec') || entry.path.endsWith('.blob')),
            );
    if (!create || hasPayload) {
      throw const QueueStorageException('key_unavailable');
    }
    final key = await _cipher.newSecretKey();
    await keys.write(_account(scope), await key.extractBytes());
    return key;
  }

  Future<void> _atomic(File file, List<int> bytes, String operation) async {
    final temp = File('${file.path}.${_id()}.tmp');
    try {
      await temp.writeAsBytes(bytes, flush: true);
      await beforeCommit?.call(operation);
      await temp.rename(file.path);
    } finally {
      if (await temp.exists()) await temp.delete();
    }
  }

  Future<void> _seal(
    QueueScope scope,
    String name,
    List<int> bytes,
    SecretKey key,
    String operation,
  ) async {
    final box = await _cipher.encrypt(
      bytes,
      secretKey: key,
      aad: _aad(scope, name),
    );
    await _atomic(_file(scope, name), box.concatenation(), operation);
  }

  Future<List<int>> _unseal(
    QueueScope scope,
    String name,
    SecretKey key,
  ) async => _cipher.decrypt(
    SecretBox.fromConcatenation(
      await _file(scope, name).readAsBytes(),
      nonceLength: 12,
      macLength: 16,
    ),
    secretKey: key,
    aad: _aad(scope, name),
  );
  Future<void> _save(
    QueueScope scope,
    QueueRecord record,
    SecretKey key,
    String operation,
  ) => _seal(
    scope,
    _recordName(record.id),
    utf8.encode(
      jsonEncode({
        'version': 1,
        'scope': scope.toJson(),
        'record': record.toJson(),
      }),
    ),
    key,
    operation,
  );

  Future<QueueLoad> _load(QueueScope scope) async {
    final folder = _folder(scope);
    if (!await folder.exists()) return const QueueLoad([]);
    final key = await _key(scope);
    final records = <QueueRecord>[];
    var corrupt = 0;
    final recordIds = <String>{};
    final entries = await folder.list(followLinks: false).toList();
    for (final entry in entries.whereType<File>().where(
      (entry) => entry.path.endsWith('.rec'),
    )) {
      final name = entry.uri.pathSegments.last;
      recordIds.add(name.substring(0, name.length - 4));
      try {
        final value = jsonDecode(
          utf8.decode(await _unseal(scope, name, key)),
        ) as Map<String, dynamic>;
        if (value['version'] != 1 ||
            jsonEncode(value['scope']) != jsonEncode(scope.toJson())) {
          throw const FormatException();
        }
        final record = QueueRecord.fromJson(
          value['record'] as Map<String, dynamic>,
        );
        if (_recordName(record.id) != name) throw const FormatException();
        if (record.state == QueueRecordState.accepted) {
          await _remove(scope, record);
        } else {
          records.add(record);
        }
      } on Object catch (error) {
        corrupt++;
        _failure('load', error, reason: 'corrupt_record');
      }
    }
    records.sort((a, b) => a.sequence.compareTo(b.sequence));
    for (final entry in entries.whereType<File>()) {
      final name = entry.uri.pathSegments.last;
      if (name.endsWith('.tmp') ||
          name.endsWith('.blob') &&
              !recordIds.contains(name.split('-').first)) {
        await entry.delete();
      }
    }
    try {
      await _atomic(
        _file(scope, 'index.json'),
        utf8.encode(
          jsonEncode({
            'version': 1,
            'records': records.map((record) => record.id).toList(),
          }),
        ),
        'index',
      );
    } on Object catch (error) {
      _failure('index', error);
    }
    return QueueLoad(List.unmodifiable(records), corruptRecords: corrupt);
  }

  @override
  Future<QueueLoad> load(QueueScope scope) => _run('load', () => _load(scope));

  @override
  Future<QueueRecord> commit(
    QueueScope scope,
    String text, {
    String? displayText,
    List<QueueAttachmentInput> files = const [],
  }) => _run('commit', () async {
    final folder = _folder(scope);
    final key = await _key(scope, create: true);
    final loaded = await _load(scope);
    await folder.create(recursive: true);
    final id = _id();
    final attachments = <QueueAttachment>[];
    try {
      for (final file in files) {
        final source = File(file.path);
        if (await source.length() > kMaxAttachmentBytes) {
          throw const QueueStorageException('attachment_too_large');
        }
        final bytes = await source.readAsBytes();
        if (bytes.length > kMaxAttachmentBytes) {
          throw const QueueStorageException('attachment_too_large');
        }
        final blobId = '$id-${_id()}.blob';
        await _seal(scope, blobId, bytes, key, 'attachment');
        attachments.add(
          QueueAttachment(
            blobId: blobId,
            name: file.name,
            size: bytes.length,
            mimeType: file.mimeType,
            isImage: file.isImage,
          ),
        );
      }
      final record = QueueRecord(
        id: id,
        sequence: loaded.records.isEmpty ? 0 : loaded.records.last.sequence + 1,
        text: text,
        displayText: displayText,
        attachments: List.unmodifiable(attachments),
      );
      await _save(scope, record, key, 'record');
      try {
        await _atomic(
          _file(scope, 'index.json'),
          utf8.encode(
            jsonEncode({
              'version': 1,
              'records': [
                ...loaded.records.map((entry) => entry.id),
                record.id,
              ],
            }),
          ),
          'index',
        );
      } on Object catch (error) {
        _failure('index', error);
      }
      return record;
    } on Object {
      if (!await _file(scope, _recordName(id)).exists()) {
        for (final file in attachments) {
          if (await _file(scope, file.blobId).exists()) {
            await _file(scope, file.blobId).delete();
          }
        }
      }
      rethrow;
    }
  });

  @override
  Future<void> setState(QueueScope scope, String id, QueueRecordState state) =>
      _run('state', () async {
        final loaded = await _load(scope);
        final record = loaded.records
            .where((record) => record.id == id)
            .firstOrNull;
        if (record == null) throw const QueueStorageException('record_missing');
        if (record.state == QueueRecordState.submissionStarted &&
            state == QueueRecordState.queued) {
          throw const QueueStorageException('invalid_transition');
        }
        final key = await _key(scope);
        await _save(scope, record.withState(state), key, 'state');
        if (state == QueueRecordState.accepted) await _remove(scope, record);
      });

  @override
  Future<void> beginSubmission(QueueScope scope, String id, String claim) =>
      _run('begin_submission', () async {
        if (!_safeName.hasMatch(claim)) {
          throw const QueueStorageException('invalid_claim');
        }
        final record = (await _load(scope)).records
            .where((record) => record.id == id)
            .firstOrNull;
        if (record == null) throw const QueueStorageException('record_missing');
        final digest = _hash(claim);
        if (record.state == QueueRecordState.submissionStarted) {
          if (record.submissionClaimHash == digest) return;
          throw const QueueStorageException('submission_claimed');
        }
        await _save(
          scope,
          record.withState(
            QueueRecordState.submissionStarted,
            claimHash: digest,
          ),
          await _key(scope),
          'state',
        );
      });

  @override
  Future<void> restoreUnsentAfterPreSubmitFailure(
    QueueScope scope,
    String id, {
    String? claim,
  }) => _run('not_submitted', () async {
    final record = (await _load(scope)).records
        .where((record) => record.id == id)
        .firstOrNull;
    if (record == null) throw const QueueStorageException('record_missing');
    if (record.state == QueueRecordState.submissionStarted &&
        (claim == null ||
            record.submissionClaimHash == null ||
            record.submissionClaimHash != _hash(claim))) {
      throw const QueueStorageException('submission_claimed');
    }
    await _save(
      scope,
      record.withState(QueueRecordState.queued),
      await _key(scope),
      'state',
    );
  });

  @override
  Future<List<int>> readAttachment(
    QueueScope scope,
    String id,
    String blobId,
  ) => _run('attachment', () async {
    final loaded = await _load(scope);
    final record = loaded.records
        .where((record) => record.id == id)
        .firstOrNull;
    final attachment = record?.attachments
        .where((file) => file.blobId == blobId)
        .firstOrNull;
    if (attachment == null) {
      throw const QueueStorageException('attachment_missing');
    }
    final bytes = await _unseal(scope, blobId, await _key(scope));
    if (bytes.length != attachment.size) {
      throw const QueueStorageException('attachment_corrupt');
    }
    return bytes;
  });

  Future<void> _remove(QueueScope scope, QueueRecord record) async {
    for (final attachment in record.attachments) {
      final blob = _file(scope, attachment.blobId);
      if (await blob.exists()) await blob.delete();
    }
    final file = _file(scope, _recordName(record.id));
    if (await file.exists()) await file.delete();
  }

  @override
  Future<void> discard(QueueScope scope, String id) =>
      _run('discard', () async {
        final recordName = _recordName(id);
        final folder = _folder(scope);
        if (!await folder.exists()) return;
        for (final entry in await folder.list(followLinks: false).toList()) {
          if (entry is! File) continue;
          final name = entry.uri.pathSegments.last;
          if (name.startsWith('$id-') && _safeBlobName.hasMatch(name)) {
            await entry.delete();
          }
        }
        final record = _file(scope, recordName);
        if (await record.exists()) await record.delete();
      });

  @override
  Future<void> deleteConversation(QueueScope scope) =>
      _run('delete', () => _delete(_folder(scope)));
  @override
  Future<void> deleteAccount(QueueScope scope) => _run(
    'delete',
    () => _delete(_accountDir(scope), account: _account(scope)),
  );
  @override
  Future<void> deleteServer(String serverKey) => _run(
    'delete',
    () => _delete(
      Directory('${directory.path}/${_hash(serverKey)}'),
      server: true,
    ),
  );
  Future<void> _delete(
    Directory target, {
    String? account,
    bool server = false,
  }) async {
    final tombstone = File('${target.path}.delete');
    await tombstone.parent.create(recursive: true);
    await tombstone.writeAsString(
      jsonEncode({'account': account, 'server': server}),
      flush: true,
    );
    if (server && await target.exists()) {
      for (final entry in await target.list(followLinks: false).toList()) {
        if (entry is Directory) {
          await keys.delete(
            entry.uri.pathSegments.where((s) => s.isNotEmpty).last,
          );
        }
      }
    } else if (account != null) {
      await keys.delete(account);
    }
    if (await target.exists()) await target.delete(recursive: true);
    await tombstone.delete();
  }

  Future<void> _retryCleanup() async {
    final tombstones = await directory
        .list(recursive: true, followLinks: false)
        .where((entry) => entry is File && entry.path.endsWith('.delete'))
        .toList();
    for (final tombstone in tombstones) {
      if (!await tombstone.exists()) continue;
      try {
        final value = jsonDecode(
          await File(tombstone.path).readAsString(),
        ) as Map<String, dynamic>;
        await _delete(
          Directory(tombstone.path.substring(0, tombstone.path.length - 7)),
          account: value['account'] as String?,
          server: value['server'] == true,
        );
      } on Object catch (error) {
        _failure('cleanup', error);
      }
    }
  }
}
