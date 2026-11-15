import 'dart:async';

import '../chat/chat_transport.dart';

/// Reads the live chat statuses for the watch's list over one gateway
/// connection that later reads reuse, instead of a socket per refresh.
///
/// The transport reconnects by itself when its socket dropped, so a dropped
/// connection is replaced by the next read. [close] ends it for good: the
/// handler calls it when the session or owner changes and on sign-out, and an
/// idle timer calls it after [idleTimeout] without a read. A read that runs
/// past its budget closes the transport it used, unless a newer one has
/// replaced it. Only reads go through here; a send keeps its own transport and
/// is never resent.
class WatchStatusSource {
  WatchStatusSource(
    this._create, {
    this.idleTimeout = const Duration(seconds: 60),
  });

  final ChatTransport? Function() _create;
  final Duration idleTimeout;
  _Held? _held;
  Timer? _idle;

  /// The statuses by chat id, or null when nobody is signed in. A failed read
  /// is an empty answer, as [ChatTransport.activeStatuses] gives it. Past
  /// [budget] it throws a [TimeoutException] and closes the connection it used.
  Future<Map<String, String>?> activeStatuses({
    String? profile,
    Duration? budget,
  }) async {
    _idle?.cancel();
    var held = _held;
    if (held == null) {
      final transport = _create();
      if (transport == null) return null;
      held = _held = _Held(transport);
    }
    final used = held;
    used.reading++;
    try {
      var read = used.transport.activeStatuses(profile: profile);
      if (budget != null) read = read.timeout(budget);
      return await read;
    } on TimeoutException {
      // The socket may be dead or half open.
      unawaited(_release(used));
      rethrow;
    } finally {
      used.reading--;
      if (identical(_held, used) && used.reading == 0) {
        _idle = Timer(idleTimeout, close);
      }
    }
  }

  /// Closes the connection; the next read opens a new one.
  Future<void> close() async {
    _idle?.cancel();
    _idle = null;
    final held = _held;
    if (held != null) await _release(held);
  }

  Future<void> _release(_Held held) async {
    if (identical(_held, held)) _held = null;
    try {
      await held.transport.close();
    } on Object {
      // Cleanup of an optional read has nothing to report.
    }
  }
}

class _Held {
  _Held(this.transport);

  final ChatTransport transport;
  int reading = 0;
}
