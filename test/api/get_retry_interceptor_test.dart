import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_otel/flutter_otel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/get_retry_interceptor.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';

import '../support/recording_tracer.dart';

class _RecordingLogger extends Logger {
  final records = <LogRecord>[];

  @override
  void emit(LogRecord record) => records.add(record);
}

/// Fails the first [failures] requests with [type], then answers 200.
class _Flaky implements HttpClientAdapter {
  _Flaky(this.type, {this.failures = 1 << 30, this.status});

  final DioExceptionType type;
  final int failures;
  final int? status;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (requests.length > failures) return ResponseBody.fromString('{}', 200);
    throw DioException(
      requestOptions: options,
      type: type,
      response: status == null
          ? null
          : Response(requestOptions: options, statusCode: status),
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late List<Duration> slept;
  late Dio dio;

  Dio build(_Flaky adapter, {Random? random, Interceptor? first}) {
    final built = Dio(BaseOptions(baseUrl: 'http://hermes.test'))
      ..httpClientAdapter = adapter;
    if (first != null) built.interceptors.add(first);
    built.interceptors.add(
      GetRetryInterceptor(
        built,
        random: random ?? Random(7),
        sleep: (delay) async => slept.add(delay),
      ),
    );
    return built;
  }

  setUp(() => slept = []);

  test('a GET that fails to connect twice is answered by the third try, '
      'after a growing, jittered wait each', () async {
    final adapter = _Flaky(DioExceptionType.connectionError, failures: 2);
    dio = build(adapter);

    final response = await dio.get<Object?>('/api/status');

    expect(response.statusCode, 200);
    expect(adapter.requests, hasLength(3));
    expect(slept, hasLength(2));
    expect(slept[0], lessThan(const Duration(milliseconds: 500)));
    expect(slept[1], lessThan(const Duration(seconds: 1)));
  });

  test('a GET that keeps failing is tried at most twice more, then fails '
      'with the original error', () async {
    final adapter = _Flaky(DioExceptionType.connectionTimeout);
    dio = build(adapter);

    await expectLater(
      dio.get<Object?>('/api/status'),
      throwsA(
        isA<DioException>().having(
          (e) => e.type,
          'type',
          DioExceptionType.connectionTimeout,
        ),
      ),
    );

    expect(adapter.requests, hasLength(3));
    expect(slept, hasLength(2));
  });

  for (final type in [
    DioExceptionType.receiveTimeout,
    DioExceptionType.sendTimeout,
    DioExceptionType.badCertificate,
    DioExceptionType.cancel,
    DioExceptionType.unknown,
  ]) {
    test('a GET failing with $type is not retried', () async {
      final adapter = _Flaky(type);
      dio = build(adapter);

      await expectLater(
        dio.get<Object?>('/api/status'),
        throwsA(isA<DioException>()),
      );

      expect(adapter.requests, hasLength(1));
      expect(slept, isEmpty);
    });
  }

  test('an answer with an error status is not retried', () async {
    final adapter = _Flaky(DioExceptionType.badResponse, status: 502);
    dio = build(adapter);

    await expectLater(
      dio.get<Object?>('/api/status'),
      throwsA(isA<DioException>()),
    );

    expect(adapter.requests, hasLength(1));
  });

  for (final method in ['POST', 'PATCH', 'PUT', 'DELETE']) {
    test('a $method is never retried, even when it never connected', () async {
      final adapter = _Flaky(DioExceptionType.connectionError);
      dio = build(adapter);

      await expectLater(
        dio.request<Object?>('/api/sessions', options: Options(method: method)),
        throwsA(isA<DioException>()),
      );

      expect(adapter.requests, hasLength(1));
      expect(slept, isEmpty);
    });
  }

  test('requests that fail together do not wait the same time', () async {
    final adapter = _Flaky(DioExceptionType.connectionError, failures: 12);
    dio = build(adapter);

    await Future.wait([
      for (var i = 0; i < 12; i++) dio.get<Object?>('/api/status'),
    ]);

    // Twelve first failures, each with its own draw.
    expect(slept.take(12).toSet().length, greaterThan(6));
  });

  test('a request cancelled while it waits is not sent again', () async {
    final adapter = _Flaky(DioExceptionType.connectionError);
    final token = CancelToken();
    dio = Dio(BaseOptions(baseUrl: 'http://hermes.test'))
      ..httpClientAdapter = adapter;
    dio.interceptors.add(
      GetRetryInterceptor(
        dio,
        random: Random(7),
        sleep: (_) async => token.cancel(),
      ),
    );

    await expectLater(
      dio.get<Object?>('/api/status', cancelToken: token),
      throwsA(
        isA<DioException>().having(
          (e) => e.type,
          'type',
          DioExceptionType.cancel,
        ),
      ),
    );

    expect(adapter.requests, hasLength(1));
  });

  group('with telemetry in front of it', () {
    late RecordingTracer tracer;
    late _RecordingLogger logger;

    setUp(() {
      tracer = RecordingTracer();
      logger = _RecordingLogger();
    });

    test('every failed try keeps its own error span with the error type, '
        'and the burst logger folds their log records into one', () async {
      final adapter = _Flaky(DioExceptionType.connectionError);
      dio = build(adapter, first: httpInterceptor(logger, tracer));

      await expectLater(
        dio.get<Object?>('/api/sessions/some-id'),
        throwsA(isA<DioException>()),
      );

      expect(tracer.spans, hasLength(3));
      for (final span in tracer.spans) {
        expect(span.status, StatusCode.error);
        expect(span.attributes['error.type'], 'connectionError');
        expect(span.attributes['http.route'], '/api/sessions');
        expect(span.ended, isTrue);
      }
      expect(logger.records, hasLength(1));
    });
  });
}
