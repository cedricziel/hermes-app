import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/models/model_provider_option.dart';

void main() {
  group('ModelOptions.fromJson', () {
    test('reads the ready providers, their models and the current one', () {
      final options = ModelOptions.fromJson({
        'model': 'claude-opus-4',
        'provider': 'anthropic',
        'providers': [
          {
            'slug': 'anthropic',
            'name': 'Anthropic',
            'is_current': true,
            'authenticated': true,
            'models': ['claude-opus-4', 'claude-haiku-4'],
            'total_models': 2,
            'capabilities': {
              'claude-opus-4': {
                'fast': false,
                'reasoning': true,
                'can_disable_reasoning': true,
              },
              'claude-haiku-4': {'fast': true, 'reasoning': false},
            },
          },
          {
            'slug': 'openai',
            'models': ['gpt-5.1'],
          },
        ],
      });

      expect(options.providers.map((p) => p.id), ['anthropic', 'openai']);
      final anthropic = options.providers.first;
      expect(anthropic.displayLabel, 'Anthropic');
      expect(anthropic.models.map((m) => m.id), [
        'claude-opus-4',
        'claude-haiku-4',
      ]);
      expect(anthropic.models.first.efforts, kReasoningEfforts);
      expect(anthropic.models.last.efforts, isEmpty);
      expect(options.providers.last.displayLabel, 'openai');
      expect(options.current, const ModelChoice('anthropic', 'claude-opus-4'));
    });

    test('offers "none" only when the model can turn reasoning off', () {
      final options = ModelOptions.fromJson({
        'providers': [
          {
            'slug': 'openai',
            'models': ['gpt-5.1'],
            'capabilities': {
              'gpt-5.1': {'reasoning': true},
            },
          },
        ],
      });

      expect(options.providers.single.models.single.efforts, [
        'minimal',
        'low',
        'medium',
        'high',
        'xhigh',
        'max',
        'ultra',
      ]);
    });

    test('skips junk rows, unauthenticated and empty providers', () {
      final options = ModelOptions.fromJson({
        'model': 42,
        'providers': [
          'not a row',
          {
            'name': 'No slug',
            'models': ['x'],
          },
          {
            'slug': '',
            'models': ['x'],
          },
          {
            'slug': 'locked',
            'authenticated': false,
            'models': ['x'],
          },
          {'slug': 'empty', 'models': <String>[]},
          {'slug': 'broken', 'models': 'gpt'},
          {
            'slug': 'mixed',
            'models': ['good', 7, '', null],
            'capabilities': 'junk',
          },
        ],
      });

      expect(options.providers.map((p) => p.id), ['mixed']);
      expect(options.providers.single.models.map((m) => m.id), ['good']);
      expect(options.providers.single.models.single.efforts, isNotEmpty);
      expect(options.current, isNull);
    });

    test('reads the Kanban plugin\'s label and its capability-free rows', () {
      final options = ModelOptions.fromJson({
        'providers': [
          {
            'slug': 'anthropic',
            'label': 'Anthropic',
            'models': ['claude-opus-4'],
          },
        ],
      });

      final provider = options.providers.single;
      expect(provider.displayLabel, 'Anthropic');
      expect(provider.models.single.efforts, kReasoningEfforts.sublist(1));
    });

    test('reads a body that is not a map as no options', () {
      expect(ModelOptions.fromJson('oops').providers, isEmpty);
      expect(ModelOptions.fromJson(null).current, isNull);
    });
  });

  group('ModelOptions first-run facts', () {
    Map<String, Object?> row(
      String slug, {
      bool? authenticated,
      List<String> models = const [],
    }) => {'slug': slug, 'authenticated': ?authenticated, 'models': models};

    test('a connected provider without models is warming', () {
      final options = ModelOptions.fromJson({
        'providers': [row('example-a', authenticated: true)],
      });

      expect(options.providers, isEmpty);
      expect(options.warming, isTrue);
      expect(options.currentMissing, isFalse);
    });

    test('a provider that is not connected is not warming', () {
      final options = ModelOptions.fromJson({
        'providers': [row('example-a', authenticated: false)],
      });

      expect(options.warming, isFalse);
    });

    test('a row without the flag and without models is not warming', () {
      expect(
        ModelOptions.fromJson({
          'providers': [row('example-a')],
        }).warming,
        isFalse,
      );
    });

    test('a warming row is recorded next to a ready provider', () {
      final options = ModelOptions.fromJson({
        'providers': [
          row('example-a', authenticated: true),
          row('example-b', authenticated: true, models: ['example-model-a']),
        ],
      });

      expect(options.providers.map((p) => p.id), ['example-b']);
      expect(options.warming, isTrue);
    });

    test('the default provider missing from the rows is currentMissing', () {
      final options = ModelOptions.fromJson({
        'provider': 'example-a',
        'model': 'example-model-a',
        'providers': [
          row('example-b', authenticated: true, models: ['example-model-b']),
        ],
      });

      expect(options.currentMissing, isTrue);
      expect(
        options.missing,
        const ModelChoice('example-a', 'example-model-a'),
      );
      expect(options.providers, hasLength(1));
    });

    test('currentMissing holds with no provider ready at all', () {
      final options = ModelOptions.fromJson({
        'provider': 'example-a',
        'model': 'example-model-a',
        'providers': <Object?>[],
      });

      expect(options.currentMissing, isTrue);
    });

    test('the default provider among the rows is not missing', () {
      final ready = ModelOptions.fromJson({
        'provider': 'example-a',
        'model': 'example-model-a',
        'providers': [
          row('example-a', authenticated: true, models: ['example-model-a']),
        ],
      });
      final warming = ModelOptions.fromJson({
        'provider': 'example-a',
        'model': 'example-model-a',
        'providers': [row('example-a', authenticated: true)],
      });

      expect(ready.currentMissing, isFalse);
      expect(warming.currentMissing, isFalse);
      expect(warming.warming, isTrue);
    });

    test('a fresh profile with no default is not missing anything', () {
      final options = ModelOptions.fromJson({
        'provider': '',
        'model': '',
        'providers': <Object?>[],
      });

      expect(options.currentMissing, isFalse);
      expect(options.warming, isFalse);
    });

    test('a provider that was named without a model is not missing', () {
      expect(
        ModelOptions.fromJson({
          'provider': 'example-a',
          'providers': <Object?>[],
        }).currentMissing,
        isFalse,
      );
    });
  });

  group('ModelOptions.model', () {
    test('finds a model within its own provider only', () {
      final options = ModelOptions.fromJson({
        'providers': [
          {
            'slug': 'a',
            'models': ['m'],
          },
        ],
      });

      expect(options.model(const ModelChoice('a', 'm'))?.id, 'm');
      expect(options.model(const ModelChoice('b', 'm')), isNull);
    });
  });

  test('effortLabel names every level the way the dashboard does', () {
    expect(
      [for (final effort in kReasoningEfforts) effortLabel(effort)],
      ['Off', 'Minimal', 'Low', 'Medium', 'High', 'Extra High', 'Max', 'Ultra'],
    );
  });

  test('a choice equals another with the same fields', () {
    expect(
      const ModelChoice('a', 'm', effort: 'high'),
      const ModelChoice('a', 'm', effort: 'high'),
    );
    expect(
      const ModelChoice('a', 'm', effort: 'high'),
      isNot(const ModelChoice('a', 'm')),
    );
  });
}
