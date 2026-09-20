import 'package:dio/dio.dart';
import 'package:flutter_otel/flutter_otel.dart';

import 'safely.dart';

/// Records one client span and one log record per request.
///
/// Requests go to a server address the user typed in, so this deliberately
/// leaves out anything that could identify it: no URL or host, no query
/// string, no exception messages (Dio puts the host in them), and no
/// `traceparent` header. What it keeps is the method, the status, the error
/// type, the duration and, for relative request paths, the first two path
/// segments (`/api/sessions` for `/api/sessions/<id>/messages`), so session
/// ids, profile names and other path parameters never leave the device.
class HttpTelemetryInterceptor extends Interceptor {
  HttpTelemetryInterceptor(this._tracer, this._logger);

  static const _callKey = 'hermes.telemetry.call';
  static final _routeEnd = RegExp('[?#]');
  static const _routeSegments = 2;

  final Tracer _tracer;
  final Logger _logger;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final call = _Call(_route(options.path));
    options.extra[_callKey] = call;
    safely(() {
      call.span = _tracer.startSpan(
        'HTTP ${options.method}',
        kind: SpanKind.client,
        attributes: {'http.method': options.method, 'http.route': ?call.route},
      );
    });
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final status = response.statusCode;
    _finish(
      response.requestOptions,
      status: status,
      spanStatus: status != null && status >= 400
          ? StatusCode.error
          : StatusCode.ok,
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _finish(
      err.requestOptions,
      status: err.response?.statusCode,
      errorType: err.type.name,
      spanStatus: StatusCode.error,
    );
    handler.next(err);
  }

  void _finish(
    RequestOptions options, {
    required int? status,
    required StatusCode spanStatus,
    String? errorType,
  }) {
    final call = options.extra.remove(_callKey) as _Call?;
    if (call == null) return;
    final span = call.span;
    safely(() {
      if (span == null) return;
      if (status != null) span.setAttribute('http.status_code', status);
      if (errorType != null) span.setAttribute('error.type', errorType);
      span.setStatus(spanStatus);
      span.end();
    });
    safely(() {
      final failed =
          errorType != null || status == null || status < 200 || status >= 300;
      _logger.emit(
        LogRecord(
          body: [
            'HTTP ${options.method}',
            ?call.route,
            status ?? errorType,
          ].join(' '),
          severity: failed ? LogSeverity.error : LogSeverity.info,
          attributes: {
            'http.method': options.method,
            'http.route': ?call.route,
            'http.status_code': ?status,
            'http.duration_ms': call.stopwatch.elapsedMilliseconds,
            'error.type': ?errorType,
          },
          traceId: span?.spanContext.traceId,
          spanId: span?.spanContext.spanId,
        ),
      );
    });
  }

  /// The first [_routeSegments] segments of a relative path, without query or
  /// fragment. Later segments are where path parameters live.
  static String? _route(String path) {
    if (!path.startsWith('/')) return null;
    final end = path.indexOf(_routeEnd);
    final segments = (end < 0 ? path : path.substring(0, end))
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .take(_routeSegments);
    return '/${segments.join('/')}';
  }
}

/// What the interceptor keeps between a request and its response.
class _Call {
  _Call(this.route);

  final String? route;
  final Stopwatch stopwatch = Stopwatch()..start();
  Span? span;
}
