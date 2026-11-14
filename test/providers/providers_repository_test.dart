import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/providers/provider_models.dart';
import 'package:hermes_app/src/providers/provider_results.dart';
import 'package:hermes_app/src/providers/providers_repository.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';

import '../support/fake_hermes_server.dart';
import '../support/recording_tracer.dart';
import 'provider_fixtures.dart';

const _routes = {
  ProviderSource.options: '/api/model/options',
  ProviderSource.env: '/api/env',
  ProviderSource.oauth: '/api/providers/oauth',
  ProviderSource.endpoints: '/api/providers/custom-endpoints',
  ProviderSource.pool: '/api/credentials/pool',
};

FakeHermesServer connectedServer() => FakeHermesServer()
  ..on('GET', '/api/model/options', connectedOptions())
  ..on('GET', '/api/env', connectedEnv())
  ..on('GET', '/api/providers/oauth', connectedOauth())
  ..on('GET', '/api/providers/custom-endpoints', oneEndpoint())
  ..on('GET', '/api/credentials/pool', connectedPool());

ProvidersRepository repositoryOn(
  FakeHermesServer server, {
  ConnectionTelemetry telemetry = const ConnectionTelemetry(),
}) => ProvidersRepository(server.client().raw, telemetry: telemetry);

void main() {
  group('load', () {
    test('merges the five answers', () async {
      final server = connectedServer();
      final snapshot = await repositoryOn(server).load('work');
      expect(snapshot, isA<ProvidersLoaded>());
      final loaded = snapshot as ProvidersLoaded;
      expect(loaded.catalog.connected.map((e) => e.id), [
        'openrouter',
        'openai-codex',
        'lab',
      ]);
      for (final source in ProviderSource.values) {
        expect(loaded.state(source), isA<SourceOk>(), reason: source.name);
      }
    });

    test('every request carries the profile, the options the flag', () async {
      final server = connectedServer();
      await repositoryOn(server).load('work');
      for (final entry in _routes.entries) {
        final request = server.requestsTo('GET', entry.value).single;
        expect(request.queryParameters['profile'], 'work', reason: entry.value);
      }
      final options = server.requestsTo('GET', '/api/model/options').single;
      expect(options.queryParameters['include_unconfigured'], true);
    });

    test('a server without profiles gets no profile parameter', () async {
      final server = connectedServer();
      await repositoryOn(server).load(null);
      for (final request in server.requests) {
        expect(request.queryParameters, isNot(contains('profile')));
      }
    });

    test('reads the sources in parallel', () async {
      final server = connectedServer();
      var inFlight = 0;
      var peak = 0;
      for (final path in _routes.values) {
        server.onRequest('GET', path, (_) async {
          inFlight++;
          if (inFlight > peak) peak = inFlight;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          inFlight--;
          return (status: 200, body: <String, Object?>{});
        });
      }
      await repositoryOn(server).load('work');
      expect(peak, 5);
    });

    test('options answering 404 is unsupported', () async {
      final server = connectedServer()
        ..on('GET', '/api/model/options', {'detail': 'Not Found'}, status: 404);
      expect(
        await repositoryOn(server).load('work'),
        isA<ProvidersUnsupported>(),
      );
    });

    test('options failing fails the whole snapshot', () async {
      final server = connectedServer()
        ..on('GET', '/api/model/options', {'detail': 'boom'}, status: 500);
      final snapshot = await repositoryOn(server).load('work');
      expect(snapshot, isA<ProvidersFailed>());
      expect((snapshot as ProvidersFailed).reason, ReadFailure.server);
    });

    test('a restart-required answer is told apart', () async {
      final server = connectedServer()
        ..on('GET', '/api/model/options', {
          'detail': 'Restart required: code changed',
        }, status: 503);
      final snapshot = await repositoryOn(server).load('work');
      expect((snapshot as ProvidersFailed).reason, ReadFailure.restartRequired);
    });

    test('options that are no object fail as malformed', () async {
      final server = connectedServer()..on('GET', '/api/model/options', ['x']);
      final snapshot = await repositoryOn(server).load('work');
      expect((snapshot as ProvidersFailed).reason, ReadFailure.malformed);
    });

    test('no connection fails as unreachable', () async {
      final server = connectedServer()
        ..onRequest('GET', '/api/model/options', (request) {
          throw DioException.connectionError(
            requestOptions: request,
            reason: 'offline',
          );
        });
      final snapshot = await repositoryOn(server).load('work');
      expect((snapshot as ProvidersFailed).reason, ReadFailure.unreachable);
    });

    for (final source in ProviderSource.values.skip(1)) {
      test(
        'a 404 on ${source.name} is not offered, the rest still load',
        () async {
          final server = connectedServer()
            ..on('GET', _routes[source]!, {'detail': 'Not Found'}, status: 404);
          final loaded =
              await repositoryOn(server).load('work') as ProvidersLoaded;
          expect(loaded.state(source), isA<SourceNotOffered>());
          expect(loaded.offered(source), isFalse);
          expect(loaded.failed(source), isFalse);
          expect(loaded.catalog.entries, isNotEmpty);
        },
      );

      test(
        'a failure on ${source.name} degrades without hiding the rest',
        () async {
          final server = connectedServer()
            ..on('GET', _routes[source]!, {'detail': 'boom'}, status: 500);
          final loaded =
              await repositoryOn(server).load('work') as ProvidersLoaded;
          expect(loaded.failed(source), isTrue);
          for (final other in ProviderSource.values) {
            if (other != source) expect(loaded.failed(other), isFalse);
          }
          expect(loaded.catalog.byId('openrouter'), isNotNull);
        },
      );
    }

    test('without the env source a skeleton key is still addable', () async {
      final server = FakeHermesServer()
        ..on('GET', '/api/model/options', emptyProfileOptions())
        ..on('GET', '/api/env', {'detail': 'x'}, status: 500);
      final loaded = await repositoryOn(server).load('work') as ProvidersLoaded;
      final router = loaded.catalog.byId('openrouter')!;
      expect(router.method, ConnectMethod.key);
      expect(router.keyEnv, 'OPENROUTER_API_KEY');
    });
  });

  group('pool', () {
    test('is only ever read: no request deletes a pool entry', () async {
      final server = connectedServer()
        ..on('PUT', '/api/env', {'ok': true})
        ..on('DELETE', '/api/env', {'ok': true})
        ..on('POST', '/api/providers/validate', {'ok': true, 'reachable': true})
        ..on('POST', '/api/providers/custom-endpoints', {'ok': true, 'id': 'a'})
        ..on('POST', '/api/providers/custom-endpoints/validate', {})
        ..on('POST', '/api/providers/custom-endpoints/a/activate', {'ok': true})
        ..on('DELETE', '/api/providers/custom-endpoints/a', {'ok': true})
        ..on('POST', '/api/providers/oauth/nous/start', {})
        ..on('GET', '/api/providers/oauth/nous/poll/s', {})
        ..on('DELETE', '/api/providers/oauth/sessions/s', {'ok': true})
        ..on('DELETE', '/api/providers/oauth/nous', {'ok': true})
        ..on('GET', '/api/model/recommended-default', {})
        ..on('POST', '/api/model/set', {'ok': true});
      final repository = repositoryOn(server);
      await repository.load('p');
      await repository.checkKey('K', 'v');
      await repository.saveKey('p', 'K', 'v');
      await repository.removeKey('p', 'K');
      await repository.signOut('p', 'nous');
      await repository.recommendedDefault('p', 'nous');
      await repository.setDefaultModel('p', 'nous', 'm');
      await repository.startSignIn('p', 'nous');
      await repository.pollSignIn('p', 'nous', 's');
      await repository.cancelSignIn('p', 's');
      await repository.checkEndpoint(name: 'a', baseUrl: 'http://x');
      await repository.saveEndpoint('p', name: 'a', baseUrl: 'http://x');
      await repository.activateEndpoint('p', 'a');
      await repository.deleteEndpoint('p', 'a');
      expect(server.requests, hasLength(greaterThan(15)));
      expect(
        server.requests.where(
          (r) =>
              r.method == 'DELETE' &&
              r.path.startsWith('/api/credentials/pool'),
        ),
        isEmpty,
      );
      expect(
        server.requests.where((r) => r.path.contains('/api/env/reveal')),
        isEmpty,
      );
      expect(
        server.requests.where(
          (r) => r.method == 'POST' && r.path == '/api/credentials/pool',
        ),
        isEmpty,
      );
    });
  });

  group('telemetry', () {
    test('providers.load carries only the tallies and the bucket', () async {
      final tracer = RecordingTracer();
      final events = <(String, Map<String, Object>)>[];
      final telemetry = ConnectionTelemetry(
        tracer: tracer,
        serverAttributes: const {'hermes.version': 'test'},
        events: (name, [attributes = const {}]) =>
            events.add((name, attributes)),
      );
      await repositoryOn(
        connectedServer(),
        telemetry: telemetry,
      ).load('private-profile');
      final span = tracer.spans.single;
      expect(span.name, 'providers.load');
      expect(span.ended, isTrue);
      expect(span.attributes, {
        'hermes.version': 'test',
        'sources_ok': 4,
        'sources_failed': 0,
        'connected': '2-5',
      });
      expect(events, isEmpty);
    });

    test('the connected count is bucketed', () async {
      Future<Object?> bucketFor(Map<String, Object?> options) async {
        final tracer = RecordingTracer();
        final server = FakeHermesServer()
          ..on('GET', '/api/model/options', options);
        await repositoryOn(
          server,
          telemetry: ConnectionTelemetry(tracer: tracer),
        ).load(null);
        return tracer.spans.single.attributes['connected'];
      }

      expect(await bucketFor(emptyProfileOptions()), '0');
      expect(
        await bucketFor(optionsBody([optionsRow('a', current: true)])),
        '1',
      );
      expect(
        await bucketFor(
          optionsBody([for (final s in 'abcdefg'.split('')) optionsRow(s)]),
        ),
        '>5',
      );
    });

    test(
      'providers.read_failed names the source and the error kind only',
      () async {
        final tracer = RecordingTracer();
        final events = <(String, Map<String, Object>)>[];
        final server = connectedServer()
          ..on('GET', '/api/env', {'detail': 'secret detail'}, status: 500)
          ..on('GET', '/api/providers/oauth', ['x'])
          ..on('GET', '/api/providers/custom-endpoints', {}, status: 404);
        await repositoryOn(
          server,
          telemetry: ConnectionTelemetry(
            tracer: tracer,
            events: (name, [attributes = const {}]) =>
                events.add((name, attributes)),
          ),
        ).load('private-profile');
        expect(
          [for (final (name, attrs) in events) '$name $attrs'],
          [
            'providers.read_failed {source: env, error_type: badResponse}',
            'providers.read_failed {source: oauth, error_type: malformed}',
          ],
        );
        final span = tracer.spans.single;
        expect(span.attributes['sources_ok'], 1);
        expect(span.attributes['sources_failed'], 2);
        expect(
          '${span.attributes} $events',
          isNot(anyOf(contains('private-profile'), contains('secret detail'))),
        );
      },
    );

    test('a failed options read still ends its span', () async {
      final tracer = RecordingTracer();
      final server = connectedServer()
        ..on('GET', '/api/model/options', {}, status: 500);
      await repositoryOn(
        server,
        telemetry: ConnectionTelemetry(tracer: tracer),
      ).load(null);
      final span = tracer.spans.single;
      expect(span.ended, isTrue);
      expect(span.attributes, isNot(contains('connected')));
    });

    test('a broken tracer and logger do not break the load', () async {
      final loaded = await repositoryOn(
        connectedServer()..on('GET', '/api/env', {}, status: 500),
        telemetry: ConnectionTelemetry(
          tracer: ThrowingTracer(),
          events: (_, [attributes = const {}]) => throw StateError('telemetry'),
        ),
      ).load(null);
      expect(loaded, isA<ProvidersLoaded>());
    });
  });
}
