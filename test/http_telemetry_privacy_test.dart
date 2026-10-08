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
      ..interceptors.add(httpInterceptor(logger, tracer));
  });

  Future<void> get(String path, {int status = 200}) async {
    dio.httpClientAdapter = _Reply(status);
    await dio.get<Object?>(path, options: Options(validateStatus: (_) => true));
  }

  test('describes every span and log record with the server attributes, '
      'under the request\'s own', () async {
    dio.interceptors
      ..clear()
      ..add(
        httpInterceptor(
          logger,
          tracer,
          serverAttributes: const {
            'hermes.version': '0.14.2',
            'http.request.method': 'shadowed',
          },
        ),
      );

    await get('/api/sessions');

    final span = tracer.spans.single;
    expect(span.attributes['hermes.version'], '0.14.2');
    expect(span.attributes['http.request.method'], 'GET');
    expect(span.attributes['peer.service'], 'hermes-agent');
    expect(logger.records.single.attributes['hermes.version'], '0.14.2');
  });

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

  test('names the Hermes backend as the peer service', () async {
    await get('/api/status');

    expect(tracer.spans.single.attributes['peer.service'], 'hermes-agent');
    expect(logger.records.single.attributes['peer.service'], 'hermes-agent');
  });
}
