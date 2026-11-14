import 'package:dio/dio.dart';
import 'package:flutter_otel/flutter_otel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_api_client.dart';
import 'package:hermes_app/src/providers/provider_results.dart';
import 'package:hermes_app/src/providers/providers_repository.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';

import '../support/fake_hermes_server.dart';
import '../support/recording_tracer.dart';
import 'provider_fixtures.dart';

const _secret = 'sk-test-SECRET-123456';
const _lastFour = '3456';

class _RecordingLogger extends Logger {
  final records = <LogRecord>[];

  @override
  void emit(LogRecord record) => records.add(record);
}

/// Every signal the app could export, plus what the repository answered.
class _Harness {
  _Harness() {
    final dio = server.dio()..interceptors.add(httpInterceptor(logger, tracer));
    repository = ProvidersRepository(
      HermesApiClient(dio).raw,
      checkBudget: const Duration(milliseconds: 80),
      telemetry: ConnectionTelemetry(
        tracer: tracer,
        serverAttributes: const {'hermes.version': 'test'},
        events: (name, [attributes = const {}]) {
          events.add('$name $attributes');
          trail.record(name, attributes);
        },
      ),
    );
  }

  final server = FakeHermesServer();
  final tracer = RecordingTracer();
  final logger = _RecordingLogger();
  final trail = BreadcrumbTrail();
  final events = <String>[];
  final answers = <String>[];
  late final ProvidersRepository repository;

  /// Remembers what a call returned, as text a person could see.
  T keep<T extends Object>(T answer, [String? text]) {
    answers.add('${answer.runtimeType} ${text ?? answer}');
    return answer;
  }

  String exported() => [
    for (final span in tracer.spans)
      '${span.name} ${span.attributes} ${span.events} ${span.statusDescription}',
    for (final r in logger.records) '${r.body} ${r.attributes}',
    ...events,
    for (final b in trail.recent) '${b.name} ${b.attributes}',
    ...answers,
  ].join('\n');
}

