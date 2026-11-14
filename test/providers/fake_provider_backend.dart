import 'package:dio/dio.dart';

import '../support/fake_hermes_server.dart';
import 'provider_fixtures.dart';

/// How the answer to a write that reached the server goes wrong.
enum LostAnswer { none, afterWrite, beforeWrite }

/// A Hermes dashboard with state: keys, sign-ins, endpoints and the default
/// model live here, and every list route answers from them, so a controller
/// that writes and then reads again sees what it changed.
class FakeProviderBackend {
  FakeProviderBackend() {
    _install();
  }

  final server = FakeHermesServer();

  /// `.env` variable to the redacted preview a read shows.
  final keys = <String, String>{};
  final signedIn = <String>{};
  final endpoints = <Map<String, Object?>>[];
  final pool = <String, List<Map<String, Object?>>>{};

  String defaultProvider = '';
  String defaultModel = '';

  /// A provider that lists its models only once it was recommended (as
  /// Hermes' non-blocking catalogs do), and which providers lost theirs.
  bool modelsWarm = true;

  /// The recommendation does not warm the catalog (models stay unlisted).
  bool stayCold = false;
  final models = const ['example-model-a', 'example-model-b'];

  /// Recommended default per provider; a missing one is no recommendation.
  final recommended = <String, String>{
    'openrouter': 'example-model-a',
    'nous': 'example-nous-model',
    'anthropic': 'example-model-b',
  };
  bool recommendationFails = false;

  /// What the key check says.
  Map<String, Object?> validate = {
    'ok': true,
    'reachable': true,
    'message': '',
  };

  LostAnswer lostSave = LostAnswer.none;
  LostAnswer lostRemove = LostAnswer.none;
  int? saveStatus;
  String saveDetail = '';

  /// A model that needs the person's confirmation before it is saved.
  String? expensiveModel;
  String expensiveMessage = 'This model is expensive.';

  /// What a poll answers; the keys of an approval are applied on `approved`.
  Map<String, Object?> pollAnswer = {'session_id': 's-1', 'status': 'pending'};

  /// The default Hermes sets when a Nous sign-in is approved (null: none).
  String? approvalMovesDefaultTo;
  bool approvalClearsDefault = false;
  String approvalModelInPoll = '';

  static String redact(String value) =>
      '«redacted:${value.substring(0, 4)}...${value.substring(value.length - 4)}»';

  bool _connected(String slug) =>
      (pool[slug]?.any((e) => e['source'] == 'manual') ?? false) ||
      switch (slug) {
        'openrouter' => keys.containsKey('OPENROUTER_API_KEY'),
        'anthropic' => keys.containsKey('ANTHROPIC_API_KEY'),
        _ => signedIn.contains(slug),
      };

  Map<String, Object?> _options() {
    Map<String, Object?> row(String slug, String name, {String? keyEnv}) {
      final connected = _connected(slug);
      return optionsRow(
        slug,
        name: name,
        authenticated: connected,
        current: connected && defaultProvider == slug,
        models: connected && modelsWarm ? models : const [],
        authType: keyEnv != null ? 'api_key' : 'oauth_device_code',
        keyEnv: keyEnv,
      );
    }

    return optionsBody(
      [
        row('openrouter', 'OpenRouter', keyEnv: 'OPENROUTER_API_KEY'),
        row('anthropic', 'Anthropic', keyEnv: 'ANTHROPIC_API_KEY'),
        row('nous', 'Nous Portal'),
        row('openai-codex', 'ChatGPT or Codex'),
      ],
      model: defaultModel,
      provider: defaultProvider,
    );
  }

  Map<String, Object?> _env() => {
    for (final (env, slug, name) in [
      ('OPENROUTER_API_KEY', 'openrouter', 'OpenRouter'),
      ('ANTHROPIC_API_KEY', 'anthropic', 'Anthropic'),
    ])
      env: envRow(
        provider: slug,
        label: name,
        isSet: keys.containsKey(env),
        redacted: keys[env],
        url: 'https://example.com/keys/$slug',
      ),
  };

  Map<String, Object?> _oauth() => {
    'providers': [
      oauthRow(
        'nous',
        name: 'Nous Portal',
        loggedIn: signedIn.contains('nous'),
        source: 'device_code',
      ),
      oauthRow(
        'openai-codex',
        name: 'ChatGPT or Codex',
        loggedIn: signedIn.contains('openai-codex'),
        source: 'device_code',
      ),
      oauthRow(
        'anthropic',
        name: 'Anthropic account',
        flow: 'external',
        cliCommand: 'hermes auth add anthropic',
      ),
    ],
  };

