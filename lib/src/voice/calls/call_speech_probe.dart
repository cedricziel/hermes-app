import 'dart:async';

import 'package:stream_channel/stream_channel.dart';

import '../../chat/gateway/gateway_connection.dart';

/// Checks the authenticated upgrade only. No text, synthesized speech or user
/// audio is sent. A connection that arrives after timeout/cancellation is closed.
Future<void> probeCallSpeech(
  MixedSocketConnect connect,
  String? profile, {
  required bool Function() isCurrent,
  Duration timeout = const Duration(seconds: 8),
}) async {
  var expired = false;
  var closing = false;
  Future<void> close(StreamChannel<Object?> socket) async {
    if (closing) return;
    closing = true;
    final subscription = socket.stream.listen((_) {}, onError: (Object _) {});
    try {
      await socket.sink.close().timeout(const Duration(seconds: 2));
    } on Object {
      // The handshake already succeeded; teardown cannot change readiness.
    } finally {
      await subscription
          .cancel()
          .timeout(const Duration(seconds: 2))
          .catchError((Object _) {});
    }
  }

  final opening = connect({'profile': ?profile});
  unawaited(
    opening.then<void>((socket) {
      if (expired || !isCurrent()) unawaited(close(socket));
    }, onError: (Object _, StackTrace _) {}),
  );
  try {
    final socket = await opening.timeout(timeout);
    // This is the sole owner unless the late-result handler already closed it.
    if (!expired && isCurrent()) unawaited(close(socket));
  } finally {
    expired = true;
  }
}
