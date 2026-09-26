import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/models/hermes_models_repository.dart';
import 'package:hermes_app/src/models/model_provider_option.dart';
import 'package:hermes_app/src/models/moa_setup.dart';

import 'support/fake_hermes_server.dart';

void main() {
  late FakeHermesServer server;
  late HermesModelsRepository repository;

  setUp(() {
    server = FakeHermesServer();
    repository = HermesModelsRepository(server.client().raw);
  });

  test('loads the options of the given profile', () async {
    server.on(
      'GET',
      '/api/model/options',
      {
        'model': 'gpt-5.1',
        'provider': 'openai',
        'providers': [
          {
            'slug': 'openai',
            'models': ['gpt-5.1'],
          },
        ],
      },
      query: {'profile': 'work'},
    );

    final options = await repository.load(profile: 'work');

    expect(options.current, const ModelChoice('openai', 'gpt-5.1'));
    expect(options.providers.single.id, 'openai');
  });

  test('loads the helper model slots of the given profile', () async {
    server.on(
      'GET',
      '/api/model/auxiliary',
      {
        'tasks': [
          {'task': 'vision', 'provider': 'openai', 'model': 'gpt-5-mini'},
        ],
        'main': {'provider': 'openai', 'model': 'gpt-5.1'},
      },
      query: {'profile': 'work'},
    );

    final models = await repository.loadAuxiliary(profile: 'work');

    expect(
      models.slots.single.choice,
      const ModelChoice('openai', 'gpt-5-mini'),
    );
    expect(models.main, const ModelChoice('openai', 'gpt-5.1'));
  });

  test('loads the MoA setup of the given profile', () async {
    server.on(
      'GET',
      '/api/model/moa',
      moaConfigBody(),
      query: {'profile': 'work'},
    );

    final moa = await repository.loadMoa(profile: 'work');

    expect(moa!.slots, hasLength(3));
  });

  test('saves the whole MoA config with one slot changed', () async {
    server.on('PUT', '/api/model/moa', {'ok': true});
    final moa = MoaSetup.fromJson(moaConfigBody())!;

    await repository.saveMoa(
      moa.withSlot(
        'moa-aggregator',
        const ModelChoice('anthropic', 'claude-sonnet-4-5'),
      ),
      profile: 'work',
    );

    final request = server.requestsTo('PUT', '/api/model/moa').single;
    expect(request.queryParameters, {'profile': 'work'});
    final body = jsonBody(request)! as Map<String, Object?>;
    expect(body['default_preset'], 'default');
    final presets = body['presets']! as Map;
    expect(presets.keys, ['default', 'cheap']);
    final preset = presets['default'] as Map;
    expect(preset['aggregator'], {
      'provider': 'anthropic',
      'model': 'claude-sonnet-4-5',
      'enabled': true,
    });
    expect(preset['reference_temperature'], 0.7);
    expect(preset['fanout'], 'user_turn');
    expect((preset['reference_models'] as List)[2], {
      'provider': 'openrouter',
      'model': 'deepseek/deepseek-v4-pro',
      'reasoning_effort': 'high',
      'enabled': false,
    });
  });

  group('assignAuxiliary', () {
    Map<String, Object?> lastBody() =>
        jsonBody(server.requestsTo('POST', '/api/model/set').last)!
            as Map<String, Object?>;

    setUp(() {
      server.on('POST', '/api/model/set', {
        'ok': true,
        'scope': 'auxiliary',
        'tasks': ['vision'],
      });
    });

    test('posts the task, model and effort for the profile', () async {
      final confirm = await repository.assignAuxiliary(
        'vision',
        const ModelChoice('openai', 'gpt-5-mini', effort: 'low'),
        profile: 'work',
      );

      expect(confirm, isNull);
      final request = server.requestsTo('POST', '/api/model/set').single;
      expect(request.queryParameters, {'profile': 'work'});
      expect(lastBody(), {
        'scope': 'auxiliary',
        'provider': 'openai',
        'model': 'gpt-5-mini',
        'task': 'vision',
        'reasoning_effort': 'low',
        'base_url': '',
        'api_key': '',
        'confirm_expensive_model': false,
      });
    });

    test('no choice puts the slot back on auto', () async {
      await repository.assignAuxiliary('vision', null);

      expect(lastBody(), containsPair('provider', 'auto'));
      expect(lastBody(), containsPair('model', ''));
      expect(lastBody().containsKey('reasoning_effort'), isFalse);
    });

    test('returns the message of a model that needs confirming', () async {
      server.on('POST', '/api/model/set', {
        'ok': false,
        'scope': 'auxiliary',
        'confirm_required': true,
        'confirm_message': 'gpt-5-pro costs \$120 per million tokens.',
      });

      final confirm = await repository.assignAuxiliary(
        'vision',
        const ModelChoice('openai', 'gpt-5-pro'),
      );

      expect(confirm, 'gpt-5-pro costs \$120 per million tokens.');
    });

    test('sends the confirmation when asked to', () async {
      await repository.assignAuxiliary(
        'vision',
        const ModelChoice('openai', 'gpt-5-pro'),
        confirmExpensive: true,
      );

      expect(lastBody(), containsPair('confirm_expensive_model', true));
    });
  });
}
