import 'dart:async';
import 'dart:convert';

import 'package:stream_channel/stream_channel.dart';

/// A server-pushed `event` notification, e.g. `message.delta`.
class GatewayEvent {
  const GatewayEvent({
    required this.type,
    required this.sessionId,
    required this.payload,
  });

  final String type;

  /// The runtime session the event belongs to; empty for events that concern
  /// no session (`sessions.changed`).
  final String sessionId;

  final Map<String, Object?> payload;
}

/// The gateway answered a request with a JSON-RPC error.
class GatewayRpcException implements Exception {
  const GatewayRpcException(this.code, this.message);

  final int code;
  final String message;

  @override
  String toString() => 'GatewayRpcException($code): $message';
}

/// The socket closed before the gateway answered, or before a request was sent.
class GatewayConnectionClosed implements Exception {
  const GatewayConnectionClosed();

  @override
  String toString() => 'The gateway connection closed';
}

/// A JSON-RPC 2.0 client for the dashboard's `/api/ws` socket: requests are
/// answered by id, everything else the server sends is an event.
class GatewayRpcClient {
  GatewayRpcClient(StreamChannel<String> channel) : _channel = channel {
    _subscription = channel.stream.listen(
      _onFrame,
      onError: (Object _) {},
      onDone: _onClosed,
    );
  }

  final StreamChannel<String> _channel;
  late final StreamSubscription<String> _subscription;
  final _events = StreamController<GatewayEvent>.broadcast();
  final _pending = <int, Completer<Map<String, Object?>>>{};
  var _nextId = 1;
  var _closed = false;

  bool get isClosed => _closed;

  /// Ends when the socket closes.
  Stream<GatewayEvent> get events => _events.stream;

  Future<Map<String, Object?>> request(
    String method, [
    Map<String, Object?> params = const {},
  ]) {
    if (_closed) return Future.error(const GatewayConnectionClosed());
    final id = _nextId++;
    final completer = Completer<Map<String, Object?>>();
    _pending[id] = completer;
    _channel.sink.add(
      jsonEncode({
        'jsonrpc': '2.0',
        'id': id,
        'method': method,
        'params': params,
      }),
    );
    return completer.future;
  }

  Future<void> close() async {
    _onClosed();
    await _subscription.cancel();
    await _channel.sink.close();
  }

  void _onFrame(String frame) {
    final Object? message;
    try {
      message = jsonDecode(frame);
    } on FormatException {
      return;
    }
    if (message is! Map<String, dynamic>) return;

    final id = message['id'];
    if (id is int) {
      _settle(id, message);
    } else if (message['method'] == 'event') {
      _emit(message['params']);
    }
  }

  void _settle(int id, Map<String, dynamic> message) {
    final completer = _pending.remove(id);
    if (completer == null) return;
    final error = message['error'];
    if (error is Map) {
      completer.completeError(
        GatewayRpcException(
          (error['code'] as num?)?.toInt() ?? 0,
          error['message']?.toString() ?? '',
        ),
      );
    } else {
      completer.complete(
        message['result'] as Map<String, Object?>? ?? const {},
      );
    }
  }

  void _emit(Object? params) {
    if (params is! Map) return;
    _events.add(
      GatewayEvent(
        type: params['type']?.toString() ?? '',
        sessionId: params['session_id']?.toString() ?? '',
        payload: params['payload'] as Map<String, Object?>? ?? const {},
      ),
    );
  }

  void _onClosed() {
    if (_closed) return;
    _closed = true;
    final pending = _pending.values.toList();
    _pending.clear();
    for (final completer in pending) {
      completer.completeError(const GatewayConnectionClosed());
    }
    _events.close();
  }
}
