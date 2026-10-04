import 'package:hermes_app/src/models/hermes_models_repository.dart';
import 'package:hermes_app/src/settings/helper_models_screen.dart';
import 'package:widgetbook/widgetbook.dart';

import '../test/support/fake_hermes_server.dart';
import 'host.dart';

/// A profile with a few helper slots set and a model list to pick from.
FakeHermesServer helperModelsServer({bool withMoa = true}) {
  final server = FakeHermesServer()
    ..on('GET', '/api/model/auxiliary', {
      'tasks': [
        {'task': 'vision', 'provider': 'auto', 'model': ''},
        {
          'task': 'title_generation',
          'provider': 'openrouter',
          'model': 'gemini-flash',
          'reasoning_effort': 'low',
        },
        {'task': 'compression', 'provider': 'openai', 'model': 'gpt-5-mini'},
        {'task': 'approval', 'provider': 'auto', 'model': ''},
      ],
      'main': {'provider': 'anthropic', 'model': 'claude-opus-4'},
    })
    ..on('GET', '/api/model/options', {
      'model': 'claude-opus-4',
      'provider': 'anthropic',
      'providers': [
        {
          'slug': 'openai',
          'name': 'OpenAI',
          'models': ['gpt-5-mini', 'gpt-5-pro'],
        },
        {
          'slug': 'openrouter',
          'name': 'OpenRouter',
          'models': ['gemini-flash', 'deepseek/deepseek-v4-pro'],
        },
      ],
    })
    ..on('POST', '/api/model/set', {'ok': true, 'scope': 'auxiliary'})
    ..on('PUT', '/api/model/moa', {'ok': true});
  if (withMoa) server.on('GET', '/api/model/moa', moaConfigBody());
  return server;
}

HelperModelsScreen helperModelsScreen(FakeHermesServer server) =>
    HelperModelsScreen(
      repository: HermesModelsRepository(server.client().raw),
      profile: 'work',
    );

WidgetbookUseCase _helperModels(String name, {bool withMoa = true}) =>
    WidgetbookUseCase(
      name: name,
      builder: (_) => Hosted<FakeHermesServer>(
        create: () => helperModelsServer(withMoa: withMoa),
        builder: (_, server) => helperModelsScreen(server),
      ),
    );

WidgetbookNode settingsScreensNode() => WidgetbookFolder(
  name: 'Settings screens',
  children: [
    WidgetbookComponent(
      name: 'HelperModelsScreen',
      useCases: [
        _helperModels('Slots and mixture of agents'),
        _helperModels('Without mixture of agents', withMoa: false),
      ],
    ),
  ],
);
