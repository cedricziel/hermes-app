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
}
