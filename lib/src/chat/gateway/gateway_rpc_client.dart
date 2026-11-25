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

/// The JSON-RPC error code the gateway answers a call with when its params do
/// not fit the method's schema.
const kGatewayInvalidParams = 4000;

/// The JSON-RPC error code for a method the gateway does not have.
const kGatewayMethodNotFound = -32601;

/// The gateway answered a request with a JSON-RPC error.
class GatewayRpcException implements Exception {
  const GatewayRpcException(this.code, this.message, [this.data]);

  final int code;
  final String message;

  /// The error's `data` object, when the gateway sent one.
  final Map<String, Object?>? data;

  /// `data.code`, the machine-readable reason of a refusal such as
  /// `viewer_mismatch`.
  String? get dataCode {
    final code = data?['code'];
    return code is String ? code : null;
  }

  @override
  String toString() => 'GatewayRpcException($code): $message';
}

/// The socket closed before the gateway answered, or before a request was sent.
class GatewayConnectionClosed implements Exception {
  const GatewayConnectionClosed();

  @override
  String toString() => 'The gateway connection closed';
}

/// A channel that keeps the WebSocket close code readable after the socket
/// ended, which a cast [StreamChannel] would hide.
abstract interface class SocketCloseCode {
  int? get closeCode;
}

/// A call or a connect ran out of time and its socket was dropped. A
/// [GatewayConnectionClosed] to every caller; telemetry tells a hung call from
/// a socket that closed.
class GatewayCallTimedOut extends GatewayConnectionClosed {
  const GatewayCallTimedOut();

  @override
  String toString() => 'The gateway did not answer in time';
}

/// `session.resume` was answered with an error that says this session or turn
/// is not on the server any more (or never will resume), so reconnecting again
/// cannot help. A [GatewayConnectionClosed], so code that treats a lost
/// connection as the reply's end still does; a reader that wants to say why
/// checks for this type first. [code] is the JSON-RPC code of the refusal.
///
/// [restarted]: the server's replay epoch changed since the app last heard from
/// the session, so the server was restarted and its turn died with it.
class GatewaySessionGone extends GatewayConnectionClosed {
  const GatewaySessionGone(this.code, {this.restarted = false});

  final int code;
  final bool restarted;

  @override
  String toString() => 'The gateway no longer has the session ($code)';
}

/// The connection was lost under a reply the server had accepted (the prompt
/// was answered), and the reconnect gave up: the server was not reached, so the
/// turn may well still run. A [GatewayConnectionClosed], and the one kind of it
/// that says the prompt was accepted whether or not any frame of the reply
/// came, so the reply waits instead of failing.
class GatewayReplyLost extends GatewayConnectionClosed {
  const GatewayReplyLost();

  @override
  String toString() => 'The gateway connection was lost under a reply';
}

/// The reply cannot be waited for: the server answered and the turn is no
/// longer running with nothing to show (the silence probe no longer lists it,
/// or a resume found it over with no stored reply), or a turn handed over live
/// was lost and the thread is read again instead. A [GatewayConnectionClosed]
/// so older readers still end the reply, but unlike a lost connection nothing
/// is left to wait for: the reply fails.
///
/// [restarted]: the server was restarted since the app last heard from the
/// session (its replay epoch changed) and brought nothing back, so the turn was
/// interrupted by the restart.
class GatewayTurnEnded extends GatewayConnectionClosed {
  const GatewayTurnEnded({this.restarted = false});

  final bool restarted;

  @override
  String toString() => 'The turn ended without a reply';
}

/// The server cannot be made to say whether the turn still runs: its answers to
/// "is this session still working?" were refused or unreadable for as long as
/// the transport is willing to ask, or the turn has been silent for longer than
/// any live one is. Nothing is waited for any more and nothing is resent, and
/// the reply says it could not confirm how the turn ended. A
/// [GatewayConnectionClosed] so older readers still end the reply.
class GatewayReplyUnconfirmed extends GatewayConnectionClosed {
  const GatewayReplyUnconfirmed();

  @override
  String toString() => 'The gateway could not confirm the turn';
}

