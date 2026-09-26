import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/models/auxiliary_models.dart';
import 'package:hermes_app/src/models/model_provider_option.dart';

void main() {
  test('reads the slots in order, pinned or on auto, and the main model', () {
    final models = AuxiliaryModels.fromJson({
      'tasks': [
        {
          'task': 'vision',
          'provider': 'auto',
          'model': '',
          'base_url': '',
          'reasoning_effort': null,
          'local_endpoint': false,
        },
        {
          'task': 'title_generation',
          'provider': 'openrouter',
          'model': 'gemini-flash',
          'base_url': '',
          'reasoning_effort': 'low',
          'local_endpoint': false,
        },
        {'task': 'curator', 'provider': '', 'model': ''},
        {'provider': 'openai', 'model': 'gpt-5'},
        'junk',
        {'task': 'brand_new_job', 'provider': 'openai', 'model': 'gpt-5'},
      ],
      'main': {'provider': 'anthropic', 'model': 'claude-opus-4'},
    });

    expect(models.slots.map((s) => s.task), [
      'vision',
      'title_generation',
      'curator',
      'brand_new_job',
    ]);
    expect(models.slots[0].choice, isNull);
    expect(
      models.slots[1].choice,
      const ModelChoice('openrouter', 'gemini-flash', effort: 'low'),
    );
    expect(models.slots[2].choice, isNull);
    expect(models.main, const ModelChoice('anthropic', 'claude-opus-4'));
    expect(models.slots[1].label, 'Chat titles');
    expect(models.slots[3].label, 'brand_new_job');
  });

  test('a missing main model or body reads as none', () {
    expect(AuxiliaryModels.fromJson({'tasks': []}).main, isNull);
    expect(AuxiliaryModels.fromJson(null).slots, isEmpty);
  });

  test('withSlot replaces the slot of the same task', () {
    const models = AuxiliaryModels(
      slots: [
        AuxiliarySlot(task: 'vision'),
        AuxiliarySlot(task: 'compression'),
      ],
    );

    final next = models.withSlot(
      const AuxiliarySlot(task: 'vision', choice: ModelChoice('openai', 'x')),
    );

    expect(next.slots.first.choice, const ModelChoice('openai', 'x'));
    expect(next.slots.last.task, 'compression');
  });
}
