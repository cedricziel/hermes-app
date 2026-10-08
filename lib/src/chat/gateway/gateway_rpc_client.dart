import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:dart_otel_instrumentation_messaging/dart_otel_instrumentation_messaging.dart';
import 'package:flutter_otel/flutter_otel.dart';
import 'package:stream_channel/stream_channel.dart';

/// A server-pushed `event` notification, e.g. `message.delta`.
class GatewayEvent {
  const GatewayEvent({
    required this.type,
    required this.sessionId,
    required this.payload,
    this.seq,
  });

  final String type;

  /// The runtime session the event belongs to; empty for events that concern
  /// no session (`sessions.changed`).
  final String sessionId;

  final Map<String, Object?> payload;

  /// The event's position in its session, from 1, when the server numbers its
  /// events. A replay after a reconnect asks for the events past a seq.
  final int? seq;
}

/// A request the gateway sends to the client and waits on, e.g. `approval`.
/// The client answers it with [GatewayRpcClient.respond] or
/// [GatewayRpcClient.respondError], quoting [id].
class GatewayServerRequest {
  const GatewayServerRequest({
    required this.id,
    required this.method,
    required this.sessionId,
    required this.params,
  });

  final String id;
  final String method;

  /// The runtime session the request belongs to.
  final String sessionId;

  final Map<String, Object?> params;
}

/// The JSON-RPC error code the gateway answers a profile-scoped call with when
/// the named profile does not exist (`ProfileUnavailableError` upstream).
const kGatewayProfileUnavailable = 4064;

/// The JSON-RPC error code for a method the gateway does not have.
const kGatewayMethodNotFound = -32601;

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
/// answered by id, the server's own requests are reported as
/// [serverRequests], and everything else the server sends is an event.
class GatewayRpcClient {
  /// With [heartbeat], the client pings the gateway every [pingEvery] and
  /// closes itself once no frame of any kind has arrived for [deadAfter]. A
  /// socket the OS dropped while the app slept can look open and never
  /// answer; without the heartbeat nothing notices until the next request.
  /// The heartbeat runs only while the connection is held (see [hold]).
  GatewayRpcClient(
    StreamChannel<String> channel, {
    this._telemetry,
    this.heartbeat = false,
    this.pingEvery = const Duration(seconds: 15),
    this.deadAfter = const Duration(seconds: 45),
    this.resumeGrace = const Duration(milliseconds: 250),
    this.probeTimeout = const Duration(seconds: 5),
  }) : _channel = channel {
    _subscription = channel.stream.listen(
      _onFrame,
      onError: (Object _) {},
      onDone: _onClosed,
    );
  }

  final bool heartbeat;
  final Duration pingEvery;
  final Duration deadAfter;

  /// How late a deadline must fire to count as one the app slept through.
  final Duration resumeGrace;

  /// How long a deadline that fired late waits, after a ping, for any frame
  /// before closing. A radio that is waking up can take a few seconds to
  /// carry traffic again; this is long enough for that and still quick to
  /// give up on a dead socket.
  final Duration probeTimeout;

  final StreamChannel<String> _channel;
  final MessagingConnectionTracer? _telemetry;
  late final StreamSubscription<String> _subscription;
  final _events = StreamController<GatewayEvent>.broadcast();
  final _serverRequests = StreamController<GatewayServerRequest>.broadcast();
  final _pending = <int, _Pending>{};
  var _nextId = 1;
  var _closed = false;

  /// How many frames have arrived, to tell a socket that went quiet from one
  /// whose frames are still waiting to be handled.
  var _framesSeen = 0;
  var _holds = 0;
  Timer? _pingTimer;
  Timer? _deadline;
  Timer? _probe;
  DateTime? _armedFor;
  String? _epoch;

  bool get isClosed => _closed;

  /// Keeps the heartbeat running until the returned function is called, which
  /// is safe to call more than once. The heartbeat runs while any hold is
  /// open, with a fresh silence deadline from the first one, so an idle
  /// connection nobody listens to is neither pinged nor closed for silence.
  void Function() hold() {
    if (_closed) return () {};
    if (_holds++ == 0 && heartbeat) {
      _armDeadline(deadAfter);
      _pingTimer = Timer.periodic(pingEvery, (_) => _ping());
    }
    var held = true;
    return () {
      if (!held) return;
      held = false;
      if (--_holds == 0) _stopHeartbeat();
    };
  }

