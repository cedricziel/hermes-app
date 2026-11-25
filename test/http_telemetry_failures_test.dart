import 'package:dio/dio.dart';
import 'package:flutter_otel/flutter_otel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';

import 'support/recording_tracer.dart';

class _RecordingLogger extends Logger {
  final records = <LogRecord>[];

  @override
  void emit(LogRecord record) => records.add(record);
}

class _Fail implements HttpClientAdapter {
  _Fail({this.status, this.type = DioExceptionType.badResponse});

  final int? status;
  final DioExceptionType type;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (status != null) return ResponseBody.fromString('{}', status!);
    throw DioException(requestOptions: options, type: type);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late RecordingTracer tracer;
  late _RecordingLogger logger;

  setUp(() {
    tracer = RecordingTracer();
    logger = _RecordingLogger();
  });

  Future<void> send(String method, String path, HttpClientAdapter adapter) {
    final dio = Dio(BaseOptions(baseUrl: 'http://hermes.example:9119'))
      ..httpClientAdapter = adapter
      ..interceptors.add(httpInterceptor(logger, tracer));
    return dio
        .request<Object?>(path, options: Options(method: method))
        .then<void>((_) {}, onError: (Object _) {});
  }

  test('a failed answer is an error span with its status and error type, and '
      'one ERROR record with the method, route template and status', () async {
    await send('POST', '/api/auth/ws-ticket', _Fail(status: 401));

    final span = tracer.spans.single;
    expect(span.status, StatusCode.error);
    expect(span.attributes['http.response.status_code'], 401);
    expect(span.attributes['error.type'], 'badResponse');
    final record = logger.records.single;
    expect(record.severity, LogSeverity.error);
    expect(record.body, 'HTTP POST /api/auth 401');
    expect(record.attributes['http.request.method'], 'POST');
    expect(record.attributes['http.route'], '/api/auth');
    expect(record.attributes['http.response.status_code'], 401);
    expect(record.attributes['error.type'], 'badResponse');
  });

  test('a request that never got an answer logs its error type and has no '
      'status', () async {
    await send(
      'GET',
      '/api/sessions/secret-id?token=abc',
      _Fail(type: DioExceptionType.connectionError),
    );

    final span = tracer.spans.single;
    expect(span.status, StatusCode.error);
    expect(span.attributes['error.type'], 'connectionError');
    expect(span.attributes.containsKey('http.response.status_code'), isFalse);
    final record = logger.records.single;
    expect(record.severity, LogSeverity.error);
    expect(record.attributes['error.type'], 'connectionError');
    final exported = '${record.body} ${record.attributes.values.join(' ')}';
    expect(exported, isNot(contains('secret-id')));
    expect(exported, isNot(contains('token')));
  });
}
