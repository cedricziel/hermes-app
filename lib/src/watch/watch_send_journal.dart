import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_otel/flutter_otel.dart'
    show AppEventLogger, noopAppEventLogger;

import 'watch_context.dart';

/// Protected, device-only storage whose single-key replacement is atomic.
abstract interface class WatchJournalStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Keychain items remain available to background watch relays after first unlock.
class ProtectedWatchJournalStore implements WatchJournalStore {
  const ProtectedWatchJournalStore();
  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      synchronizable: false,
    ),
  );
  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class WatchJournalException implements Exception {
  const WatchJournalException(this.code);
  final String code;
}

class WatchSendIdentity {
  WatchSendIdentity(
    this.sendId,
    this.createdAt,
    this.profile,
    this.target,
    String text,
  ) : fingerprint = sha256
          .convert(utf8.encode(jsonEncode([createdAt, profile, target, text])))
          .toString();
  final String sendId;
  final int createdAt;
  final String? profile;
  final String? target;
  final String fingerprint;
}

class WatchSendRecord {
  WatchSendRecord(this.data);
  final Map<String, dynamic> data;
  String get state => data['state'] as String;
  String? get boundThread => data['boundThread'] as String?;
  Map<String, Object?>? get result =>
      (data['result'] as Map?)?.cast<String, Object?>();
}

class WatchSendJournal {
  WatchSendJournal({
    WatchJournalStore? store,
    DateTime Function()? now,
    this.events = noopAppEventLogger,
  }) : _store = store ?? const ProtectedWatchJournalStore(),
       _now = now ?? DateTime.now;
  final WatchJournalStore _store;
  final AppEventLogger events;
  final DateTime Function() _now;
  Future<void> _queue = Future.value();
  final _invalid = <String>{};
  final _active = <String>{};
  static const validity = Duration(minutes: 10);
  static const retention = Duration(days: 7);

  String _key(WatchContext context) =>
      'watch.send.v1.${context.id}.${context.revision}';
  String _live(WatchContext context, String id) => '${_key(context)}/$id';
  void _event(String operation, String outcome) {
    try {
      events('watch.send.journal', {
        'operation': operation,
        'outcome': outcome,
      });
    } on Object {
      return;
    }
  }

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  void _checkCurrent(WatchContext context) {
    if (_invalid.contains(_key(context))) {
      throw const WatchJournalException('context_changed');
    }
  }

  Future<T> _scoped<T>(WatchContext context, Future<T> Function() action) =>
      _serial(() async {
        _checkCurrent(context);
        final result = await action();
        _checkCurrent(context);
        return result;
      });