  void _install() {
    server
      ..onRequest(
        'GET',
        '/api/model/options',
        (_) => (status: 200, body: _options()),
      )
      ..onRequest('GET', '/api/env', (_) => (status: 200, body: _env()))
      ..onRequest(
        'GET',
        '/api/providers/oauth',
        (_) => (status: 200, body: _oauth()),
      )
      ..onRequest(
        'GET',
        '/api/providers/custom-endpoints',
        (_) => (
          status: 200,
          body: {
            'endpoints': endpoints,
            'current': {'provider': '', 'model': '', 'base_url': ''},
          },
        ),
      )
      ..onRequest(
        'GET',
        '/api/credentials/pool',
        (_) => (
          status: 200,
          body: {
            'providers': [
              for (final e in pool.entries)
                {'provider': e.key, 'entries': e.value},
            ],
          },
        ),
      )
      ..onRequest(
        'POST',
        '/api/providers/validate',
        (_) => (status: 200, body: validate),
      )
      ..onRequest('PUT', '/api/env', (request) {
        final body = jsonBody(request)! as Map;
        final key = body['key'] as String;
        final value = body['value'] as String;
        if (saveStatus case final status?) {
          return (status: status, body: {'detail': saveDetail});
        }
        if (lostSave == LostAnswer.beforeWrite) {
          throw DioException.connectionError(
            requestOptions: request,
            reason: 'offline',
          );
        }
        keys[key] = redact(value);
        if (lostSave == LostAnswer.afterWrite) {
          throw DioException.connectionError(
            requestOptions: request,
            reason: 'offline',
          );
        }
        return (status: 200, body: {'ok': true, 'key': key});
      })
      ..onRequest('DELETE', '/api/env', (request) {
        final key = (jsonBody(request)! as Map)['key'] as String;
        if (lostRemove == LostAnswer.beforeWrite) {
          throw DioException.connectionError(
            requestOptions: request,
            reason: 'offline',
          );
        }
        if (keys.remove(key) == null) {
          return (status: 404, body: {'detail': '$key not found in .env'});
        }
        if (lostRemove == LostAnswer.afterWrite) {
          throw DioException.connectionError(
            requestOptions: request,
            reason: 'offline',
          );
        }
        return (status: 200, body: {'ok': true});
      })
      ..onRequest('GET', '/api/model/recommended-default', (request) {
        if (recommendationFails) return (status: 500, body: {'detail': 'x'});
        final slug = request.queryParameters['provider'] as String;
        if (!stayCold) modelsWarm = true;
        return (
          status: 200,
          body: {
            'provider': slug,
            'model': recommended[slug] ?? '',
            'free_tier': false,
          },
        );
      })
      ..onRequest('POST', '/api/model/set', (request) {
        final body = jsonBody(request)! as Map;
        final model = body['model'] as String;
        if (model == expensiveModel &&
            body['confirm_expensive_model'] != true) {
          return (
            status: 200,
            body: {
              'ok': false,
              'confirm_required': true,
              'confirm_message': expensiveMessage,
            },
          );
        }
        defaultProvider = body['provider'] as String;
        defaultModel = model;
        return (status: 200, body: {'ok': true});
      })
      ..on('POST', '/api/providers/oauth/nous/start', {
        'session_id': 's-1',
        'flow': 'device_code',
        'user_code': 'ABCD-1234',
        'verification_url': 'https://portal.example.com/device?code=ABCD-1234',
        'expires_in': 900,
        'poll_interval': 5,
      })
      ..onRequest('GET', '/api/providers/oauth/nous/poll/s-1', (_) {
        if (pollAnswer['status'] == 'approved' && !signedIn.contains('nous')) {
          signedIn.add('nous');
          if (approvalMovesDefaultTo != null) {
            defaultProvider = 'nous';
            defaultModel = approvalMovesDefaultTo!;
          }
          if (approvalClearsDefault) {
            defaultProvider = '';
            defaultModel = '';
          }
        }
        return (status: 200, body: pollAnswer);
      })
      ..on('DELETE', '/api/providers/oauth/sessions/s-1', {'ok': true})
      ..onRequest('DELETE', '/api/providers/oauth/nous', (_) {
        signedIn.remove('nous');
        return (status: 200, body: {'ok': true, 'provider': 'nous'});
      })
      ..on('POST', '/api/providers/custom-endpoints/validate', {
        'ok': true,
        'reachable': true,
        'models': ['example-model-a', 'example-model-b'],
        'resolved_base_url': 'http://localhost:8000/v1',
      })
      ..onRequest('POST', '/api/providers/custom-endpoints', (request) {
        final body = Map<String, Object?>.from(jsonBody(request)! as Map);
        final id = (body['id'] as String?) ?? 'lab';
        endpoints
          ..removeWhere((e) => e['id'] == id)
          ..add(
            endpointRow(
              id,
              name: body['name'] as String,
              baseUrl: body['base_url'] as String,
              model: body['model'] as String,
              hasKey: body['api_key'] != null,
              current: body['make_default'] == true,
            ),
          );
        if (body['make_default'] == true) {
          defaultProvider = 'custom:$id';
          defaultModel = body['model'] as String;
        }
        return (status: 200, body: {'ok': true, 'id': id});
      })
      ..onRequest('DELETE', '/api/providers/custom-endpoints/lab', (_) {
        endpoints.removeWhere((e) => e['id'] == 'lab');
        return (status: 200, body: {'ok': true});
      });
  }
}
