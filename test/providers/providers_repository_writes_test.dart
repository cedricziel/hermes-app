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
    repository = ProvidersRepository(
      server.client().raw,
      checkBudget: const Duration(milliseconds: 80),
      recommendBudget: const Duration(milliseconds: 80),
    );
  });

  Object? sentBody(String method, String path) =>
      jsonBody(server.requestsTo(method, path).single);

  void lostAnswer(String method, String path) =>
      server.onRequest(method, path, (request) {
        throw DioException.connectionError(
          requestOptions: request,
          reason: 'offline',
        );
      });

  group('checkKey', () {
    const path = '/api/providers/validate';

    test('sends the variable and the value, with no profile', () async {
      server.on('POST', path, {'ok': true, 'reachable': true, 'message': ''});
      await repository.checkKey('OPENROUTER_API_KEY', 'test-value-123456');
      expect(sentBody('POST', path), {
        'key': 'OPENROUTER_API_KEY',
        'value': 'test-value-123456',
      });
      expect(server.requestsTo('POST', path).single.queryParameters, isEmpty);
    });

    test('accepted', () async {
      server.on('POST', path, {'ok': true, 'reachable': true, 'message': ''});
      expect(
        await repository.checkKey('K', 'test-value-123456'),
        isA<KeyAccepted>(),
      );
    });

    test('a key with no probe is unchecked', () async {
      server.on('POST', path, {'ok': true, 'reachable': false, 'message': ''});
      expect(
        await repository.checkKey('K', 'test-value-123456'),
        isA<KeyUnchecked>(),
      );
    });

    test('rejected carries Hermes\' message', () async {
      server.on('POST', path, {
        'ok': false,
        'reachable': true,
        'message': 'That API key was rejected. Double-check it and try again.',
      });
      final result = await repository.checkKey('K', 'test-value-123456');
      expect(result, isA<KeyRejected>());
      expect(
        (result as KeyRejected).message,
        'That API key was rejected. Double-check it and try again.',
      );
    });

    test('a provider error is told apart by the message prefix', () async {
      server.on('POST', path, {
        'ok': false,
        'reachable': true,
        'message': 'Provider returned HTTP 503 for this key.',
      });
      final result = await repository.checkKey('K', 'test-value-123456');
      expect(result, isA<KeyProviderError>());
      expect(
        (result as KeyProviderError).message,
        'Provider returned HTTP 503 for this key.',
      );
    });

    test('unreachable', () async {
      server.on('POST', path, {
        'ok': false,
        'reachable': false,
        'message': 'Could not reach the provider to verify the key.',
      });
      expect(
        await repository.checkKey('K', 'test-value-123456'),
        isA<KeyUnreachable>(),
      );
    });

    test(
      'a failing or garbled check is unreachable, a 404 unchecked',
      () async {
        server.on('POST', path, {'detail': 'x'}, status: 500);
        expect(
          await repository.checkKey('K', 'test-value-123456'),
          isA<KeyUnreachable>(),
        );
        server.on('POST', path, ['x']);
        expect(
          await repository.checkKey('K', 'test-value-123456'),
          isA<KeyUnreachable>(),
        );
        server.on('POST', path, {'detail': 'Not Found'}, status: 404);
        expect(
          await repository.checkKey('K', 'test-value-123456'),
          isA<KeyUnchecked>(),
        );
        lostAnswer('POST', path);
        expect(
          await repository.checkKey('K', 'test-value-123456'),
          isA<KeyUnreachable>(),
        );
      },
    );

    test('gives up after its budget', () async {
      server.onRequest('POST', path, (_) async {
        await Future<void>.delayed(const Duration(seconds: 5));
        return (status: 200, body: {'ok': true, 'reachable': true});
      });
      final watch = Stopwatch()..start();
      expect(
        await repository.checkKey('K', 'test-value-123456'),
        isA<KeyUnreachable>(),
      );
      expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
    });

    test('a message that echoes the key is not passed on', () async {
      server.on('POST', path, {
        'ok': false,
        'reachable': true,
        'message': 'rejected sk-secret-value',
      });
      final result =
          await repository.checkKey('K', 'sk-secret-value') as KeyRejected;
      expect(result.message, isEmpty);
    });
  });

  group('saveKey', () {
    const path = '/api/env';

    test('sends provider_setup with the profile as a query', () async {
      server.on('PUT', path, {'ok': true, 'key': 'K', 'config_updates': []});
      expect(await repository.saveKey('work', 'K', 'v'), isA<KeySaved>());
      expect(sentBody('PUT', path), {
        'key': 'K',
        'value': 'v',
        'provider_setup': true,
      });
      expect(
        server.requestsTo('PUT', path).single.queryParameters['profile'],
        'work',
      );
    });

    test('no profile for a server without profiles', () async {
      server.on('PUT', path, {'ok': true});
      await repository.saveKey(null, 'K', 'v');
      expect(
        server.requestsTo('PUT', path).single.queryParameters,
        isNot(contains('profile')),
      );
    });

    test('a refusal carries Hermes\' reason', () async {
      server.on('PUT', path, {
        'detail': 'This key is managed by your administrator.',
      }, status: 400);
      final result = await repository.saveKey('work', 'K', 'v');
      expect(result, isA<KeyRefused>());
      expect(
        (result as KeyRefused).message,
        'This key is managed by your administrator.',
      );
    });

    test('a 422 is never read: a fixed sentence', () async {
      server.on('PUT', path, {
        'detail': [
          {
            'type': 'missing',
            'input': {'key': 'K', 'value': 'sk-secret'},
          },
        ],
      }, status: 422);
      final result = await repository.saveKey('work', 'K', 'sk-secret');
      expect((result as KeyRefused).message, kNotAcceptedMessage);
    });

    test('a detail echoing the key is replaced', () async {
      server.on('PUT', path, {'detail': 'bad sk-secret'}, status: 400);
      final result = await repository.saveKey('work', 'K', 'sk-secret');
      expect((result as KeyRefused).message, isNot(contains('sk-secret')));
    });

    test(
      'a lost answer or a server error is unknown and never resent',
      () async {
        lostAnswer('PUT', path);
        expect(await repository.saveKey('w', 'K', 'v'), isA<KeySaveUnknown>());
        expect(server.requestsTo('PUT', path), hasLength(1));
        server.on('PUT', path, {'detail': 'boom'}, status: 500);
        expect(await repository.saveKey('w', 'K', 'v'), isA<KeySaveUnknown>());
        expect(server.requestsTo('PUT', path), hasLength(2));
      },
    );

    test('an answer that says nothing is unknown', () async {
      server.on('PUT', path, 'not json at all');
      expect(await repository.saveKey('w', 'K', 'v'), isA<KeySaveUnknown>());
    });
  });

  group('removeKey', () {
    const path = '/api/env';

    test('sends the variable with the profile', () async {
      server.on('DELETE', path, {'ok': true});
      expect(await repository.removeKey('work', 'K'), isA<Removed>());
      expect(sentBody('DELETE', path), {'key': 'K'});
      expect(
        server.requestsTo('DELETE', path).single.queryParameters['profile'],
        'work',
      );
    });

    test('404 is already gone', () async {
      server.on('DELETE', path, {'detail': 'K not found in .env'}, status: 404);
      expect(await repository.removeKey('work', 'K'), isA<AlreadyGone>());
    });

    test('a locked key is refused with Hermes\' reason', () async {
      server.on('DELETE', path, {'detail': 'locked by policy'}, status: 400);
      final result = await repository.removeKey('work', 'K');
      expect((result as RemoveRefused).message, 'locked by policy');
    });

    test('a lost answer is unknown', () async {
      lostAnswer('DELETE', path);
      expect(await repository.removeKey('work', 'K'), isA<RemoveUnknown>());
    });
  });

  group('signOut', () {
    test('removes the account of the profile', () async {
      const path = '/api/providers/oauth/openai-codex';
      server.on('DELETE', path, {'ok': true, 'provider': 'openai-codex'});
      expect(await repository.signOut('work', 'openai-codex'), isA<Removed>());
      expect(
        server.requestsTo('DELETE', path).single.queryParameters['profile'],
        'work',
      );
    });

    test('404 is already gone', () async {
      server.on('DELETE', '/api/providers/oauth/nous', {}, status: 404);
      expect(await repository.signOut('w', 'nous'), isA<AlreadyGone>());
    });

    test(
      '409 and a provider that is not disconnectable are refusals',
      () async {
        server.on('DELETE', '/api/providers/oauth/nous', {
          'detail': 'No stored credentials were removed for nous',
        }, status: 409);
        final conflict = await repository.signOut('w', 'nous');
        expect(
          (conflict as RemoveRefused).message,
          'No stored credentials were removed for nous',
        );
        server.on('DELETE', '/api/providers/oauth/nous', {
          'detail': 'Remove the API key from Settings → Keys instead.',
        }, status: 400);
        final refused = await repository.signOut('w', 'nous');
        expect((refused as RemoveRefused).message, contains('Settings'));
      },
    );

    test('a failing server is unknown', () async {
      server.on('DELETE', '/api/providers/oauth/nous', {}, status: 500);
      expect(await repository.signOut('w', 'nous'), isA<RemoveUnknown>());
    });

    test('encodes the provider id', () async {
      const path = '/api/providers/oauth/custom%3Afoo';
      server.on('DELETE', path, {'ok': true});
      expect(await repository.signOut('w', 'custom:foo'), isA<Removed>());
      expect(server.requestsTo('DELETE', path), hasLength(1));
    });
  });

  group('recommendedDefault', () {
    const path = '/api/model/recommended-default';

    test('asks for the provider and the profile', () async {
      server.on('GET', path, {
        'provider': 'openrouter',
        'model': 'example-model-a',
        'free_tier': true,
      });
      final result = await repository.recommendedDefault('work', 'openrouter');
      expect(result!.model, 'example-model-a');
      expect(result.freeTier, isTrue);
      final query = server.requestsTo('GET', path).single.queryParameters;
      expect(query['provider'], 'openrouter');
      expect(query['profile'], 'work');
    });

    test(
      'an empty model, a failure and a stall are no recommendation',
      () async {
        server.on('GET', path, {'provider': 'x', 'model': ''});
        expect(await repository.recommendedDefault('w', 'x'), isNull);
        server.on('GET', path, {}, status: 500);
        expect(await repository.recommendedDefault('w', 'x'), isNull);
        server.onRequest('GET', path, (_) async {
          await Future<void>.delayed(const Duration(seconds: 5));
          return (status: 200, body: {'model': 'late'});
        });
        expect(await repository.recommendedDefault('w', 'x'), isNull);
      },
    );
  });

  group('setDefaultModel', () {
    const path = '/api/model/set';

    test('saves the main scope for the profile', () async {
      server.on('POST', path, {'ok': true});
      final result = await repository.setDefaultModel(
        'work',
        'openrouter',
        'example-model-a',
      );
      expect(result, isA<DefaultModelSaved>());
      expect(sentBody('POST', path), {
        'scope': 'main',
        'provider': 'openrouter',
        'model': 'example-model-a',
      });
      expect(
        server.requestsTo('POST', path).single.queryParameters['profile'],
        'work',
      );
    });

    test('surfaces the confirmation and resends only with the flag', () async {
      server.onRequest('POST', path, (request) {
        final confirmed =
            (jsonBody(request)! as Map)['confirm_expensive_model'] == true;
        return (
          status: 200,
          body: confirmed
              ? {'ok': true}
              : {
                  'ok': false,
                  'confirm_required': true,
                  'confirm_message': 'This model is expensive.',
                },
        );
      });
      final first = await repository.setDefaultModel('w', 'p', 'm');
      expect(first, isA<DefaultModelConfirmRequired>());
      expect(
        (first as DefaultModelConfirmRequired).message,
        'This model is expensive.',
      );
      expect(server.requestsTo('POST', path), hasLength(1));
      final second = await repository.setDefaultModel(
        'w',
        'p',
        'm',
        confirmExpensive: true,
      );
      expect(second, isA<DefaultModelSaved>());
      expect(
        (jsonBody(server.requestsTo('POST', path).last)!
            as Map)['confirm_expensive_model'],
        isTrue,
      );
    });

    test(
      'a restart-required answer is a refusal, a lost one a failure',
      () async {
        server.on('POST', path, {'detail': 'Restart required: x'}, status: 503);
        final refused = await repository.setDefaultModel('w', 'p', 'm');
        expect((refused as DefaultModelRefused).message, startsWith('Restart'));
        lostAnswer('POST', path);
        expect(
          await repository.setDefaultModel('w', 'p', 'm'),
          isA<DefaultModelFailed>(),
        );
      },
    );
  });
}
