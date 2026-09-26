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

    test('reads a body that is not a map as no options', () {
      expect(ModelOptions.fromJson('oops').providers, isEmpty);
      expect(ModelOptions.fromJson(null).current, isNull);
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
