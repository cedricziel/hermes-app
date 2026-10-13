import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../auth/verified_session_owner.dart';

class WatchThreadId {
  const WatchThreadId(this.contextId, this.profile, this.sessionId);
  final String contextId;
  final String? profile;
  final String sessionId;

  String encode() =>
      'v2/${base64Url.encode(utf8.encode(jsonEncode([contextId, profile, sessionId]))).replaceAll('=', '')}';

  static WatchThreadId? decode(Object? value) {
    if (value is! String || !value.startsWith('v2/')) {
      return null;
    }
    try {
      final tuple = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(value.substring(3)))),
      );
      if (tuple is! List ||
          tuple.length != 3 ||
          tuple[0] is! String ||
          (tuple[0] as String).isEmpty ||
          (tuple[1] != null && tuple[1] is! String) ||
          tuple[2] is! String ||
          (tuple[2] as String).isEmpty) {
        return null;
      }
      return WatchThreadId(
        tuple[0] as String,
        tuple[1] as String?,
        tuple[2] as String,
      );
    } on Object {
      return null;
    }
  }
}

class WatchContext {
  const WatchContext(this.id, this.revision);
  final String id;
  final int revision;
  Map<String, Object> get fields => {'contextId': id, 'revision': revision};
}

class WatchContextStore {
  WatchContextStore({
    Future<String?> Function()? read,
    Future<void> Function(String)? write,
    String Function()? randomId,
  }) : _read = read ?? (() => _storage.read(key: _key)),
       _write = write ?? ((value) => _storage.write(key: _key, value: value)),
       _randomId = randomId ?? _random;
  static const _key = 'watch.context.v2';
  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    mOptions: MacOsOptions(usesDataProtectionKeychain: !kDebugMode),
  );
  final Future<String?> Function() _read;
  final Future<void> Function(String) _write;
  final String Function() _randomId;
  Future<void> _queue = Future.value();
  WatchContext? current;
  int revision = 0;
  int _generation = 0;
  bool _departurePending = false;

  Future<WatchContext?> resolve({
    required VerifiedSessionOwner? owner,
    required String? ungatedServer,
    required int revision,
    bool departed = false,
  }) {
    if (departed || (owner == null && ungatedServer == null)) {
      current = null;
      _generation++;
    }
    if (departed) _departurePending = true;
    final generation = _generation;
    final result = _queue.then((_) async {
      final ownerKey = owner == null
          ? (ungatedServer == null ? null : ['ungated', ungatedServer])
          : [
              'gated',
              owner.server,
              owner.user,
              owner.organization,
              owner.provider,
            ];
      Map<String, dynamic>? saved;
      final raw = await _read();
      try {
        if (raw != null) saved = jsonDecode(raw) as Map<String, dynamic>;
      } on Object {
        saved = null;
      }
      final durableRevision = max(revision, (saved?['revision'] as int?) ?? 0);
      if (generation != _generation) {
        return null;
      }
      if (departed || ownerKey == null) {
        this.revision = durableRevision + (departed ? 1 : 0);
        await _write(jsonEncode({'revision': this.revision}));
        if (generation != _generation) return null;
        _departurePending = false;
        current = null;
        return null;
      }
      final matches =
          !_departurePending &&
          jsonEncode(saved?['owner']) == jsonEncode(ownerKey);
      final id = matches && saved?['id'] is String
          ? saved!['id'] as String
          : _randomId();
      final next = matches
          ? durableRevision
          : max(durableRevision, ((saved?['revision'] as int?) ?? -1) + 1);
      await _write(jsonEncode({'owner': ownerKey, 'id': id, 'revision': next}));
      this.revision = next;
      if (generation != _generation) {
        return null;
      }
      _departurePending = false;
      return current = WatchContext(id, next);
    });
    final guarded = result.catchError((Object error, StackTrace stack) {
      if (generation == _generation) current = null;
      Error.throwWithStackTrace(error, stack);
    });
    _queue = guarded.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return guarded;
  }

  Future<void> synchronizeRevision(int next) {
    final result = _queue.then((_) async {
      if (next <= revision) return;
      final raw = await _read();
      final saved = raw == null
          ? <String, dynamic>{}
          : jsonDecode(raw) as Map<String, dynamic>;
      saved['revision'] = next;
      await _write(jsonEncode(saved));
      revision = next;
      final active = current;
      if (active != null) current = WatchContext(active.id, next);
    });
    _queue = result.catchError((Object _) {});
    return result;
  }

  static String _random() {
    final random = Random.secure();
    return base64Url
        .encode(List.generate(24, (_) => random.nextInt(256)))
        .replaceAll('=', '');
  }
}
