import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/models/model_provider_option.dart';
import 'package:hermes_app/src/models/moa_setup.dart';

import 'support/fake_hermes_server.dart';

void main() {
  test('reads the default preset\'s advisors and aggregator', () {
    final moa = MoaSetup.fromJson(moaConfigBody())!;

    expect(moa.preset, 'default');
    expect(moa.slots.map((s) => s.label), [
      'Advisor 1',
      'Advisor 2',
      'Aggregator',
    ]);
    expect(moa.slots[0].choice, const ModelChoice('openai-codex', 'gpt-5.5'));
    expect(moa.slots[0].enabled, isTrue);
    expect(
      moa.slots[1].choice,
      const ModelChoice(
        'openrouter',
        'deepseek/deepseek-v4-pro',
        effort: 'high',
      ),
    );
    expect(moa.slots[1].enabled, isFalse);
    expect(
      moa.slots[2].choice,
      const ModelChoice('openrouter', 'anthropic/claude-opus-4.8'),
    );
  });

  test('names the preset the server calls default', () {
    expect(MoaSetup.fromJson(moaConfigBody(preset: 'deep'))!.preset, 'deep');
  });

  test('no preset or no body reads as no setup', () {
    expect(MoaSetup.fromJson(null), isNull);
    expect(MoaSetup.fromJson({'presets': {}}), isNull);
    expect(MoaSetup.fromJson({'default_preset': 'x', 'presets': {}}), isNull);
  });

  test('withSlot changes that slot only and keeps the rest', () {
    final moa = MoaSetup.fromJson(moaConfigBody())!;
    final advisor = moa.slots[1];

    final next = moa.withSlot(
      advisor.key,
      const ModelChoice('anthropic', 'claude-sonnet-4-5'),
    );

    final json = next.toJson();
    final presets = json['presets'] as Map;
    final refs = (presets['default'] as Map)['reference_models'] as List;
    expect(refs[2], {
      'provider': 'anthropic',
      'model': 'claude-sonnet-4-5',
      'enabled': false,
    });
    expect(refs[0], {
      'provider': 'openai-codex',
      'model': 'gpt-5.5',
      'enabled': true,
    });
    expect(presets['cheap'], (moaConfigBody()['presets'] as Map)['cheap']);
    expect((presets['default'] as Map)['reference_temperature'], 0.7);
    expect(
      next.slots[1].choice,
      const ModelChoice('anthropic', 'claude-sonnet-4-5'),
    );
    expect(moa.slots[1].choice.modelId, 'deepseek/deepseek-v4-pro');

    final aggregator = next
        .withSlot(
          'moa-aggregator',
          const ModelChoice('nous', 'hermes-4', effort: 'low'),
        )
        .toJson();
    expect(((aggregator['presets'] as Map)['default'] as Map)['aggregator'], {
      'provider': 'nous',
      'model': 'hermes-4',
      'reasoning_effort': 'low',
    });
  });
}