  void _stopHeartbeat() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _deadline?.cancel();
    _deadline = null;
    _probe?.cancel();
    _probe = null;
  }

  /// The replay epoch the gateway announced in `gateway.ready`, or null
  /// until one arrives. A changed epoch means the gateway lost its replay
  /// ring, so the caller must refetch rather than replay.
  String? get epoch => _epoch;

  /// Ends when the socket closes.
  Stream<GatewayEvent> get events => _events.stream;

  /// Requests the gateway makes of the client. Ends when the socket closes.
  Stream<GatewayServerRequest> get serverRequests => _serverRequests.stream;

  Future<Map<String, Object?>> request(
    String method, [
    Map<String, Object?> params = const {},
  ]) {
    if (_closed) return Future.error(const GatewayConnectionClosed());
    final id = _nextId++;
    final completer = Completer<Map<String, Object?>>();
    _pending[id] = _Pending(completer, _telemetry?.startRequest(method, id));
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

  /// Whether the gateway still answers within [timeout]. Any answer counts,
  /// an error too: a socket the OS dropped while the app slept can look open
  /// and never answer.
  Future<bool> isResponsive(Duration timeout) async {
    try {
      await request('client.capabilities', {
        'server_requests': true,
      }).timeout(timeout);
      return true;
    } on GatewayRpcException {
      return true;
    } on Object {
      return false;
    }
  }

  /// Answers the server request [id] with [result]. Does nothing once the
  /// socket has closed: the gateway is no longer waiting.
  void respond(String id, Map<String, Object?> result) =>
      _reply({'id': id, 'result': result});

  /// Answers the server request [id] with a JSON-RPC error.
  void respondError(String id, int code, String message) => _reply({
    'id': id,
    'error': {'code': code, 'message': message},
  });

  void _reply(Map<String, Object?> message) {
    if (_closed) return;
    _channel.sink.add(jsonEncode({'jsonrpc': '2.0', ...message}));
  }

  Future<void> close() async {
    _onClosed();
    await _subscription.cancel();
    await _channel.sink.close();
  }

  /// Sends a heartbeat ping. A refused ping still means the gateway answered,
  /// so only the answer's arrival matters; the answer itself is a frame and
  /// resets the deadline.
  void _ping() {
    if (_closed) return;
    request('gateway.ping').then<void>((_) {}, onError: (Object _) {});
  }

  /// Restarts the countdown that closes a silent socket. Called on every
  /// inbound frame, so the deadline is measured from the last frame of any kind.
  void _armDeadline(Duration after) {
    _deadline?.cancel();
    _armedFor = clock.now().add(after);
    _deadline = Timer(after, _onSilent);
  }

  /// The deadline passed. After the app was suspended it fires long past due,
  /// before the frames that arrived meanwhile are read from the socket, so
  /// the socket is closed only if still no frame came after a wait: one turn
  /// of the event loop, or, when the deadline ran late, a ping and up to
  /// [probeTimeout] for any frame.
  void _onSilent() {
    final seen = _framesSeen;
    final due = _armedFor;
    final late = due != null && clock.now().difference(due) > resumeGrace;
    void check() {
      if (_closed || _holds == 0 || _framesSeen != seen) return;
      _close();
    }

    if (late) {
      _ping();
      _probe = Timer(probeTimeout, check);
    } else {
      Timer.run(check);
    }
  }

  void _close() {
    _onClosed();
    unawaited(_subscription.cancel());
    unawaited(_channel.sink.close());
  }

  void _onFrame(String frame) {
    _framesSeen++;
    if (_holds > 0 && heartbeat && !_closed) _armDeadline(deadAfter);
    final Object? message;
    try {
      message = jsonDecode(frame);
    } on FormatException {
      return;
    }
    if (message is! Map<String, dynamic>) return;

    final id = message['id'];
    final method = message['method'];
    if (id is int) {
      _settle(id, message);
    } else if (method == 'event') {
      _emit(message['params']);
    } else if (id is String && method is String) {
      _serverRequest(id, method, message['params']);
    }
  }

  void _serverRequest(String id, String method, Object? params) {
    final Map<String, Object?> fields = params is Map<String, Object?>
        ? params
        : const {};
    _serverRequests.add(
      GatewayServerRequest(
        id: id,
        method: method,
        sessionId: fields['session_id']?.toString() ?? '',
        params: fields,
      ),
    );
  }

  void _settle(int id, Map<String, dynamic> message) {
    final pending = _pending.remove(id);
    if (pending == null) return;
    final error = message['error'];
    if (error is Map) {
      final code = (error['code'] as num?)?.toInt() ?? 0;
      _telemetry?.finishRequest(pending.span, errorCode: code);
      pending.completer.completeError(
        GatewayRpcException(code, error['message']?.toString() ?? ''),
      );
    } else {
      _telemetry?.finishRequest(pending.span);
      pending.completer.complete(
        message['result'] as Map<String, Object?>? ?? const {},
      );
    }
  }

  void _emit(Object? params) {
    if (params is! Map) return;
    _telemetry?.event(params['type']?.toString() ?? '');
    final type = params['type']?.toString() ?? '';
    final payload = params['payload'] as Map<String, Object?>? ?? const {};
    final seq = params['seq'];
    var sessionId = params['session_id']?.toString() ?? '';
    // Session-less broadcasts such as approval.cancelled carry their session
    // in the payload; lift it so per-session filtering routes them.
    final payloadSession = payload['session_id'];
    if (sessionId.isEmpty && payloadSession is String) {
      sessionId = payloadSession;
    }
    if (type == 'gateway.ready') {
      final epoch = payload['replay_epoch'];
      if (epoch is String) _epoch = epoch;
    }
    _events.add(
      GatewayEvent(
        type: type,
        sessionId: sessionId,
        payload: payload,
        seq: seq is int ? seq : null,
      ),
    );
  }

  void _onClosed() {
    if (_closed) return;
    _closed = true;
    _stopHeartbeat();
    final pending = _pending.values.toList();
    _pending.clear();
    for (final call in pending) {
      _telemetry?.finishRequest(
        call.span,
        failure: const GatewayConnectionClosed(),
      );
      call.completer.completeError(const GatewayConnectionClosed());
    }
    _events.close();
    _serverRequests.close();
  }
}

/// A request awaiting its answer, and the span that times it.
class _Pending {
  _Pending(this.completer, this.span);

  final Completer<Map<String, Object?>> completer;
  final Span? span;
}