/// Whether a `session.resume` refusal is final: no later attempt can succeed.
///
/// The codes are those Hermes' `session.resume` answers for a session it does
/// not have or will not resume: `4000` (params refused), `4006` (no id),
/// `4007` "session not found", `4064` (profile gone), `4130` (transcript too
/// large) and `4132` (a Kanban worker's session). `4007` is final only when its
/// message says "not found"; any other `4007` (such as "session no longer
/// live; retry resume", a race the next attempt wins) is retried, as are `4009`
/// and `5000`.
bool isFinalResumeRefusal(GatewayRpcException error) {
  switch (error.code) {
    case kGatewayInvalidParams || 4006 || 4064 || 4130 || 4132:
      return true;
    case 4007:
      return error.message.toLowerCase().contains('not found');
    default:
      return false;
  }
}

/// A request that asked not to take the connection down with it gave up
/// waiting for its answer. The connection is still open.
class GatewayRequestTimeout implements Exception {
  const GatewayRequestTimeout();

  @override
  String toString() => 'The gateway did not answer in time';
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
    this.defaultTimeout,
    this.onSocketClosed,
  }) : _channel = channel {
    _subscription = channel.stream.listen(
      _onFrame,
      onError: (Object _) => _errored = true,
      onDone: () {
        _closeReason ??= _errored ? 'error' : 'remote_close';
        _onClosed();
      },
    );
  }

  /// Told once when the socket ends, with why (`heartbeat_silence`,
  /// `remote_close`, `local_close`, `error`), the WebSocket close code when
  /// the channel can say one, and how long the socket lived. Never throws into
  /// the client: a failing callback is ignored.
  final void Function(String reason, int? closeCode, Duration lived)?
  onSocketClosed;

  /// How long a request given no `timeout` of its own waits for its answer
  /// before it is abandoned; null for no limit.
  final Duration? defaultTimeout;

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

  /// Who to tell when the answer of an abandoned request still comes.
  final _abandoned = <int, void Function(Map<String, Object?>)>{};
  var _nextId = 1;
  var _closed = false;
  var _errored = false;
  String? _closeReason;
  int? _closeCode;
  final DateTime _openedAt = clock.now();

  /// The WebSocket close code the peer ended the socket with, once it is
  /// closed and the channel could say one.
  int? get closeCode => _closeCode;

  /// How many frames have arrived, to tell a socket that went quiet from one
  /// whose frames are still waiting to be handled.
  var _framesSeen = 0;
  var _holds = 0;
  DateTime _lastFrameAt = clock.now();
  Timer? _pingTimer;
  Timer? _deadline;
  Timer? _probe;
  DateTime? _armedFor;
  String? _epoch;

  bool get isClosed => _closed;

  /// Whether nothing has watched this socket and it has been quiet for
  /// [deadAfter]: it may have died unnoticed, so a caller about to rely on it
  /// should check it first (see [isResponsive]). A held connection is watched
  /// by the heartbeat instead.
  bool get isStale =>
      !_closed &&
      _holds == 0 &&
      clock.now().difference(_lastFrameAt) > deadAfter;

  /// Keeps the heartbeat running until the returned function is called, which
  /// is safe to call more than once. The heartbeat runs while any hold is
  /// open, with a fresh silence deadline from the first one, so a connection
  /// nobody holds is neither pinged nor closed for silence.
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

  /// Sends [method]. A request that gets no answer within [defaultTimeout] is
  /// abandoned like one of [requestWithin].
  Future<Map<String, Object?>> request(
    String method, [
    Map<String, Object?> params = const {},
  ]) => _request(method, params);

  /// Like [request], but a request that gets no answer within [timeout] is
  /// abandoned: it fails with [GatewayRequestTimeout], its span ends and its
  /// entry is dropped, so a late answer is ignored. The socket stays open.
  ///
  /// An answer that comes after the deadline is a timeout too, also when it
  /// was read before the overdue timer ran (the app slept past the deadline).
  /// [onLateResult] is told the result of such an answer, for a request that
  /// changed something on the server which the caller must now undo. With
  /// [acceptLate] such an answer settles the request instead, for a call whose
  /// answer confirms something the caller cannot take back.
  Future<Map<String, Object?>> requestWithin(
    String method,
    Map<String, Object?> params, {
    required Duration timeout,
    void Function(Map<String, Object?> result)? onLateResult,
    bool acceptLate = false,
  }) => _request(
    method,
    params,
    timeout: timeout,
    onLateResult: onLateResult,
    acceptLate: acceptLate,
  );

  /// Rechecks ownership after instrumentation, before sending the request frame.
  /// With [acceptLate], an answer read after the deadline but before the
  /// overdue timer ran still settles the request, for a call whose answer
  /// confirms something the caller cannot take back.
  Future<Map<String, Object?>> requestGuarded(
    String method,
    Map<String, Object?> params, {
    required bool Function() authorize,
    Duration? timeout,
    bool acceptLate = false,
  }) => _request(
    method,
    params,
    authorize: authorize,
    timeout: timeout,
    acceptLate: acceptLate,
  );

  Future<Map<String, Object?>> _request(
    String method,
    Map<String, Object?> params, {
    bool Function()? authorize,
    Duration? timeout,
    void Function(Map<String, Object?> result)? onLateResult,
    bool acceptLate = false,
  }) {
    if (_closed || authorize?.call() == false) {
      return Future.error(const GatewayConnectionClosed());
    }
    final id = _nextId++;
    final span = _telemetry?.startRequest(method, id);
    if (_closed || authorize?.call() == false) {
      _telemetry?.finishRequest(span, failure: const GatewayConnectionClosed());
      return Future.error(const GatewayConnectionClosed());
    }
    final completer = Completer<Map<String, Object?>>();
    final limit = timeout ?? defaultTimeout;
    final pending = _pending[id] = _Pending(
      completer,
      span,
      clock.now(),
      limit,
      onLateResult,
      acceptLate,
    );
    _channel.sink.add(
      jsonEncode({
        'jsonrpc': '2.0',
        'id': id,
        'method': method,
        'params': params,
      }),
    );
    // Armed once the frame is out, so the wait never counts the send.
    if (limit != null) {
      pending.timer = Timer(limit, () {
        if (_pending.remove(id) == null) return;
        if (onLateResult != null) _abandoned[id] = onLateResult;
        _finish(pending, failure: const GatewayRequestTimeout());
        completer.completeError(const GatewayRequestTimeout());
      });
    }
    return completer.future;
  }

  /// Ends [pending]'s span. A span whose deadline passed while the app was
  /// suspended (timers stop with the process, so the end would be stamped
  /// when it woke) is ended at the deadline instead, so no span outlives it.
  void _finish(_Pending pending, {int? errorCode, Object? failure}) {
    final span = pending.span, due = pending.dueAt;
    _telemetry?.finishRequest(
      span == null ||
              due == null ||
              !pending.isOverdue(clock.now(), resumeGrace)
          ? span
          : _EndedAt(span, due),
      errorCode: errorCode,
      failure: failure,
    );
  }

  /// Whether the gateway still answers within [timeout]. Any answer counts,
  /// an error too: a socket the OS dropped while the app slept can look open
  /// and never answer. An answer that comes late still counts: it proves the
  /// socket lives, and closing a live one would cost the replies on it.
  Future<bool> isResponsive(Duration timeout) async {
    try {
      await _request(
        'client.capabilities',
        {'server_requests': true},
        timeout: timeout,
        acceptLate: true,
      );
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
    _closeReason ??= 'local_close';
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

    _probe?.cancel();
    if (late) {
      _ping();
      _probe = Timer(probeTimeout, check);
    } else {
      _probe = Timer(Duration.zero, check);
    }
  }

  void _close() {
    _closeReason ??= 'heartbeat_silence';
    _onClosed();
    unawaited(_subscription.cancel());
    unawaited(_channel.sink.close());
  }

  void _onFrame(String frame) {
    _framesSeen++;
    _lastFrameAt = clock.now();
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
    if (pending == null) {
      _tellLate(_abandoned.remove(id), message);
      return;
    }
    pending.timer?.cancel();
    if (!pending.acceptLate && pending.isOverdue(clock.now(), resumeGrace)) {
      // Read before the overdue timer ran: the caller was promised a timeout.
      _finish(pending, failure: const GatewayRequestTimeout());
      pending.completer.completeError(const GatewayRequestTimeout());
      _tellLate(pending.onLateResult, message);
      return;
    }
    final error = message['error'];
    if (error is Map) {
      final code = switch (error['code']) {
        final num code => code.toInt(),
        _ => 0,
      };
      _finish(pending, errorCode: code);
      final data = error['data'];
      pending.completer.completeError(
        GatewayRpcException(
          code,
          error['message']?.toString() ?? '',
          data is Map ? Map<String, Object?>.from(data) : null,
        ),
      );
    } else {
      switch (message['result']) {
        case null:
          _finish(pending);
          pending.completer.complete(const {});
        case final Map<String, Object?> result:
          _finish(pending);
          pending.completer.complete(result);
        case _:
          // A result that is not an object cannot be read; callers must not
          // take it for a valid empty answer.
          const code = -32603;
          _finish(pending, errorCode: code);
          pending.completer.completeError(
            const GatewayRpcException(code, 'malformed result'),
          );
      }
    }
  }

  void _tellLate(
    void Function(Map<String, Object?> result)? onLateResult,
    Map<String, dynamic> message,
  ) {
    if (onLateResult == null) return;
    if (message['result'] case final Map<String, Object?> result) {
      try {
        onLateResult(result);
      } on Object {
        // The caller's cleanup must not take the socket's reader down.
      }
    }
  }

  void _emit(Object? params) {
    if (params is! Map) return;
    _telemetry?.event(params['type']?.toString() ?? '');
    final type = params['type']?.toString() ?? '';
    final payload = switch (params['payload']) {
      final Map<String, Object?> payload => payload,
      _ => const <String, Object?>{},
    };
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
    _abandoned.clear();
    for (final call in pending) {
      call.timer?.cancel();
      _finish(call, failure: const GatewayConnectionClosed());
      call.completer.completeError(const GatewayConnectionClosed());
    }
    _events.close();
    _serverRequests.close();
    _reportClosed();
  }

  void _reportClosed() {
    try {
      final channel = _channel;
      _closeCode = channel is SocketCloseCode
          ? (channel as SocketCloseCode).closeCode
          : null;
      onSocketClosed?.call(
        _closeReason ?? 'remote_close',
        _closeCode,
        clock.now().difference(_openedAt),
      );
    } on Object {
      // Telemetry must not take the socket's teardown down with it.
    }
  }
}

