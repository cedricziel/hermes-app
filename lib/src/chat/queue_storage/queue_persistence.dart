import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../app_lock/app_lock_controller.dart';
import '../../auth/auth_controller.dart';
import '../../windows/conversation_windows.dart' show windowSessionOwnerKey;
import 'durable_queue_store.dart';
import 'queue_record.dart';

class QueuePersistence extends ChangeNotifier {
  QueuePersistence({
    required this.auth,
    required this.lock,
    Future<PromptQueueStore> Function()? factory,
  }) : _factory = factory ?? DurableQueueStore.open;
  final AuthController auth;
  final AppLockController lock;
  final Future<PromptQueueStore> Function() _factory;
  Future<PromptQueueStore>? _opened;
  StreamSubscription<void>? _signedOut;
  QueueScope? _identity;
  final _cleanup = <(QueueScope, bool)>[];
  var _cleaning = false;
  bool get visible => !lock.covered;
  bool get allowed =>
      visible &&
      auth.protectedRequestsAllowed &&
      auth.state == HermesConnectionState.ready &&
      windowSessionOwnerKey(auth) != null;
  Future<PromptQueueStore> open() async {
    try {
      return await (_opened ??= _factory());
    } on Object {
      _opened = null;
      rethrow;
    }
  }

  QueueScope? scopeFor(String conversationId, String? profile) {
    final server = auth.baseUrl;
    final owner = windowSessionOwnerKey(auth);
    if (!allowed ||
        server == null ||
        owner == null ||
        profile == null ||
        profile.trim().isEmpty) {
      return null;
    }
    return QueueScope(
      serverKey: server,
      accountKey: owner,
      profile: profile,
      conversationId: conversationId,
    );
  }

  void start() {
    auth.addListener(_changed);
    lock.addListener(_changed);
    _signedOut = auth.signedOut.listen((_) {
      if (auth.sessionExpired) {
        notifyListeners();
        return;
      }
      final identity = _identity;
      _identity = null;
      if (identity != null) {
        _cleanup.add((identity, auth.baseUrl == null));
        unawaited(_clean());
      }
      notifyListeners();
    });
    _changed();
  }

  void _changed() {
    final owner = windowSessionOwnerKey(auth);
    final server = auth.baseUrl;
    if (owner != null &&
        server != null &&
        auth.state == HermesConnectionState.ready) {
      _identity = QueueScope(
        serverKey: server,
        accountKey: owner,
        profile: null,
        conversationId: '',
      );
    }
    notifyListeners();
    if (_cleanup.isNotEmpty) unawaited(_clean());
  }

  Future<void> _clean() async {
    if (_cleaning) return;
    _cleaning = true;
    try {
      while (_cleanup.isNotEmpty) {
        final (identity, serverRemoved) = _cleanup.first;
        final store = await open();
        if (serverRemoved) {
          await store.deleteServer(identity.serverKey);
        } else {
          await store.deleteAccount(identity);
        }
        _cleanup.removeAt(0);
      }
    } on Object {
      // Storage tombstones and the next unlock retain cleanup responsibility.
    } finally {
      _cleaning = false;
    }
  }

  @override
  void dispose() {
    auth.removeListener(_changed);
    lock.removeListener(_changed);
    unawaited(_signedOut?.cancel());
    super.dispose();
  }
}
