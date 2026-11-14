import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/providers/provider_results.dart';
import 'package:hermes_app/src/providers/providers_repository.dart';

import '../support/fake_hermes_server.dart';

void main() {
  late FakeHermesServer server;
  late ProvidersRepository repository;

  setUp(() {
    server = FakeHermesServer();
    repository = ProvidersRepository(server.client().raw);
  });

  void lostAnswer(String method, String path) =>
      server.onRequest(method, path, (request) {
        throw DioException.connectionError(
          requestOptions: request,
          reason: 'offline',
        );
      });

  Map<String, Object?> sentJson(String method, String path) =>
      Map<String, Object?>.from(
        jsonBody(server.requestsTo(method, path).single)! as Map,
      );

  group('startSignIn', () {
    const path = '/api/providers/oauth/nous/start';

    test('reads the session with the profile', () async {
      server.on('POST', path, {
        'session_id': 's-1',
        'flow': 'device_code',
        'user_code': 'ABCD-1234',
        'verification_url': 'https://portal.example.com/device?code=ABCD-1234',
        'expires_in': 900,
        'poll_interval': 5,
      });
      final result = await repository.startSignIn('work', 'nous');
      final session = (result as SignInStarted).session;
      expect(session.sessionId, 's-1');
      expect(session.userCode, 'ABCD-1234');
      expect(session.verificationUrl, contains('portal.example.com'));
      expect(session.expiresIn, 900);
      expect(session.pollInterval, 5);
      expect(
        server.requestsTo('POST', path).single.queryParameters['profile'],
        'work',
      );
    });

    test('an answer without a code is a refusal', () async {
      server.on('POST', path, {'session_id': 's-1'});
      expect(
        await repository.startSignIn('w', 'nous'),
        isA<SignInStartRefused>(),
      );
    });

    test('Hermes\' sentence comes through, for a 400 and a 504', () async {
      server.on('POST', path, {
        'detail': 'Already signed in to Nous Portal.',
      }, status: 400);
      final already = await repository.startSignIn('w', 'nous');
      expect(
        (already as SignInStartRefused).message,
        'Already signed in to Nous Portal.',
      );
      server.on('POST', path, {
        'detail': 'device-auth timed out before returning a user code',
      }, status: 504);
      final slow = await repository.startSignIn('w', 'nous');
      expect((slow as SignInStartRefused).message, contains('timed out'));
    });

    test('a 422 is never read', () async {
      server.on('POST', path, {
        'detail': [
          {'input': 'anything'},
        ],
      }, status: 422);
      final result = await repository.startSignIn('w', 'nous');
      expect((result as SignInStartRefused).message, kNotAcceptedMessage);
    });

    test('no answer is a failure', () async {
      lostAnswer('POST', path);
      expect(
        await repository.startSignIn('w', 'nous'),
        isA<SignInStartFailed>(),
      );
    });

    test('encodes the provider id', () async {
      const encoded = '/api/providers/oauth/custom%3Afoo/start';
      server.on('POST', encoded, {
        'session_id': 's',
        'user_code': 'C',
        'verification_url': 'https://x.example.com',
      });
      expect(
        await repository.startSignIn('w', 'custom:foo'),
        isA<SignInStarted>(),
      );
      expect(server.requestsTo('POST', encoded), hasLength(1));
    });
  });

  group('pollSignIn', () {
    const path = '/api/providers/oauth/nous/poll/s-1';

    test('reads each status', () async {
      for (final (wire, status) in [
        ('pending', SignInStatus.pending),
        ('approved', SignInStatus.approved),
        ('denied', SignInStatus.denied),
        ('expired', SignInStatus.expired),
        ('error', SignInStatus.error),
        ('cancelled', SignInStatus.cancelled),
        ('something new', SignInStatus.pending),
      ]) {
        server.on('GET', path, {'session_id': 's-1', 'status': wire});
        final result = await repository.pollSignIn('w', 'nous', 's-1');
        expect((result as SignInPolled).status, status, reason: wire);
      }
    });

    test('carries the error, the email and the retry hint', () async {
      server.on('GET', path, {
        'status': 'error',
        'error_message': 'The provider said no.',
        'account_email': 'ada@example.com',
        'retry_after': 3,
      });
      final result =
          await repository.pollSignIn('work', 'nous', 's-1') as SignInPolled;
      expect(result.errorMessage, 'The provider said no.');
      expect(result.accountEmail, 'ada@example.com');
      expect(result.retryAfter, 3);
      expect(
        server.requestsTo('GET', path).single.queryParameters['profile'],
        'work',
      );
    });

    test('404 means the session is gone', () async {
      server.on('GET', path, {'detail': 'unknown'}, status: 404);
      expect(
        await repository.pollSignIn('w', 'nous', 's-1'),
        isA<SignInGone>(),
      );
    });

    test('other failures keep waiting', () async {
      server.on('GET', path, {}, status: 500);
      expect(
        await repository.pollSignIn('w', 'nous', 's-1'),
        isA<SignInPollFailed>(),
      );
      server.on('GET', path, {}, status: 400);
      expect(
        await repository.pollSignIn('w', 'nous', 's-1'),
        isA<SignInPollFailed>(),
      );
      lostAnswer('GET', path);
      expect(
        await repository.pollSignIn('w', 'nous', 's-1'),
        isA<SignInPollFailed>(),
      );
    });

    test('encodes the provider and the session id', () async {
      const encoded = '/api/providers/oauth/custom%3Afoo/poll/a%2Fb%3Ac';
      server.on('GET', encoded, {'status': 'pending'});
      await repository.pollSignIn('w', 'custom:foo', 'a/b:c');
      expect(server.requestsTo('GET', encoded), hasLength(1));
    });
  });

  group('cancelSignIn', () {
    const path = '/api/providers/oauth/sessions/s-1';

    test('cancels with the profile', () async {
      server.on('DELETE', path, {'ok': true});
      expect(
        await repository.cancelSignIn('work', 's-1'),
        SignInCancel.cancelled,
      );
      expect(
        server.requestsTo('DELETE', path).single.queryParameters['profile'],
        'work',
      );
    });

    test('an unknown session is not found, a failure is a failure', () async {
      server.on('DELETE', path, {'ok': false, 'message': 'session not found'});
      expect(await repository.cancelSignIn('w', 's-1'), SignInCancel.notFound);
      server.on('DELETE', path, {}, status: 404);
      expect(await repository.cancelSignIn('w', 's-1'), SignInCancel.notFound);
      lostAnswer('DELETE', path);
      expect(await repository.cancelSignIn('w', 's-1'), SignInCancel.failed);
    });

    test('encodes the session id', () async {
      const encoded = '/api/providers/oauth/sessions/a%2Fb';
      server.on('DELETE', encoded, {'ok': true});
      await repository.cancelSignIn('w', 'a/b');
      expect(server.requestsTo('DELETE', encoded), hasLength(1));
    });
  });

  group('checkEndpoint', () {
    const path = '/api/providers/custom-endpoints/validate';

    test('sends the required fields and no profile', () async {
      server.on('POST', path, {'ok': true, 'reachable': true, 'models': []});
      await repository.checkEndpoint(
        name: 'Lab',
        baseUrl: 'http://127.0.0.1:8283',
      );
      final body = sentJson('POST', path);
      expect(body['name'], 'Lab');
      expect(body['base_url'], 'http://127.0.0.1:8283');
      expect(body['model'], '');
      expect(body, isNot(contains('api_key')));
      expect(body, isNot(contains('api_mode')));
      expect(server.requestsTo('POST', path).single.queryParameters, isEmpty);
    });

    test('sends a typed key and the API type', () async {
      server.on('POST', path, {'ok': true, 'reachable': true});
      await repository.checkEndpoint(
        name: 'Lab',
        baseUrl: 'https://lab.example.com',
        apiKey: 'typed-key-123456',
        apiMode: 'chat_completions',
      );
      final body = sentJson('POST', path);
      expect(body['api_key'], 'typed-key-123456');
      expect(body['api_mode'], 'chat_completions');
    });

    test('models found, with the address that answered', () async {
      server.on('POST', path, {
        'ok': true,
        'reachable': true,
        'models': ['example-model-a', 'example-model-b'],
        'resolved_base_url': 'http://127.0.0.1:8283/v1',
        'message': '',
      });
      final result = await repository.checkEndpoint(
        name: 'a',
        baseUrl: 'http://127.0.0.1:8283',
      ) as EndpointChecked;
      expect(result.models, ['example-model-a', 'example-model-b']);
      expect(result.resolvedBaseUrl, 'http://127.0.0.1:8283/v1');
      expect(result.warning, isNull);
    });

    test('a warning is reachable but not ok', () async {
      server.on('POST', path, {
        'ok': false,
        'reachable': true,
        'message': 'The endpoint answered 401.',
        'models': [],
      });
      final result = await repository.checkEndpoint(
        name: 'a',
        baseUrl: 'http://x',
      ) as EndpointChecked;
      expect(result.warning, 'The endpoint answered 401.');
      expect(result.models, isEmpty);
    });

    test('unreachable, and a check that fails', () async {
      server.on('POST', path, {'ok': false, 'reachable': false});
      expect(
        await repository.checkEndpoint(name: 'a', baseUrl: 'http://x'),
        isA<EndpointUnreachable>(),
      );
      server.on('POST', path, {}, status: 500);
      expect(
        await repository.checkEndpoint(name: 'a', baseUrl: 'http://x'),
        isA<EndpointCheckFailed>(),
      );
      server.on('POST', path, {
        'detail': [
          {'input': 'k'},
        ],
      }, status: 422);
      expect(
        await repository.checkEndpoint(name: 'a', baseUrl: 'http://x'),
        isA<EndpointCheckFailed>(),
      );
      lostAnswer('POST', path);
      expect(
        await repository.checkEndpoint(name: 'a', baseUrl: 'http://x'),
        isA<EndpointCheckFailed>(),
      );
    });
  });

  group('saveEndpoint', () {
    const path = '/api/providers/custom-endpoints';

    test('sends every required field, model empty before a pick', () async {
      server.on('POST', path, {'ok': true, 'id': 'lab', 'endpoints': []});
      final result = await repository.saveEndpoint(
        'work',
        name: 'Lab',
        baseUrl: 'http://127.0.0.1:8283/v1',
      );
      expect((result as EndpointSaved).id, 'lab');
      final body = sentJson('POST', path);
      expect(body['name'], 'Lab');
      expect(body['base_url'], 'http://127.0.0.1:8283/v1');
      expect(body['model'], '');
      expect(
        server.requestsTo('POST', path).single.queryParameters['profile'],
        'work',
      );
    });

    test('the key is omitted unless touched, empty only to clear', () async {
      server.on('POST', path, {'ok': true, 'id': 'lab'});
      await repository.saveEndpoint('w', name: 'Lab', baseUrl: 'http://x');
      expect(sentJson('POST', path), isNot(contains('api_key')));
      server.requests.clear();
      await repository.saveEndpoint(
        'w',
        name: 'Lab',
        baseUrl: 'http://x',
        apiKey: '',
      );
      expect(sentJson('POST', path)['api_key'], '');
      server.requests.clear();
      await repository.saveEndpoint(
        'w',
        name: 'Lab',
        baseUrl: 'http://x',
        apiKey: 'typed-key-123456',
      );
      expect(sentJson('POST', path)['api_key'], 'typed-key-123456');
    });

    test('carries the optional fields it was given', () async {
      server.on('POST', path, {'ok': true, 'id': 'lab'});
      await repository.saveEndpoint(
        'w',
        id: 'lab',
        name: 'Lab',
        baseUrl: 'http://x',
        model: 'example-model-a',
        apiMode: '',
        contextLength: 8192,
        discoverModels: false,
        makeDefault: true,
        models: ['example-model-a'],
      );
      final body = sentJson('POST', path);
      expect(body['id'], 'lab');
      expect(body['model'], 'example-model-a');
      expect(body['api_mode'], '');
      expect(body['context_length'], 8192);
      expect(body['discover_models'], false);
      expect(body['make_default'], true);
      expect(body['models'], ['example-model-a']);
    });

    test('refused with Hermes\' reason, or the fixed 422 sentence', () async {
      server.on('POST', path, {
        'detail': 'base_url must include scheme and host',
      }, status: 400);
      final refused = await repository.saveEndpoint(
        'w',
        name: 'a',
        baseUrl: 'x',
      );
      expect(
        (refused as EndpointRefused).message,
        'base_url must include scheme and host',
      );
      server.on('POST', path, {
        'detail': [
          {
            'input': {'api_key': 'typed-key-123456'},
          },
        ],
      }, status: 422);
      final invalid = await repository.saveEndpoint(
        'w',
        name: 'a',
        baseUrl: 'x',
        apiKey: 'typed-key-123456',
      );
      expect((invalid as EndpointRefused).message, kNotAcceptedMessage);
    });

    test('a lost answer is unknown and never resent', () async {
      lostAnswer('POST', path);
      expect(
        await repository.saveEndpoint('w', name: 'a', baseUrl: 'http://x'),
        isA<EndpointSaveUnknown>(),
      );
      expect(server.requestsTo('POST', path), hasLength(1));
    });
  });

  group('activateEndpoint and deleteEndpoint', () {
    const id = 'local-127.0.0.1:8283';
    const encoded = 'local-127.0.0.1%3A8283';

    test('activate encodes the id and sends the profile', () async {
      const path = '/api/providers/custom-endpoints/$encoded/activate';
      server.on('POST', path, {
        'ok': true,
        'provider': 'custom:x',
        'model': 'm',
      });
      expect(
        await repository.activateEndpoint('work', id),
        isA<EndpointActivated>(),
      );
      expect(server.requestsTo('POST', path), hasLength(1));
      expect(
        server.requestsTo('POST', path).single.queryParameters['profile'],
        'work',
      );
    });

    test('activate refusals and failures', () async {
      const path = '/api/providers/custom-endpoints/$encoded/activate';
      server.on('POST', path, {
        'detail': 'endpoint is incomplete',
      }, status: 400);
      final refused = await repository.activateEndpoint('w', id);
      expect(
        (refused as EndpointActivationRefused).message,
        'endpoint is incomplete',
      );
      server.on('POST', path, {}, status: 500);
      expect(
        await repository.activateEndpoint('w', id),
        isA<EndpointActivationFailed>(),
      );
    });

    test('delete encodes the id, 404 is already gone', () async {
      const path = '/api/providers/custom-endpoints/$encoded';
      server.on('DELETE', path, {'ok': true});
      expect(await repository.deleteEndpoint('work', id), isA<Removed>());
      expect(server.requestsTo('DELETE', path), hasLength(1));
      expect(
        server.requestsTo('DELETE', path).single.queryParameters['profile'],
        'work',
      );
      server.on('DELETE', path, {'detail': 'unknown'}, status: 404);
      expect(await repository.deleteEndpoint('w', id), isA<AlreadyGone>());
      lostAnswer('DELETE', path);
      expect(await repository.deleteEndpoint('w', id), isA<RemoveUnknown>());
    });

    test('a slug with a colon is encoded, not read as a scheme', () async {
      const path = '/api/providers/custom-endpoints/custom%3Afoo';
      server.on('DELETE', path, {'ok': true});
      await repository.deleteEndpoint('w', 'custom:foo');
      expect(server.requestsTo('DELETE', path), hasLength(1));
    });
  });
}
