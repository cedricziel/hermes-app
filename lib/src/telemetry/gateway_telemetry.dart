import 'package:flutter_otel/flutter_otel.dart';

import 'safely.dart';

/// Traces the dashboard's JSON-RPC socket the way messaging is traced.
///
/// Opening the socket is an HTTP client span for the upgrade. Everything sent
/// or received over it afterwards is a message: a producer span per request,
/// open until the gateway answers, and a consumer span per server event. Each
/// is linked to the connection's span rather than nested under it, so no trace
/// grows for as long as the connection lives.
///
/// Only fixed names are recorded: the JSON-RPC method or event type, the
/// request id and the error code. Never the params, results, session ids or
/// message text. With no tracer every call does nothing.
class GatewayTelemetry {
  GatewayTelemetry([this._tracer]);

  final Tracer? _tracer;
  SpanContext? _connection;

  static const _system = 'hermes.gateway';

  // Streaming a reply sends one delta per chunk; a span each would drown the
  // rest, so the events that mark its start, tools and end stand for it.
  static const _skipped = {'message.delta'};

  static const _knownEvents = {
    'message.start',
    'message.complete',
    'tool.start',
    'tool.complete',
    'session.title',
    'sessions.changed',
    'approval.request',
    'approval.expire',
    'clarify.request',
    'clarify.expire',
  };

  /// Runs [open] inside the client span for the WebSocket upgrade.
  Future<T> connecting<T>(
    Future<T> Function() open, {
    String route = '/api/ws',
  }) async {
    final tracer = _tracer;
    if (tracer == null) return open();
    Span? span;
    safely(
      () => span = tracer.startSpan(
        'HTTP GET',
        kind: SpanKind.client,
        attributes: {'http.method': 'GET', 'http.route': route},
      ),
    );
    try {
      final result = await open();
      safely(() {
        span
          ?..setAttribute('http.status_code', 101)
          ..setStatus(StatusCode.ok)
          ..end();
        _connection = span?.spanContext;
      });
      return result;
    } catch (error) {
      safely(() {
        span
          ?..setAttribute('error.type', error.runtimeType.toString())
          ..setStatus(StatusCode.error)
          ..end();
      });
      rethrow;
    }
  }

  /// Starts the producer span of one request; end it with [finishRequest].
  Span? startRequest(String method, int id) =>
      _start('$method send', SpanKind.producer, {
        'messaging.system': _system,
        'messaging.operation.type': 'send',
        'messaging.destination.name': method,
        'messaging.message.id': '$id',
        'rpc.system': 'jsonrpc',
        'rpc.jsonrpc.version': '2.0',
        'rpc.method': method,
      });

  /// Ends a request's span: with [errorCode] when the gateway answered with a
  /// JSON-RPC error, with [failure] when there was no answer, else as a success.
  void finishRequest(Span? span, {int? errorCode, Object? failure}) {
    if (span == null) return;
    safely(() {
      if (errorCode != null) {
        span.setAttribute('rpc.jsonrpc.error_code', errorCode);
      }
      if (failure != null) {
        span.setAttribute('error.type', failure.runtimeType.toString());
      }
      span
        ..setStatus(
          errorCode != null || failure != null
              ? StatusCode.error
              : StatusCode.ok,
        )
        ..end();
    });
  }

  /// Records a server event as an instant consumer span.
  void event(String type) {
    if (_skipped.contains(type)) return;
    final name = _knownEvents.contains(type) ? type : 'other';
    _start('$name receive', SpanKind.consumer, {
        'messaging.system': _system,
        'messaging.operation.type': 'receive',
        'messaging.destination.name': name,
      })
      ?..setStatus(StatusCode.ok)
      ..end();
  }

  Span? _start(String name, SpanKind kind, Map<String, Object?> attributes) {
    final tracer = _tracer;
    if (tracer == null) return null;
    Span? span;
    safely(() {
      final connection = _connection;
      span = tracer.startSpan(
        name,
        kind: kind,
        attributes: attributes,
        links: [if (connection != null) SpanLink(connection)],
      );
    });
    return span;
  }
}
