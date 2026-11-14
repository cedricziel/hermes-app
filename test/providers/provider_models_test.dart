import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/providers/provider_models.dart';

import 'provider_fixtures.dart';

void main() {
  group('lastFourFromRedacted', () {
    test('takes the tail of the sentinel', () {
      expect(lastFourFromRedacted('«redacted:sk-o...4f2a»'), '4f2a');
    });

    test('shows nothing for a short key', () {
      expect(lastFourFromRedacted('«redacted:***»'), isNull);
    });

    test('shows nothing for anything that is no sentinel', () {
      expect(lastFourFromRedacted('sk-o...4f2a'), isNull);
      expect(lastFourFromRedacted('«redacted:abc»'), isNull);
      expect(lastFourFromRedacted('«redacted:a...b»'), isNull);
      expect(lastFourFromRedacted(null), isNull);
      expect(lastFourFromRedacted(7), isNull);
    });
  });

  ProviderCatalog empty() => mergeProviders(
    options: emptyProfileOptions(),
    env: emptyProfileEnv(),
    oauth: emptyProfileOauth(),
    endpoints: noEndpoints(),
    pool: emptyPool(),
  );

  ProviderCatalog connected() => mergeProviders(
    options: connectedOptions(),
    env: connectedEnv(),
    oauth: connectedOauth(),
    endpoints: oneEndpoint(),
    pool: connectedPool(),
  );

  group('connect method', () {
    test('an account beats the registry auth type', () {
      final codex = empty().byId('openai-codex')!;
      expect(codex.authType, 'oauth_external');
      expect(codex.method, ConnectMethod.account);
      expect(empty().byId('nous')!.method, ConnectMethod.account);
    });

    test('a skeleton with a key variable is a key', () {
      final zeta = empty().byId('zeta')!;
      expect(zeta.method, ConnectMethod.key);
      expect(zeta.keyEnv, 'ZETA_API_KEY');
    });

    test('the primary key variable names the key and its link', () {
      final router = empty().byId('openrouter')!;
      expect(router.keyEnv, 'OPENROUTER_API_KEY');
      expect(router.keyUrl, 'https://openrouter.ai/keys');
    });

    test('a key provider with an external account keeps both', () {
      final anthropic = empty().byId('anthropic')!;
      expect(anthropic.method, ConnectMethod.key);
      expect(anthropic.externalAccount, isTrue);
      expect(anthropic.serverCommand, 'hermes auth add anthropic');
    });

    test('external and unknown registry types are shown on the server', () {
      final copilot = empty().byId('copilot')!;
      expect(copilot.method, ConnectMethod.onServer);
      expect(copilot.serverCommand, 'hermes auth add copilot');
      final unknown = empty().byId('mystery')!;
      expect(unknown.method, ConnectMethod.onServer);
      expect(unknown.authType, 'x9');
      final qwen = empty().byId('qwen-oauth')!;
      expect(qwen.method, ConnectMethod.onServer);
    });

    test('a custom endpoint is an endpoint', () {
      final lab = connected().byId('lab')!;
      expect(lab.method, ConnectMethod.endpoint);
      expect(lab.endpoint!.baseUrl, 'http://127.0.0.1:8283/v1');
    });
  });

  group('rows that are not providers', () {
    test('moa and the local runtime are left out', () {
      final ids = empty().entries.map((e) => e.id);
      expect(ids, isNot(contains('moa')));
      expect(ids, isNot(contains('llamacpp')));
    });

    test('a local-runtime row is left out by source or by auth type', () {
      final catalog = mergeProviders(
        options: optionsBody([
          optionsRow('a', source: 'local-runtime'),
          optionsRow('b', authType: 'local'),
          optionsRow('c'),
        ]),
      );
      expect(catalog.entries.map((e) => e.id), ['c']);
    });

    test('a row lacking its slug is skipped and counted', () {
      final body = emptyProfileOptions();
      (body['providers']! as List).addAll([
        {'name': 'no slug'},
        'not a map',
        {'slug': ''},
      ]);
      final catalog = mergeProviders(options: body);
      expect(catalog.skippedRows, 3);
      expect(catalog.byId('openrouter'), isNotNull);
    });

    test('a malformed row in each source is counted', () {
      final catalog = mergeProviders(
        options: emptyProfileOptions(),
        env: {...emptyProfileEnv(), 'BROKEN': 'x'},
        oauth: {
          'providers': [
            {'name': 'no id'},
          ],
        },
        endpoints: {
          'endpoints': [
            {'name': 'no id'},
            endpointRow('dup'),
            endpointRow('dup'),
          ],
        },
        pool: {
          'providers': [
            {'entries': []},
          ],
        },
      );
      expect(catalog.skippedRows, 5);
      expect(catalog.byId('dup'), isNotNull);
    });
  });

  group('connected providers', () {
    test('the default provider is first and flagged', () {
      final catalog = connected();
      expect(catalog.defaultProvider, 'openrouter');
      expect(catalog.defaultModel, 'example-model-a');
      expect(catalog.entries.first.id, 'openrouter');
      expect(catalog.entries.first.isDefault, isTrue);
      expect(catalog.entries.first.models, hasLength(2));
      expect(catalog.entries.first.totalModels, 40);
    });

    test('connected come before the rest, endpoints last among them', () {
      final catalog = connected();
      expect(catalog.connected.map((e) => e.id), [
        'openrouter',
        'openai-codex',
        'lab',
      ]);
      expect(catalog.available.map((e) => e.id), ['nous', 'anthropic']);
    });

    test('a key shows only its last four characters', () {
      final key = connected().byId('openrouter')!.credentials.first;
      expect(key.kind, CredentialKind.apiKey);
      expect(key.keyEnv, 'OPENROUTER_API_KEY');
      expect(key.lastFour, '4f2a');
    });

    test('a short key has no characters', () {
      final env = connectedEnv();
      (env['OPENROUTER_API_KEY']! as Map)['redacted_value'] = '«redacted:***»';
      final key = mergeProviders(
        options: connectedOptions(),
        env: env,
      ).byId('openrouter')!.credentials.first;
      expect(key.lastFour, isNull);
    });

    test('a sign-in is an account credential with its source', () {
      final codex = connected().byId('openai-codex')!;
      expect(codex.connected, isTrue);
      expect(codex.account!.source, 'device_code');
      expect(codex.disconnectable, isTrue);
    });

    test('only hand-added api keys of the pool count as extra keys', () {
      final router = connected().byId('openrouter')!;
      final extra = router.credentials.where(
        (c) => c.kind == CredentialKind.poolKey,
      );
      expect(extra, hasLength(1));
      expect(extra.single.label, 'spare');
      expect(extra.single.lastFour, '9876');
      final codex = connected().byId('openai-codex')!;
      expect(
        codex.credentials.where((c) => c.kind == CredentialKind.poolKey),
        isEmpty,
      );
    });

    test(
      'an endpoint holds its key preview and the options row is dropped',
      () {
        final catalog = connected();
        expect(catalog.entries.where((e) => e.id == 'custom:lab'), isEmpty);
        final lab = catalog.byId('lab')!;
        expect(lab.connected, isTrue);
        expect(lab.credentials.single.kind, CredentialKind.endpointKey);
        expect(lab.credentials.single.lastFour, isNull);
        expect(lab.endpoint!.hasApiKey, isTrue);
      },
    );

    test('a user-defined row stays when no endpoint carries its id', () {
      final catalog = mergeProviders(
        options: connectedOptions(),
        endpoints: {
          'endpoints': [endpointRow('other')],
        },
      );
      expect(catalog.byId('custom:lab'), isNotNull);
      expect(catalog.byId('other'), isNotNull);
    });

    test('an env key attaches to a provider only the account list names', () {
      final catalog = mergeProviders(
        options: optionsBody([]),
        env: {
          'ZED_API_KEY': envRow(
            provider: 'zed',
            isSet: true,
            redacted: '«redacted:ab...wxyz»',
          ),
        },
        oauth: {
          'providers': [oauthRow('zed', flow: 'external')],
        },
      );
      final zed = catalog.byId('zed')!;
      expect(zed.method, ConnectMethod.key);
      expect(zed.keyEnv, 'ZED_API_KEY');
      expect(zed.credentials.single.lastFour, 'wxyz');
    });

    test('a user-defined row stays when endpoints were not read', () {
      final catalog = mergeProviders(options: connectedOptions());
      expect(catalog.byId('custom:lab'), isNotNull);
    });

    test('an endpoint can be the default', () {
      final endpoints = oneEndpoint();
      ((endpoints['endpoints']! as List).single as Map)['is_current'] = true;
      final options = connectedOptions()..['provider'] = 'custom:lab';
      for (final row in options['providers']! as List) {
        (row as Map)['is_current'] = false;
      }
      final catalog = mergeProviders(options: options, endpoints: endpoints);
      expect(catalog.entries.first.id, 'lab');
    });

    test('an account signed in is connected although options say not', () {
      final options = emptyProfileOptions();
      final catalog = mergeProviders(
        options: options,
        oauth: {
          'providers': [
            oauthRow('nous', loggedIn: true, source: 'device_code'),
          ],
        },
      );
      expect(catalog.byId('nous')!.connected, isTrue);
    });

    test('an account the options do not list is added', () {
      final catalog = mergeProviders(
        options: optionsBody([]),
        oauth: {
          'providers': [oauthRow('minimax-oauth', loggedIn: true)],
        },
      );
      expect(catalog.byId('minimax-oauth')!.method, ConnectMethod.account);
      expect(catalog.byId('minimax-oauth')!.connected, isTrue);
    });

    test('sign-in details travel with the entry', () {
      final env = oauthRow(
        'nous',
        loggedIn: true,
        source: 'env_var',
        disconnectable: false,
        disconnectHint: 'Remove the API key from Settings → Keys instead.',
        disconnectCommand: 'hermes auth remove nous',
      );
      final nous = mergeProviders(
        options: optionsBody([optionsRow('nous')]),
        oauth: {
          'providers': [env],
        },
      ).byId('nous')!;
      expect(nous.disconnectable, isFalse);
      expect(nous.account!.source, 'env_var');
      expect(nous.disconnectHint, contains('Settings'));
      expect(nous.disconnectCommand, 'hermes auth remove nous');
    });
  });

  group('order', () {
    test('unconnected providers lead with the recommended four', () {
      final options = optionsBody([
        for (final slug in ['zeta', 'anthropic', 'alpha', 'openai-api', 'nous'])
          optionsRow(
            slug,
            authenticated: false,
            authType: 'api_key',
            keyEnv: '${slug.toUpperCase()}_API_KEY',
          ),
        optionsRow(
          'openrouter',
          authenticated: false,
          authType: 'api_key',
          keyEnv: 'OPENROUTER_API_KEY',
        ),
      ]);
      expect(mergeProviders(options: options).entries.map((e) => e.id), [
        'nous',
        'openrouter',
        'openai-api',
        'anthropic',
        'alpha',
        'zeta',
      ]);
    });
  });

  group('missing sources', () {
    test('nothing at all is an empty catalog', () {
      final catalog = mergeProviders();
      expect(catalog.entries, isEmpty);
      expect(catalog.skippedRows, 0);
    });

    test('without env a skeleton key is still a key, without a link', () {
      final router = mergeProviders(options: emptyProfileOptions())
          .byId('openrouter')!;
      expect(router.method, ConnectMethod.key);
      expect(router.keyEnv, 'OPENROUTER_API_KEY');
      expect(router.keyUrl, isNull);
    });

    test('without the account list nothing is an account', () {
      final catalog = mergeProviders(options: emptyProfileOptions());
      expect(
        catalog.entries.where((e) => e.method == ConnectMethod.account),
        isEmpty,
      );
    });
  });

  group('random input', () {
    Object? random(Random rng, int depth) {
      switch (rng.nextInt(depth > 3 ? 5 : 8)) {
        case 0:
          return null;
        case 1:
          return rng.nextInt(10) - 3;
        case 2:
          return rng.nextBool();
        case 3:
          return ['', 'slug', 'flow', 'device_code', '«redacted:a...bcde»'][rng
              .nextInt(5)];
        case 4:
          return rng.nextDouble();
        case 5:
          return [
            for (var i = 0; i < rng.nextInt(4); i++) random(rng, depth + 1),
          ];
        default:
          const keys = [
            'providers',
            'endpoints',
            'entries',
            'slug',
            'id',
            'name',
            'provider',
            'model',
            'models',
            'status',
            'flow',
            'category',
            'is_set',
            'is_password',
            'provider_primary',
            'authenticated',
            'auth_type',
            'key_env',
            'source',
            'redacted_value',
            'has_api_key',
            'context_length',
          ];
          return {
            for (var i = 0; i < rng.nextInt(6); i++)
              keys[rng.nextInt(keys.length)]: random(rng, depth + 1),
          };
      }
    }

    test('never throws', () {
      final rng = Random(7);
      for (var i = 0; i < 2000; i++) {
        final catalog = mergeProviders(
          options: random(rng, 0),
          env: random(rng, 0),
          oauth: random(rng, 0),
          endpoints: random(rng, 0),
          pool: random(rng, 0),
        );
        expect(catalog.skippedRows, greaterThanOrEqualTo(0));
      }
    });

    test('never throws on shapes close to the real ones', () {
      final rng = Random(11);
      final bodies = [
        connectedOptions(),
        connectedEnv(),
        connectedOauth(),
        oneEndpoint(),
        connectedPool(),
      ];
      Object? mutate(Object? value) {
        if (rng.nextInt(12) == 0) return random(rng, 2);
        if (value is Map) {
          return {for (final e in value.entries) e.key: mutate(e.value)};
        }
        if (value is List) return [for (final e in value) mutate(e)];
        return value;
      }

      for (var i = 0; i < 1500; i++) {
        final m = [for (final b in bodies) mutate(b)];
        mergeProviders(
          options: m[0],
          env: m[1],
          oauth: m[2],
          endpoints: m[3],
          pool: m[4],
        );
      }
    });
  });
}