void main() {
  late _Harness h;

  setUp(() => h = _Harness());

  void echoing(String method, String path, int status) =>
      h.server.on(method, path, {
        'detail': [
          {
            'type': 'string_type',
            'loc': ['body', 'value'],
            'msg': 'Input should be a valid string',
            'input': _secret,
          },
        ],
      }, status: status);

  void lost(String method, String path) =>
      h.server.onRequest(method, path, (request) {
        throw DioException.connectionError(
          requestOptions: request,
          reason: 'offline $_secret',
          error: StateError(_secret),
        );
      });

  Future<void> everyKeyPath() async {
    final r = h.repository;
    final check = await r.checkKey('OPENROUTER_API_KEY', _secret);
    h.keep(check, switch (check) {
      KeyRejected(:final message) => message,
      KeyProviderError(:final message) => message,
      _ => null,
    });
    final saved = await r.saveKey('work', 'OPENROUTER_API_KEY', _secret);
    h.keep(saved, saved is KeyRefused ? saved.message : null);
    final probe = await r.checkEndpoint(
      name: 'Lab',
      baseUrl: 'https://lab.example.com',
      apiKey: _secret,
    );
    h.keep(probe, probe is EndpointChecked ? probe.warning : null);
    final endpoint = await r.saveEndpoint(
      'work',
      name: 'Lab',
      baseUrl: 'https://lab.example.com',
      apiKey: _secret,
    );
    h.keep(endpoint, endpoint is EndpointRefused ? endpoint.message : null);
  }

  test('a key through every path leaves no trace in telemetry', () async {
    h.server
      ..on('POST', '/api/providers/validate', {
        'ok': true,
        'reachable': true,
        'message': '',
      })
      ..on('PUT', '/api/env', {'ok': true, 'key': 'OPENROUTER_API_KEY'})
      ..on('POST', '/api/providers/custom-endpoints/validate', {
        'ok': true,
        'reachable': true,
        'models': ['example-model-a'],
      })
      ..on('POST', '/api/providers/custom-endpoints', {
        'ok': true,
        'id': 'lab',
      });
    await everyKeyPath();
    expect(h.tracer.spans.where((s) => s.name == 'HTTP POST'), isNotEmpty);
    _expectClean(h.exported());
  });

  test('a 422 that echoes the key is never read, shown or recorded', () async {
    echoing('POST', '/api/providers/validate', 422);
    echoing('PUT', '/api/env', 422);
    echoing('POST', '/api/providers/custom-endpoints/validate', 422);
    echoing('POST', '/api/providers/custom-endpoints', 422);
    await everyKeyPath();
    expect(h.answers.join(), contains(kNotAcceptedMessage));
    _expectClean(h.exported());
  });

  test('a refusal that echoes the key is replaced', () async {
    for (final (method, path) in [
      ('PUT', '/api/env'),
      ('POST', '/api/providers/custom-endpoints'),
    ]) {
      h.server.on(method, path, {'detail': 'bad value $_secret'}, status: 400);
    }
    h.server.on('POST', '/api/providers/validate', {
      'ok': false,
      'reachable': true,
      'message': 'rejected $_secret',
    });
    await everyKeyPath();
    _expectClean(h.exported());
  });

  test('a server error that echoes the key leaves nothing', () async {
    for (final (method, path) in [
      ('POST', '/api/providers/validate'),
      ('PUT', '/api/env'),
      ('POST', '/api/providers/custom-endpoints/validate'),
      ('POST', '/api/providers/custom-endpoints'),
    ]) {
      h.server.on(method, path, {'detail': _secret}, status: 500);
    }
    await everyKeyPath();
    _expectClean(h.exported());
  });

  test('a lost answer leaves nothing and holds no DioException', () async {
    lost('POST', '/api/providers/validate');
    lost('PUT', '/api/env');
    lost('POST', '/api/providers/custom-endpoints/validate');
    lost('POST', '/api/providers/custom-endpoints');
    await everyKeyPath();
    expect(
      h.answers,
      containsAll([
        startsWith('KeyUnreachable'),
        startsWith('KeySaveUnknown'),
        startsWith('EndpointCheckFailed'),
        startsWith('EndpointSaveUnknown'),
      ]),
    );
    expect(h.answers.join(), isNot(contains('DioException')));
    _expectClean(h.exported());
  });

  test('a check that runs out of time leaves nothing', () async {
    h.server.onRequest('POST', '/api/providers/validate', (_) async {
      await Future<void>.delayed(const Duration(seconds: 5));
      return (status: 200, body: {'ok': true, 'reachable': true});
    });
    h.keep(await h.repository.checkKey('OPENROUTER_API_KEY', _secret));
    expect(h.answers.single, startsWith('KeyUnreachable'));
    _expectClean(h.exported());
  });

  test('the request interceptor records no body', () async {
    h.server
      ..on('PUT', '/api/env', {'ok': true})
      ..on('POST', '/api/providers/validate', {'ok': true, 'reachable': true});
    await h.repository.saveKey('work', 'OPENROUTER_API_KEY', _secret);
    await h.repository.checkKey('OPENROUTER_API_KEY', _secret);
    expect(h.tracer.spans, isNotEmpty);
    expect(h.logger.records, isNotEmpty);
    _expectClean(h.exported());
    for (final span in h.tracer.spans) {
      expect(
        span.attributes.keys.where((k) => k.contains('body')),
        isEmpty,
        reason: span.name,
      );
    }
  });

  test('removing a key and reading providers leave nothing either', () async {
    h.server
      ..on('GET', '/api/model/options', connectedOptions())
      ..on('GET', '/api/env', connectedEnv())
      ..on('DELETE', '/api/env', {'detail': 'locked by policy'}, status: 400);
    await h.repository.load('work');
    final result = await h.repository.removeKey('work', 'OPENROUTER_API_KEY');
    h.keep(result, result is RemoveRefused ? result.message : null);
    _expectClean(h.exported());
  });
}

void _expectClean(String exported) {
  expect(exported, isNot(contains(_secret)));
  expect(exported, isNot(contains(_lastFour)));
  expect(exported, isNot(contains('DioException')));
}
