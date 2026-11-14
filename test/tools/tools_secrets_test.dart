import 'package:dio/dio.dart';
import 'package:flutter_otel/flutter_otel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_api/hermes_api.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';
import 'package:hermes_app/src/tools/hermes_tools_repository.dart';

import '../support/fake_hermes_server.dart';
import '../support/recording_tracer.dart';

const _secret = 'sk-test-0123456789-NOT-A-REAL-KEY';
const _path = '/api/tools/toolsets/web/env';

class _RecordingLogger extends Logger {
  final records = <LogRecord>[];

  @override
  void emit(LogRecord record) => records.add(record);
}

/// A key typed into the form, sent through the real generated client and a
/// Dio carrying the app's telemetry interceptor.
void main() {
  late FakeHermesServer server;
  late RecordingTracer tracer;
  late _RecordingLogger logger;
  late DefaultApi api;
  late HermesToolsRepository repository;
  late List<String> events;

  setUp(() {
    server = FakeHermesServer();
    tracer = RecordingTracer();
    logger = _RecordingLogger();
    final dio = server.dio()..interceptors.add(httpInterceptor(logger, tracer));
    api = DefaultApi(dio);
    events = [];
    repository = HermesToolsRepository(
      api,
      profile: 'work',
      telemetry: ConnectionTelemetry(
        tracer: tracer,
        events: (name, [attributes = const {}]) =>
            events.add('$name $attributes'),
      ),
    );
  });

  String everythingRecorded() => [
    for (final span in tracer.spans)
      '${span.name} ${span.attributes} ${span.events} ${span.statusDescription}',
    for (final record in logger.records) '${record.body} ${record.attributes}',
    ...events,
  ].join('\n');

  Future<ToolsResult<Object?>> save() =>
      repository.saveEnv('web', {'SEARCHCO_API_KEY': _secret});

  void expectNoTrace(ToolsResult<Object?> result) {
    // The interceptor was on the path, so there is something to inspect.
    expect(tracer.spans, isNotEmpty);
    expect(logger.records, isNotEmpty);
    expect(everythingRecorded(), isNot(contains(_secret)));
    expect(everythingRecorded(), isNot(contains('SEARCHCO_API_KEY')));
    expect('$result', isNot(contains(_secret)));
    if (result case ToolsRefused(:final detail)) {
      expect(detail ?? '', isNot(contains(_secret)));
    }
  }

  test('the value leaves in the request body once and nowhere else', () async {
    server.on('PUT', _path, {
      'ok': true,
      'saved': ['SEARCHCO_API_KEY'],
      'skipped': [],
    });

    final result = await save();

    expect(result, isA<ToolsOk>());
    expect(server.requestsTo('PUT', _path), hasLength(1));
    expect(server.requests.single.data.toString(), contains(_secret));
    expect(server.requests.single.uri.toString(), isNot(contains(_secret)));
    expectNoTrace(result);
  });

  test('the generated request model prints the value, so nothing may print '
      'it', () {
    // Documents why the repository never keeps or prints the model.
    final model = ToolsetEnvUpdate(env: {'K': _secret}, profile: 'work');
    expect(model.toString(), contains(_secret));
  });

  for (final (label, status) in [
    ('a refused save', 400),
    ('a failed save', 500),
    ('a forbidden save', 403),
    ('a save the server does not know', 404),
  ]) {
    test('$label leaves no trace of the value', () async {
      server.on('PUT', _path, {'detail': 'Unknown env var(s)'}, status: status);

      expectNoTrace(await save());
    });
  }

  test('a lost answer leaves no trace of the value', () async {
    server.onRequest('PUT', _path, (r) {
      throw DioException.receiveTimeout(
        timeout: const Duration(seconds: 1),
        requestOptions: r,
      );
    });

    final result = await save();

    expect((result as ToolsFailed).kind, ToolsFailure.unknownOutcome);
    expectNoTrace(result);
  });

  test('a lost answer is not resent by the repository', () async {
    server.onRequest('PUT', _path, (r) {
      throw DioException.receiveTimeout(
        timeout: const Duration(seconds: 1),
        requestOptions: r,
      );
    });

    await save();

    expect(server.requestsTo('PUT', _path), hasLength(1));
  });

  group('DioException.toString does not carry the body', () {
    Future<DioException> raw(
      FakeResponse Function(RequestOptions) answer,
    ) async {
      server.onRequest('PUT', _path, answer);
      try {
        await api.saveToolsetEnvApiToolsToolsetsNameEnvPut(
          name: 'web',
          toolsetEnvUpdate: ToolsetEnvUpdate(
            env: {'SEARCHCO_API_KEY': _secret},
            profile: 'work',
          ),
          profile: 'work',
        );
      } on DioException catch (error) {
        return error;
      }
      fail('the call should have failed');
    }

    test('after a failed save', () async {
      final error = await raw((_) => (status: 500, body: {'detail': 'x'}));

      expect(error.toString(), isNot(contains(_secret)));
      expect('${error.message} ${error.error}', isNot(contains(_secret)));
    });

    test('after a lost answer', () async {
      final error = await raw(
        (r) => throw DioException.receiveTimeout(
          timeout: const Duration(seconds: 1),
          requestOptions: r,
        ),
      );

      expect(error.toString(), isNot(contains(_secret)));
    });
  });
}
