import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_otel/flutter_otel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/telemetry/http_telemetry_interceptor.dart';

const _host = 'secret-hermes.example.org';

class _RecordingSpan implements Span {
  _RecordingSpan(this.name, this.kind, this.spanContext);

  @override
  final String name;
  final SpanKind kind;
  @override
  final SpanContext spanContext;

  final Map<String, Object?> attributes = {};
  final List<String> events = [];
  StatusCode? status;
  String? statusDescription;
  bool ended = false;

  @override
  bool get isRecording => !ended;

  @override
  void setAttribute(String key, Object? value) => attributes[key] = value;

  @override
  void setAttributes(Map<String, Object?> attributes) =>
      this.attributes.addAll(attributes);

  @override
  void addEvent(
    String name, {
    Map<String, Object?>? attributes,
    DateTime? timestamp,
  }) => events.add(name);

  @override
  void setStatus(StatusCode code, {String? description}) {
    status = code;
    statusDescription = description;
  }

  @override
  void recordException(
    Object exception, {
    StackTrace? stackTrace,
    Map<String, Object?>? attributes,
  }) => events.add('exception');

  @override
  void end([DateTime? endTime]) => ended = true;
}

class _RecordingTracer implements Tracer {
  final List<_RecordingSpan> spans = [];

  @override
  String get name => 'test';

  @override
  Span startSpan(
    String name, {
    SpanKind kind = SpanKind.internal,
    Map<String, Object?>? attributes,
    SpanContext? parentContext,
    List<SpanLink> links = const [],
  }) {
    final span = _RecordingSpan(
      name,
      kind,
      SpanContext(traceId: 'a' * 32, spanId: '1' * 16),
    );
    if (attributes != null) span.setAttributes(attributes);
    spans.add(span);
    return span;
  }

  @override
  Future<T> startActiveSpan<T>(
    String name,
    Future<T> Function(Span span) body, {
    SpanKind kind = SpanKind.internal,
    Map<String, Object?>? attributes,
    List<SpanLink> links = const [],
  }) => throw UnimplementedError();
}

class _ThrowingTracer extends _RecordingTracer {
  @override
  Span startSpan(
    String name, {
    SpanKind kind = SpanKind.internal,
    Map<String, Object?>? attributes,
    SpanContext? parentContext,
    List<SpanLink> links = const [],
  }) => throw StateError('tracer broke');
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._respond);

  final Future<ResponseBody> Function(RequestOptions options) _respond;
  final List<Map<String, dynamic>> requestHeaders = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requestHeaders.add(Map.of(options.headers));
    return _respond(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _RecordingTracer tracer;

  Dio buildDio(
    Future<ResponseBody> Function(RequestOptions) respond, {
    Tracer? withTracer,
  }) {
    final dio = Dio(BaseOptions(baseUrl: 'https://$_host'));
    dio.httpClientAdapter = _FakeAdapter(respond);
    dio.interceptors.add(HttpTelemetryInterceptor(withTracer ?? tracer));
    return dio;
  }

  setUp(() => tracer = _RecordingTracer());

  test('records a client span with method, route and status', () async {
    final dio = buildDio((_) async => ResponseBody.fromString('{}', 200));

    await dio.get<dynamic>('/api/status');

    final span = tracer.spans.single;
    expect(span.name, 'HTTP GET');
    expect(span.kind, SpanKind.client);
    expect(span.attributes, {
      'http.method': 'GET',
      'http.route': '/api/status',
      'http.status_code': 200,
    });
    expect(span.status, StatusCode.ok);
    expect(span.ended, isTrue);
  });

  test('marks 4xx/5xx responses as errors and still ends the span', () async {
    final dio = buildDio((_) async => ResponseBody.fromString('', 500));

    await expectLater(dio.get<dynamic>('/api/x'), throwsA(isA<DioException>()));

    final span = tracer.spans.single;
    expect(span.attributes['http.status_code'], 500);
    expect(span.attributes['error.type'], 'badResponse');
    expect(span.status, StatusCode.error);
    expect(span.ended, isTrue);
  });

  test('never exports the server host or exception details', () async {
    final dio = buildDio(
      (options) async => throw DioException.connectionError(
        requestOptions: options,
        reason: 'Failed host lookup: $_host',
      ),
    );

    await expectLater(dio.get<dynamic>('/api/x'), throwsA(isA<DioException>()));

    final span = tracer.spans.single;
    expect(span.attributes['error.type'], 'connectionError');
    expect(span.statusDescription, isNull);
    expect(span.events, isEmpty);
    expect(span.attributes.values.join(' '), isNot(contains(_host)));
  });

  test(
    'leaves out the route when the request path is an absolute URL',
    () async {
      final dio = buildDio((_) async => ResponseBody.fromString('', 200));

      await dio.get<dynamic>('https://$_host/auth/native/refresh');

      final span = tracer.spans.single;
      expect(span.attributes.containsKey('http.route'), isFalse);
      expect(span.attributes.values.join(' '), isNot(contains(_host)));
    },
  );

  test('does not add a traceparent header to requests', () async {
    final adapter = _FakeAdapter((_) async => ResponseBody.fromString('', 200));
    final dio = Dio(BaseOptions(baseUrl: 'https://$_host'))
      ..httpClientAdapter = adapter
      ..interceptors.add(HttpTelemetryInterceptor(tracer));

    await dio.get<dynamic>('/api/status');

    expect(
      adapter.requestHeaders.single.keys.map((k) => k.toLowerCase()),
      isNot(contains('traceparent')),
    );
  });

  test('a failing tracer never breaks the request', () async {
    final dio = buildDio(
      (_) async => ResponseBody.fromString('{}', 200),
      withTracer: _ThrowingTracer(),
    );

    final response = await dio.get<dynamic>('/api/status');

    expect(response.statusCode, 200);
  });
}
