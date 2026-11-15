import 'dart:async';

import '../chat/chat_transport.dart';

/// Reads the live chat statuses for the watch's list over one gateway
/// connection that later reads reuse, instead of a socket per refresh.
///
/// The transport reconnects by itself when its socket dropped, so a dropped
/// connection is replaced by the next read. [close] ends it for good: the
/// handler calls it when the session or owner changes and on sign-out, and an
/// idle timer calls it after [idleTimeout] without a read. Only reads go
/// through here; a send keeps its own transport and is never resent.
class WatchStatusSource {
  WatchStatusSource(
    this._create, {
    this.idleTimeout = const Duration(seconds: 60),
  });

  final ChatTransport? Function() _create;
  final Duration idleTimeout;
  ChatTransport? _transport;
  Timer? _idle;
  int _reading = 0;

  /// The statuses by chat id, or null when nobody is signed in. A failed read
  /// is an empty answer, as [ChatTransport.activeStatuses] gives it.
  Future<Map<String, String>?> activeStatuses({String? profile}) async {
    _idle?.cancel();
    final transport = _transport ??= _create();
    if (transport == null) return null;
    _reading++;
    try {
      return await transport.activeStatuses(profile: profile);
    } finally {
      _reading--;
      if (_reading == 0 && identical(_transport, transport)) {
        _idle = Timer(idleTimeout, close);
      }
    }
  }

  /// Closes the connection; the next read opens a new one.
  Future<void> close() async {
    _idle?.cancel();
    _idle = null;
    final transport = _transport;
    _transport = null;
    if (transport == null) return;
    try {
      await transport.close();
    } on Object {
      // Cleanup of an optional read has nothing to report.
    }
  }
}
