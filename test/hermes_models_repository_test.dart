import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/models/hermes_models_repository.dart';
import 'package:hermes_app/src/models/model_provider_option.dart';

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
