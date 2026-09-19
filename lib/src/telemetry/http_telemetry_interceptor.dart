import 'package:dio/dio.dart';
import 'package:flutter_otel/flutter_otel.dart';

/// Records one client span per request.
///
/// Requests go to a server address the user typed in, so this deliberately
/// leaves out anything that could identify it: no URL or host, no exception
/// messages (Dio puts the host in them), and no `traceparent` header. What
/// it keeps is the method, the status, the error type and, for relative
/// request paths such as `/api/status`, the path.
class HttpTelemetryInterceptor extends Interceptor {
  HttpTelemetryInterceptor(this._tracer);

  static const _spanKey = 'hermes.telemetry.span';

  final Tracer _tracer;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _safely(() {
      options.extra[_spanKey] = _tracer.startSpan(
        'HTTP ${options.method}',
        kind: SpanKind.client,
        attributes: {
          'http.method': options.method,
          if (options.path.startsWith('/')) 'http.route': options.path,
        },
      );
    });
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _safely(() {
      final span = _take(response.requestOptions);
      if (span == null) return;
      final status = response.statusCode;
      if (status != null) span.setAttribute('http.status_code', status);
      span.setStatus(
        status != null && status >= 400 ? StatusCode.error : StatusCode.ok,
      );
      span.end();
    });
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _safely(() {
      final span = _take(err.requestOptions);
      if (span == null) return;
      final status = err.response?.statusCode;
      if (status != null) span.setAttribute('http.status_code', status);
      span.setAttribute('error.type', err.type.name);
      span.setStatus(StatusCode.error);
      span.end();
    });
    handler.next(err);
  }

  Span? _take(RequestOptions options) =>
      options.extra.remove(_spanKey) as Span?;

  /// Telemetry must never break a request.
  void _safely(void Function() body) {
    try {
      body();
    } catch (_) {}
  }
}
