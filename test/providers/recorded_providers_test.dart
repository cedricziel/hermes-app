import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/providers/provider_models.dart';
import 'package:hermes_app/src/providers/provider_results.dart';
import 'package:hermes_app/src/providers/providers_repository.dart';

import '../support/fake_hermes_server.dart';
import 'provider_fixtures.dart';

/// The recorded answers of Hermes d923a5eb (task 1.2) through the real merge
/// and the real repository, so a change to the parser is checked against what
/// a server really sends and not only against hand-made rows.
void main() {
  ProviderCatalog merged({
    Object? options,
    Object? env,
    Object? oauth,
    Object? endpoints,
    Object? pool,
  }) => mergeProviders(
    options: options,
    env: env,
    oauth: oauth ?? recordedOauth,
    endpoints: endpoints ?? recordedNoEndpoints,
    pool: pool ?? recordedEmptyPool,
  );

  group('an empty profile', () {
    late ProviderCatalog catalog;
    setUp(
      () => catalog = merged(
        options: recordedEmptyOptions,
        env: recordedEmptyEnv,
      ),
    );

    test('merges without a skipped row and connects nothing', () {
      expect(catalog.skippedRows, 0);
      expect(catalog.connected, isEmpty);
      expect(catalog.defaultProvider, isEmpty);
      expect(catalog.defaultModel, isEmpty);
    });

    test('takes the key variable from /api/env when the row names none', () {
      // The skeleton's `key_env` is "" for OpenRouter.
      final openRouter = catalog.byId('openrouter')!;
      expect(openRouter.method, ConnectMethod.key);
      expect(openRouter.keyEnv, 'OPENROUTER_API_KEY');
      expect(openRouter.keyUrl, 'https://openrouter.ai/keys');
      expect(catalog.byId('openai-api')!.keyEnv, 'OPENAI_API_KEY');
      expect(catalog.byId('lmstudio')!.keyEnv, 'LM_API_KEY');
    });

    test('offers an account sign-in, a server command and no key for the '
        'rest', () {
      expect(catalog.byId('nous')!.method, ConnectMethod.account);
      expect(catalog.byId('openai-codex')!.method, ConnectMethod.account);
      final vertex = catalog.byId('vertex')!;
      expect(vertex.method, ConnectMethod.onServer);
      expect(vertex.serverCommand, 'hermes auth add vertex');
      expect(catalog.byId('bedrock')!.method, ConnectMethod.onServer);
    });

    test('lists the canonical `custom` skeleton as a provider to connect '
        'on the server', () {
      // Found against the real server: the `custom` row (name "custom",
      // `auth_type` api_key, no `key_env`) is not a provider to connect; the
      // custom endpoint form owns that. Pinned so a change is noticed.
      final custom = catalog.byId('custom')!;
      expect(custom.connected, isFalse);
      expect(custom.method, ConnectMethod.onServer);
    });
  });

  group('a profile with an OpenRouter key', () {
    late ProviderCatalog catalog;
    setUp(
      () => catalog = merged(
        options: recordedKeyOptions,
        env: recordedKeyEnv,
        pool: recordedKeyPool,
      ),
    );

    test('shows it connected with its models at once and the last four '
        'of the key', () {
      final openRouter = catalog.byId('openrouter')!;
      expect(openRouter.connected, isTrue);
      expect(openRouter.models, hasLength(3));
      expect(openRouter.totalModels, 72);
      expect(openRouter.credentials, hasLength(1));
      expect(openRouter.credentials.single.kind, CredentialKind.apiKey);
      expect(openRouter.credentials.single.lastFour, '0000');
      expect(openRouter.keyEnv, 'OPENROUTER_API_KEY');
    });

    test('has no default yet, and the pool entry that mirrors the variable '
        'is not shown twice', () {
      expect(catalog.defaultProvider, isEmpty);
      expect(catalog.byId('openrouter')!.isDefault, isFalse);
      expect(
        catalog
            .byId('openrouter')!
            .credentials
            .where((c) => c.kind == CredentialKind.poolKey),
        isEmpty,
      );
    });

    test('leaves the managed local runtime out', () {
      expect(catalog.byId('llamacpp'), isNull);
      expect(catalog.skippedRows, 0);
    });
  });

  group('a profile with a manual pool entry', () {
    late ProviderCatalog catalog;
    setUp(
      () => catalog = merged(
        options: recordedManualPoolOptions,
        env: <String, Object?>{},
        pool: recordedManualPool,
      ),
    );

    test('is connected by the pool entry alone, read-only', () {
      final openRouter = catalog.byId('openrouter')!;
      expect(openRouter.connected, isTrue);
      expect(openRouter.credentials.single.kind, CredentialKind.poolKey);
      expect(openRouter.credentials.single.label, 'manual demo');
      expect(openRouter.credentials.single.lastFour, '0001');
    });

    test('hides the moa row and the local-runtime row', () {
      expect(catalog.byId('moa'), isNull);
      expect(catalog.byId('llamacpp'), isNull);
      expect(catalog.skippedRows, 0);
    });
  });

  group('a profile with a custom endpoint as its default', () {
    late ProviderCatalog catalog;
    setUp(
      () => catalog = merged(
        options: recordedEndpointOptions,
        env: <String, Object?>{},
        endpoints: recordedEndpoints,
      ),
    );

    test('shows the endpoint once, as the default, from the endpoints '
        'answer', () {
      final rows = catalog.entries.where((e) => e.id == 'demo-local');
      expect(rows, hasLength(1));
      final endpoint = rows.single;
      expect(endpoint.method, ConnectMethod.endpoint);
      expect(endpoint.connected, isTrue);
      expect(endpoint.isDefault, isTrue);
      expect(endpoint.endpoint!.baseUrl, 'http://127.0.0.1:8283/v1');
      expect(endpoint.endpoint!.hasApiKey, isTrue);
      // The preview is a variable reference, not a redaction: no last four.
      expect(endpoint.credentials.single.kind, CredentialKind.endpointKey);
      expect(endpoint.credentials.single.lastFour, isNull);
    });

    test('keeps the default provider as Hermes writes it', () {
      expect(catalog.defaultProvider, 'custom:demo-local');
      expect(catalog.defaultModel, 'demo-model-a');
    });
  });

  group('the default provider\'s key removed', () {
    test('keeps provider and model, and shows the provider as not '
        'connected with Hermes\' warning', () {
      final catalog = merged(
        options: recordedRemovedKeyOptions,
        env: <String, Object?>{},
      );
      expect(catalog.defaultProvider, 'openrouter');
      expect(catalog.defaultModel, 'example-model-a');
      final openRouter = catalog.byId('openrouter')!;
      expect(openRouter.connected, isFalse);
      expect(openRouter.isDefault, isTrue);
      expect(openRouter.warning, contains('not authenticated'));
      expect(openRouter.models, ['example-model-a']);
    });
  });

  group('through the repository', () {
    test('the recorded answers of a profile with a key load without a '
        'skipped row', () async {
      final server = FakeHermesServer()
        ..on('GET', '/api/model/options', recordedKeyOptions)
        ..on('GET', '/api/env', recordedKeyEnv)
        ..on('GET', '/api/providers/oauth', recordedOauth)
        ..on('GET', '/api/providers/custom-endpoints', recordedNoEndpoints)
        ..on('GET', '/api/credentials/pool', recordedKeyPool);

      final snapshot = await ProvidersRepository(server.client().raw)
          .load('demo');

      final loaded = snapshot as ProvidersLoaded;
      for (final source in ProviderSource.values) {
        expect(loaded.state(source), isA<SourceOk>(), reason: source.name);
      }
      expect(loaded.catalog.skippedRows, 0);
      expect(loaded.catalog.connected.map((e) => e.id), ['openrouter']);
    });
  });
}