/// A request awaiting its answer, and the span that times it.
class _Pending {
  _Pending(
    this.completer,
    this.span,
    this.startedAt,
    this.timeout,
    this.onLateResult,
    this.acceptLate,
  );

  final Completer<Map<String, Object?>> completer;
  final Span? span;
  final DateTime startedAt;

  /// How long the request may wait, if it was given a limit.
  final Duration? timeout;

  /// Told the result of an answer that came after the deadline.
  final void Function(Map<String, Object?> result)? onLateResult;

  /// Whether an answer after the deadline still counts as an answer.
  final bool acceptLate;

  /// When the deadline falls, if there is one.
  DateTime? get dueAt {
    final limit = timeout;
    return limit == null ? null : startedAt.add(limit);
  }

  /// Whether [now] is past the deadline by more than [grace]: timers stop
  /// with the process, so a deadline can pass unnoticed while the app sleeps.
  bool isOverdue(DateTime now, Duration grace) {
    final due = dueAt;
    return due != null && now.difference(due) > grace;
  }

  /// Abandons the request when it runs out of time, if it was given any.
  Timer? timer;
}

/// A span that ends at [endTime] whenever it is ended.
class _EndedAt implements Span {
  _EndedAt(this._inner, this.endTime);

  final Span _inner;
  final DateTime endTime;

  @override
  SpanContext get spanContext => _inner.spanContext;

  @override
  String get name => _inner.name;

  @override
  bool get isRecording => _inner.isRecording;

  @override
  void setAttribute(String key, Object? value) =>
      _inner.setAttribute(key, value);

  @override
  void setAttributes(Map<String, Object?> attributes) =>
      _inner.setAttributes(attributes);

  @override
  void addEvent(
    String name, {
    Map<String, Object?>? attributes,
    DateTime? timestamp,
  }) => _inner.addEvent(name, attributes: attributes, timestamp: timestamp);

  @override
  void setStatus(StatusCode code, {String? description}) =>
      _inner.setStatus(code, description: description);

  @override
  void recordException(
    Object exception, {
    StackTrace? stackTrace,
    Map<String, Object?>? attributes,
  }) => _inner.recordException(
    exception,
    stackTrace: stackTrace,
    attributes: attributes,
  );

  @override
  void end([DateTime? _]) => _inner.end(endTime);
}