  Future<Map<String, dynamic>> _read(WatchContext context) async {
    final key = _key(context);
    if (_invalid.contains(key)) {
      throw const WatchJournalException('context_changed');
    }
    final String? raw;
    try {
      final invalid = await _store.read('$key.invalid');
      _checkCurrent(context);
      if (invalid != null) {
        throw const WatchJournalException('context_changed');
      }
      raw = await _store.read(key);
      _checkCurrent(context);
      _event('read', 'success');
    } on WatchJournalException {
      rethrow;
    } on Object {
      _event('read', 'unavailable');
      rethrow;
    }
    if (raw == null) {
      return {
        'version': 1,
        'records': <String, dynamic>{},
        'tombstones': <String, dynamic>{},
      };
    }
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['version'] is! int ||
          data['version'] != 1 ||
          data['records'] is! Map ||
          data['tombstones'] is! Map) {
        throw const FormatException();
      }
      for (final entry in _records(data).entries) {
        final record = entry.value;
        if (record['createdAt'] is! int ||
            record['updatedAt'] is! int ||
            record['fingerprint'] is! String ||
            !RegExp(r'^[a-f0-9]{64}$')
                .hasMatch(record['fingerprint'] as String) ||
            (record['profile'] != null && record['profile'] is! String) ||
            (record['target'] != null && record['target'] is! String) ||
            (record['boundThread'] != null &&
                record['boundThread'] is! String) ||
            (record['userRowId'] != null && record['userRowId'] is! int) ||
            !['not_sent', 'uncertain', 'completed'].contains(record['state']) ||
            (record['result'] != null && record['result'] is! Map)) {
          throw const FormatException();
        }
        final result = (record['result'] as Map?)?.cast<String, Object?>();
        if (record['state'] == 'completed' &&
            (result == null ||
                result['ok'] != true ||
                result['text'] is! String ||
                (result['failed'] != null && result['failed'] is! bool) ||
                (result['tools'] != null &&
                    (result['tools'] is! List ||
                        (result['tools'] as List).any(
                          (tool) => tool is! String,
                        ))) ||
                (result['threadId'] != null && result['threadId'] is! String) ||
                result.containsKey('serverUrl'))) {
          throw const FormatException();
        }
      }
      for (final value in _tombstones(data).values) {
        if (value['expiresAt'] is! int || value['fingerprint'] is! String) {
          throw const FormatException();
        }
      }
      return data;
    } on Object {
      _event('read', 'corrupt');
      throw const WatchJournalException('unavailable');
    }
  }

  Map<String, Map<String, dynamic>> _records(Map<String, dynamic> data) =>
      (data['records'] as Map).cast<String, Map<String, dynamic>>();
  Map<String, Map<String, dynamic>> _tombstones(Map<String, dynamic> data) =>
      (data['tombstones'] as Map).cast<String, Map<String, dynamic>>();

  Future<void> _write(WatchContext context, Map<String, dynamic> data) async {
    if (_invalid.contains(_key(context))) {
      throw const WatchJournalException('context_changed');
    }
    try {
      await _store.write(_key(context), jsonEncode(data));
      _checkCurrent(context);
      _event('write', 'success');
    } on Object {
      _event('write', 'unavailable');
      rethrow;
    }
  }

  void _prune(WatchContext context, Map<String, dynamic> data) {
    final now = _now().millisecondsSinceEpoch;
    final records = _records(data);
    final tombstones = _tombstones(data);
    tombstones.removeWhere((_, value) => (value['expiresAt'] as int) < now);
    // Detached retention uses the last durable dispatch or evidence timestamp.
    final expired = records.entries
        .where(
          (entry) =>
              !_active.contains(_live(context, entry.key)) &&
              now - (entry.value['updatedAt'] as int) >=
                  retention.inMilliseconds,
        )
        .map((entry) => entry.key)
        .toList();
    for (final id in expired) {
      _remove(data, id);
    }
  }

  void _remove(Map<String, dynamic> data, String id) {
    final records = _records(data);
    final record = records[id];
    if (record == null) return;
    final expiresAt = (record['createdAt'] as int) + validity.inMilliseconds;
    if (expiresAt >= _now().millisecondsSinceEpoch) {
      final tombstones = _tombstones(data);
      if (!tombstones.containsKey(id) && tombstones.length >= 1000) {
        throw const WatchJournalException('capacity');
      }
      tombstones[id] = {
        'expiresAt': expiresAt,
        'fingerprint': record['fingerprint'],
      };
    }
    records.remove(id);
  }

  /// Probes protected persistence before advertising durable recovery support.
  Future<bool> available(WatchContext context) => _scoped(context, () async {
    try {
      final data = await _read(context);
      await _write(context, data);
      return true;
    } on Object {
      return false;
    }
  }).catchError((Object _) => false);

  Future<WatchSendRecord?> lookup(WatchContext context, String id) =>
      _scoped(context, () async {
        final data = await _read(context);
        _prune(context, data);
        await _write(context, data);
        final record = _records(data)[id];
        return record == null ? null : WatchSendRecord(Map.of(record));
      });

  /// Reserves an identity; only a null return authorizes the first dispatch.
  Future<WatchSendRecord?> reserve(
    WatchContext context,
    WatchSendIdentity identity,
  ) => _scoped(context, () async {
    final data = await _read(context);
    _prune(context, data);
    final records = _records(data);
    final existing = records[identity.sendId];
    if (existing != null) {
      if (existing['fingerprint'] != identity.fingerprint) {
        throw const WatchJournalException('bad_request');
      }
      return WatchSendRecord(Map.of(existing));
    }
    final tombstone = _tombstones(data)[identity.sendId];
    if (tombstone != null) {
      if (tombstone['fingerprint'] != identity.fingerprint) {
        throw const WatchJournalException('bad_request');
      }
      return WatchSendRecord({'state': 'uncertain'});
    }
    final age = _now().millisecondsSinceEpoch - identity.createdAt;
    if (age > validity.inMilliseconds || age < -60000) {
      throw const WatchJournalException('expired');
    }
    if (records.length >= 100) {
      final terminal =
          records.entries
              .where(
                (entry) =>
                    entry.value['state'] == 'completed' &&
                    !_active.contains(_live(context, entry.key)),
              )
              .toList()
            ..sort(
              (a, b) => (a.value['updatedAt'] as int).compareTo(
                b.value['updatedAt'] as int,
              ),
            );
      if (terminal.isEmpty) throw const WatchJournalException('capacity');
      _remove(data, terminal.first.key);
    }
    if (_tombstones(data).length >= 1000) {
      throw const WatchJournalException('capacity');
    }
    records[identity.sendId] = {
      'createdAt': identity.createdAt,
      'updatedAt': _now().millisecondsSinceEpoch,
      'profile': identity.profile,
      'target': identity.target,
      'fingerprint': identity.fingerprint,
      'state': 'not_sent',
    };
    await _write(context, data);
    return null;
  });

  Future<void> _update(
    WatchContext context,
    String id,
    Map<String, Object?> fields,
  ) => _scoped(context, () async {
    final data = await _read(context);
    final record = _records(data)[id];
    if (record == null) throw const WatchJournalException('unavailable');
    record.addAll(<String, dynamic>{
      ...fields,
      'updatedAt': _now().millisecondsSinceEpoch,
    });
    await _write(context, data);
  });

  Future<void> markDispatched(WatchContext context, String id) async {
    await _update(context, id, {'state': 'uncertain'});
    _checkCurrent(context);
    _active.add(_live(context, id));
  }

  Future<void> evidence(
    WatchContext context,
    String id, {
    String? boundThread,
    int? userRowId,
  }) => _update(context, id, {
    'boundThread': ?boundThread,
    'userRowId': ?userRowId,
  });
  Future<void> complete(
    WatchContext context,
    String id,
    Map<String, Object?> result,
  ) async {
    await _update(context, id, {
      'state': 'completed',
      'result': Map<String, Object?>.of(result)..remove('serverUrl'),
    });
    _checkCurrent(context);
    detach(context, id);
  }

  void detach(WatchContext context, String id) =>
      _active.remove(_live(context, id));
  Future<void> forget(WatchContext context, String id) =>
      _scoped(context, () async {
        final data = await _read(context);
        _prune(context, data);
        if (!_active.contains(_live(context, id))) _remove(data, id);
        await _write(context, data);
      });

  /// Invalidates synchronously so queued callbacks cannot restore private results.
  Future<void> invalidate(WatchContext context) {
    final key = _key(context);
    _invalid.add(key);
    _active.removeWhere((id) => id.startsWith('$key/'));
    return _serial(() async {
      try {
        await _store.write('$key.invalid', '1');
        await _store.delete(key);
        _event('purge', 'success');
      } on Object {
        _event('purge', 'unavailable');
        rethrow;
      }
    });
  }
}
