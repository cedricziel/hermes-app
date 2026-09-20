import 'package:dio/dio.dart';
import 'package:flutter_otel/flutter_otel.dart';
import 'package:flutter_otel_instrumentation_dio/flutter_otel_instrumentation_dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/recording_tracer.dart';

class _RecordingLogger extends Logger {
  final records = <LogRecord>[];

  @override
  void emit(LogRecord record) => records.add(record);
}

class _Reply implements HttpClientAdapter {
  _Reply(this.status);

  final int status;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString('{}', status);

  @override
  void close({bool force = false}) {}
}

void main() {
  late RecordingTracer tracer;
  late _RecordingLogger logger;
  late Dio dio;

  setUp(() {
    tracer = RecordingTracer();
    logger = _RecordingLogger();
    dio = Dio(BaseOptions(baseUrl: 'http://hermes.example:9119'))
      ..interceptors.add(DioOTelInterceptor.privacy(logger, tracer: tracer));
  });

  Future<void> get(String path, {int status = 200}) async {
    dio.httpClientAdapter = _Reply(status);
    await dio.get<Object?>(path, options: Options(validateStatus: (_) => true));
  }

  test('records only the first two path segments as the route', () async {
    await get('/api/sessions/abc123/messages');
    await get('/api/profiles/work-laptop');
    await get('/api/plugins/kanban/tasks/42');
    await get('/api/status');

    expect(tracer.spans.map((s) => s.attributes['http.route']), [
      '/api/sessions',
      '/api/profiles',
      '/api/plugins',
      '/api/status',
    ]);
  });

  test('never exports an identifier from the path', () async {
    await get('/api/sessions/secret-session-id?token=abc#frag');

    final exported = [
      for (final s in tracer.spans) ...s.attributes.values,
      for (final r in logger.records) ...[r.body, ...r.attributes.values],
    ].join(' ');
    expect(exported, isNot(contains('secret-session-id')));
    expect(exported, isNot(contains('token')));
    expect(exported, isNot(contains('hermes.example')));
  });
}
