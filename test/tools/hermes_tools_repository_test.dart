import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';
import 'package:hermes_app/src/tools/hermes_tools_repository.dart';

import '../support/fake_hermes_server.dart';
import '../support/recording_tracer.dart';
import 'tools_fixtures.dart';

Map<String, Object?> body(RequestOptions request) {
  final data = request.data;
  return (data is String ? jsonDecode(data) : data) as Map<String, Object?>;
}

T ok<T>(ToolsResult<T> result) => (result as ToolsOk<T>).value;

void main() {
  late FakeHermesServer server;
  late HermesToolsRepository repository;

  setUp(() {
    server = FakeHermesServer();
    serveToolsReads(server);
    repository = toolsRepository(server);
  });

  group('reads', () {
    test('list parses the rows and sends the profile', () async {
      final result = await repository.list();

      final rows = ok(result).toolsets;
      expect(rows.map((t) => t.name), ['web', 'terminal']);
      expect(
        server.requestsTo('GET', '/api/tools/toolsets').single.queryParameters,
        {'profile': 'work'},
      );
    });

    test(
      'config, models, backends and computer use send the profile',
      () async {
        expect(await repository.config('web'), isA<ToolsOk>());
        expect(
          await repository.models('image_gen', provider: 'Image Co'),
          isA<ToolsOk>(),
        );
        expect(await repository.terminalBackends(), isA<ToolsOk>());
        expect(await repository.computerUseStatus(), isA<ToolsOk>());

        for (final request in server.requests) {
          expect(
            request.queryParameters['profile'],
            'work',
            reason: request.path,
          );
        }
        expect(
          server
              .requestsTo('GET', '/api/tools/toolsets/image_gen/models')
              .single
              .queryParameters['provider'],
          'Image Co',
        );
      },
    );

    test('forProfile binds another profile', () async {
      await repository.forProfile('home').list();

      expect(server.requests.single.queryParameters['profile'], 'home');
    });

    test('a name is encoded into the path', () async {
      server.on('GET', '/api/tools/toolsets/a%2Fb/config', webConfigFixture);

      expect(await repository.config('a/b'), isA<ToolsOk>());
    });
  });

  group('writes send the profile in the query and the body', () {
    test('switch, provider, env, model, install, backend, grant', () async {
      server
        ..on('PUT', '/api/tools/toolsets/web', {
          'ok': true,
          'name': 'web',
          'enabled': true,
          'post_setup_started': 'local_driver',
        })
        ..on('PUT', '/api/tools/toolsets/web/provider', {'ok': true})
        ..on('PUT', '/api/tools/toolsets/web/env', {
          'ok': true,
          'saved': ['SEARCHCO_API_KEY'],
          'skipped': [],
        })
        ..on('PUT', '/api/tools/toolsets/image_gen/model', {'ok': true})
        ..on('POST', '/api/tools/toolsets/web/post-setup', {
          'ok': true,
          'pid': 9,
        })
        ..on('PUT', '/api/tools/terminal/backend', {'ok': true})
        ..on('POST', '/api/tools/computer-use/permissions/grant', {
          'ok': true,
          'pid': 3,
        });

      final switched = await repository.switchToolset('web', enabled: true);
      await repository.pickProvider('web', 'Search Co', capability: 'search');
      await repository.saveEnv('web', {'SEARCHCO_API_KEY': 'typed-value'});
      await repository.pickModel('image_gen', 'fast-1');
      await repository.startPostSetup('web', 'local_driver');
      await repository.pickTerminalBackend('docker');
      await repository.grantComputerUse();

      expect(ok(switched).postSetupStarted, 'local_driver');
      expect(server.requests, hasLength(7));
      for (final request in server.requests) {
        expect(
          request.queryParameters['profile'],
          'work',
          reason: request.path,
        );
        final sent = request.data;
        if (sent != null) {
          expect(body(request)['profile'], 'work', reason: request.path);
        }
      }
      expect(body(server.requests[0]), {'enabled': true, 'profile': 'work'});
      expect(body(server.requests[1])['capability'], 'search');
      expect(body(server.requests[5]), {
        'backend': 'docker',
        'profile': 'work',
      });
    });

    test('the action status routes take no profile', () async {
      server
        ..on('GET', '/api/actions/tools-post-setup/status', {
          'running': true,
          'lines': ['step 1'],
        })
        ..on('GET', '/api/actions/computer-use-grant/status', {
          'running': false,
          'exit_code': 0,
        });

      final install = await repository.postSetupStatus(lines: 6);
      final grant = await repository.grantStatus();

      expect(ok(install).lines, ['step 1']);
      expect(ok(grant).exitCode, 0);
      expect(server.requests.first.queryParameters, {'lines': 6});
      expect(
        server.requests.every((r) => !r.queryParameters.containsKey('profile')),
        isTrue,
      );
    });
  });

  group('failures', () {
    test('404 and 405 are unsupported, not errors', () async {
      server.on('GET', '/api/tools/toolsets', {
        'detail': 'Not Found',
      }, status: 404);
      expect(await repository.list(), isA<ToolsUnsupported>());

      server.on('GET', '/api/tools/toolsets', {'detail': 'x'}, status: 405);
      expect(await repository.list(), isA<ToolsUnsupported>());
    });

    test('a 404 naming a profile is the profile gone', () async {
      server.on('GET', '/api/tools/toolsets', {
        'detail': "Profile 'work' does not exist",
      }, status: 404);

      expect(await repository.list(), isA<ToolsProfileGone>());
    });

    test('a 400 is refused with Hermes\' own text', () async {
      server.on('PUT', '/api/tools/toolsets/nope', {
        'detail': 'Unknown toolset: nope',
      }, status: 400);

      final result = await repository.switchToolset('nope', enabled: true);

      expect(result, isA<ToolsRefused>());
      expect((result as ToolsRefused).detail, 'Unknown toolset: nope');
      expect(result.outcome, 'refused');
    });

    test('401, 403, 422 and 500 are failures of their own kind', () async {
      Future<ToolsFailure?> kind(int status, [Object? body]) async {
        server.on(
          'GET',
          '/api/tools/toolsets',
          body ?? {'detail': 'x'},
          status: status,
        );
        final result = await repository.list();
        return result is ToolsFailed ? (result as ToolsFailed).kind : null;
      }

      expect(await kind(401), ToolsFailure.unauthorized);
      expect(await kind(403), ToolsFailure.unauthorized);
      expect(
        await kind(422, {
          'detail': [
            {'msg': 'bad'},
          ],
        }),
        ToolsFailure.server,
      );
      expect(await kind(500), ToolsFailure.server);
    });

    test(
      'a read that cannot connect is offline, a slow one a timeout',
      () async {
        server.onRequest('GET', '/api/tools/toolsets', (r) {
          throw DioException.connectionError(requestOptions: r, reason: 'down');
        });
        expect(
          (await repository.list() as ToolsFailed).kind,
          ToolsFailure.offline,
        );

        server.onRequest('GET', '/api/tools/toolsets', (r) {
          throw DioException.receiveTimeout(
            timeout: const Duration(seconds: 1),
            requestOptions: r,
          );
        });
        expect(
          (await repository.list() as ToolsFailed).kind,
          ToolsFailure.timeout,
        );
      },
    );

    test('a write whose answer is lost is an unknown outcome', () async {
      server.onRequest('PUT', '/api/tools/toolsets/web', (r) {
        throw DioException.receiveTimeout(
          timeout: const Duration(seconds: 1),
          requestOptions: r,
        );
      });

      final result = await repository.switchToolset('web', enabled: true);

      expect((result as ToolsFailed).kind, ToolsFailure.unknownOutcome);
      expect(result.outcome, 'unknown');
      expect(server.requestsTo('PUT', '/api/tools/toolsets/web'), hasLength(1));
    });

    test('a write that never connected is offline, not unknown', () async {
      server.onRequest('PUT', '/api/tools/toolsets/web', (r) {
        throw DioException.connectionTimeout(
          timeout: const Duration(seconds: 1),
          requestOptions: r,
        );
      });

      final result = await repository.switchToolset('web', enabled: true);

      expect((result as ToolsFailed).kind, ToolsFailure.offline);
    });
  });

  group('telemetry carries counts and outcomes only', () {
    test(
      'list traces its count and outcome; skipped rows are counted',
      () async {
        final tracer = RecordingTracer();
        final events = <String>[];
        server.on('GET', '/api/tools/toolsets', [
          ...toolsetsFixture,
          {'no': 'name'},
        ]);
        final traced = HermesToolsRepository(
          server.client().raw,
          profile: 'work-private',
          telemetry: ConnectionTelemetry(
            tracer: tracer,
            events: (name, [attributes = const {}]) =>
                events.add('$name $attributes'),
          ),
        );

        await traced.list();

        final span = tracer.spans.single;
        expect(span.name, 'tools.list');
        expect(span.attributes, {'count': 2, 'outcome': 'ok'});
        expect(span.ended, isTrue);
        expect(events, ['tools.parse_lenient {skipped: 1}']);
        expect(
          '$span ${span.attributes} $events',
          isNot(contains('work-private')),
        );
      },
    );

    test('a failed list traces the outcome and no count', () async {
      final tracer = RecordingTracer();
      server.on('GET', '/api/tools/toolsets', {'detail': 'x'}, status: 500);
      final traced = HermesToolsRepository(
        server.client().raw,
        profile: 'work',
        telemetry: ConnectionTelemetry(tracer: tracer),
      );

      await traced.list();

      expect(tracer.spans.single.attributes, {'outcome': 'failed'});
    });
  });
}
