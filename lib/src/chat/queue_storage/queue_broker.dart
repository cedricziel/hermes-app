import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'durable_queue_store.dart';
import 'queue_record.dart';

typedef QueueBrokerCall = Future<Map<String, Object?>> Function(
  String operation,
  Map<String, Object?> arguments,
);

abstract interface class QueueWindowLink {
  Future<Map<String, Object?>> queueOperation(
    String operation,
    Map<String, Object?> arguments,
  );
  Stream<bool> get queueVisibility;
}

class QueueOperationBroker {
  const QueueOperationBroker({
    required this.scope,
    required this.lease,
    required this.store,
    required this.valid,
  });
  final QueueScope scope;
  final String lease;
  final Future<PromptQueueStore> Function() store;
  final bool Function() valid;
  static const _unavailable = <String, Object?>{
    'ok': false,
    'reason': 'unavailable',
  };
  bool _matches(Object? value) =>
      value is Map &&
      value['server'] == scope.serverKey &&
      value['account'] == scope.accountKey &&
      value['profile'] == scope.profile &&
      value['conversation'] == scope.conversationId;
  Future<Map<String, Object?>> handle(
    String operation,
    Map<String, Object?> arguments,
  ) async {
    if (scope.profile == null ||
        scope.profile!.trim().isEmpty ||
        !valid() ||
        !_matches(arguments['scope']) ||
        operation != 'lease' && arguments['lease'] != lease) {
      return _unavailable;
    }
    if (operation == 'lease') return {'ok': true, 'lease': lease};
    PromptQueueStore? opened;
    QueueRecord? committed;
    var submissionMarked = false;
    try {
      opened = await store();
      if (!valid()) return _unavailable;
      final result = <String, Object?>{'ok': true};
      switch (operation) {
        case 'load':
          final loaded = await opened.load(scope);
          result['records'] = [
            for (final record in loaded.records) record.toJson(),
          ];
          result['corrupt'] = loaded.corruptRecords;
        case 'commit':
          final files = arguments['files'] as List? ?? const [];
          committed = await opened.commit(
            scope,
            arguments['text'] as String,
            displayText: arguments['display'] as String?,
            files: [
              for (final value in files)
                QueueAttachmentInput(
                  path: (value as Map)['path'] as String,
                  name: value['name'] as String,
                  mimeType: value['mime'] as String?,
                  isImage: value['image'] as bool,
                ),
            ],
          );
          result['record'] = committed.toJson();
        case 'begin':
          await opened.beginSubmission(
            scope,
            arguments['id'] as String,
            arguments['claim'] as String,
          );
          submissionMarked = true;
        case 'state':
          final state = QueueRecordState.values.byName(
            arguments['state'] as String,
          );
          await opened.setState(scope, arguments['id'] as String, state);
          submissionMarked = state == QueueRecordState.submissionStarted;
        case 'notSubmitted':
          await opened.restoreUnsentAfterPreSubmitFailure(
            scope,
            arguments['id'] as String,
            claim: arguments['claim'] as String?,
          );
        case 'attachment':
          result['bytes'] = Uint8List.fromList(
            await opened.readAttachment(
              scope,
              arguments['id'] as String,
              arguments['blob'] as String,
            ),
          );
        case 'discard':
          await opened.discard(scope, arguments['id'] as String);
        case 'deleteConversation':
          await opened.deleteConversation(scope);
        default:
          return _unavailable;
      }
      if (!valid()) {
        if (committed != null) await opened.discard(scope, committed.id);
        if (submissionMarked) {
          await opened.restoreUnsentAfterPreSubmitFailure(
            scope,
            arguments['id'] as String,
            claim: arguments['claim'] as String?,
          );
        }
        return _unavailable;
      }
      return result;
    } on Object {
      // IPC failures must never expose payloads, filesystem paths or key errors.
      return _unavailable;
    }
  }
}

class BrokerQueueStore extends ChangeNotifier implements PromptQueueStore {
  BrokerQueueStore(this.call, {Stream<bool>? visibility}) {
    _visibility = visibility?.listen((value) {
      visible = value;
      _epoch++;
      _leases.clear();
      notifyListeners();
    });
  }
  StreamSubscription<bool>? _visibility;
  var _epoch = 0;
  bool visible = true;
  @override
  void dispose() {
    visible = false;
    _epoch++;
    unawaited(_visibility?.cancel());
    super.dispose();
  }

  final QueueBrokerCall call;
  final _leases = <String, String>{};
  Future<Map<String, Object?>> _request(
    String operation,
    QueueScope scope, [
    Map<String, Object?> arguments = const {},
  ]) async {
    if (!visible) throw const QueueStorageException('unavailable');
    final epoch = _epoch;
    final key = jsonEncode(scope.toJson());
    var lease = _leases[key];
    if (lease == null) {
      final authorized = await call('lease', {'scope': scope.toJson()});
      if (epoch != _epoch ||
          !visible ||
          authorized['ok'] != true ||
          authorized['lease'] is! String) {
        throw const QueueStorageException('unavailable');
      }
      lease = authorized['lease'] as String;
      _leases[key] = lease;
    }
    final response = await call(operation, {
      'scope': scope.toJson(),
      'lease': lease,
      ...arguments,
    });
    if (epoch != _epoch || !visible || response['ok'] != true) {
      throw const QueueStorageException('unavailable');
    }
    return response;
  }

  @override
  Future<QueueLoad> load(QueueScope scope) async {
    final response = await _request('load', scope);
    return QueueLoad(
      List.unmodifiable([
        for (final value in response['records'] as List)
          QueueRecord.fromJson(Map<String, dynamic>.from(value as Map)),
      ]),
      corruptRecords: response['corrupt'] as int,
    );
  }

  @override
  Future<QueueRecord> commit(
    QueueScope scope,
    String text, {
    String? displayText,
    List<QueueAttachmentInput> files = const [],
  }) async {
    final response = await _request('commit', scope, {
      'text': text,
      'display': displayText,
      'files': [
        for (final file in files)
          {
            'path': file.path,
            'name': file.name,
            'mime': file.mimeType,
            'image': file.isImage,
          },
      ],
    });
    return QueueRecord.fromJson(
      Map<String, dynamic>.from(response['record'] as Map),
    );
  }

  @override
  Future<void> setState(
    QueueScope scope,
    String id,
    QueueRecordState state,
  ) async {
    await _request('state', scope, {'id': id, 'state': state.name});
  }

  @override
  Future<void> beginSubmission(
    QueueScope scope,
    String id,
    String claim,
  ) async {
    await _request('begin', scope, {'id': id, 'claim': claim});
  }

  @override
  Future<void> restoreUnsentAfterPreSubmitFailure(
    QueueScope scope,
    String id, {
    String? claim,
  }) async {
    await _request('notSubmitted', scope, {'id': id, 'claim': claim});
  }

  @override
  Future<List<int>> readAttachment(
    QueueScope scope,
    String id,
    String blobId,
  ) async =>
      (await _request('attachment', scope, {'id': id, 'blob': blobId}))['bytes']
          as Uint8List;
  @override
  Future<void> discard(QueueScope scope, String id) async {
    await _request('discard', scope, {'id': id});
  }

  @override
  Future<void> deleteConversation(QueueScope scope) async {
    await _request('deleteConversation', scope);
  }

  @override
  Future<void> deleteAccount(QueueScope scope) async =>
      throw UnsupportedError('Only the main engine clears queue accounts');
  @override
  Future<void> deleteServer(String serverKey) async =>
      throw UnsupportedError('Only the main engine clears queue servers');
}
