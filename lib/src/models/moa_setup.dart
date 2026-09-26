import 'dart:convert';

import 'model_provider_option.dart';

/// An advisor or the aggregator of a mixture-of-agents preset. [key] finds
/// the slot again in [MoaSetup.withSlot].
class MoaSlot {
  const MoaSlot({
    required this.key,
    required this.label,
    required this.choice,
    this.enabled = true,
  });

  final String key;
  final String label;
  final ModelChoice choice;

  /// Only advisors can be switched off.
  final bool enabled;
}

const _aggregatorKey = 'moa-aggregator';
const _advisorPrefix = 'moa-advisor-';

/// The default preset of a profile's mixture of agents, from
/// `GET /api/model/moa`. The whole answer is kept, so a save sends back
/// everything the app does not edit as the server reported it.
class MoaSetup {
  const MoaSetup._(this._raw, this.preset, this.slots);

  /// The route has no response schema. Null when the answer names no preset
  /// with a usable slot; slots without a provider and model are skipped.
  static MoaSetup? fromJson(Object? body) {
    if (body is! Map) return null;
    final raw = body.cast<String, Object?>();
    final presets = raw['presets'];
    final name = raw['default_preset'];
    final preset = presets is Map && name is String ? presets[name] : null;
    if (preset is! Map || name is! String) return null;
    final refs = preset['reference_models'];
    final slots = <MoaSlot>[];
    if (refs is List) {
      for (final (i, row) in refs.indexed) {
        final choice = _choice(row);
        if (choice == null) continue;
        slots.add(
          MoaSlot(
            key: '$_advisorPrefix$i',
            label: 'Advisor ${slots.length + 1}',
            choice: choice,
            enabled: (row as Map)['enabled'] != false,
          ),
        );
      }
    }
    final aggregator = _choice(preset['aggregator']);
    if (aggregator != null) {
      slots.add(
        MoaSlot(key: _aggregatorKey, label: 'Aggregator', choice: aggregator),
      );
    }
    return slots.isEmpty ? null : MoaSetup._(raw, name, slots);
  }

  final Map<String, Object?> _raw;

  /// The name of the preset the slots belong to.
  final String preset;
  final List<MoaSlot> slots;

  /// The setup with the slot under [key] running [choice], its other fields
  /// (such as `enabled`) kept.
  MoaSetup withSlot(String key, ModelChoice choice) {
    Map<String, Object?> put(Object? old) => {
      for (final MapEntry(:key, :value)
          in (old is Map ? old : const {}).entries)
        if (key != 'reasoning_effort') key as String: value,
      'provider': choice.providerId,
      'model': choice.modelId,
      'reasoning_effort': ?choice.effort,
    };

    final presets = (_raw['presets']! as Map).cast<String, Object?>();
    final preset = {...(presets[this.preset]! as Map).cast<String, Object?>()};
    if (key == _aggregatorKey) {
      preset['aggregator'] = put(preset['aggregator']);
    } else {
      final index = int.parse(key.substring(_advisorPrefix.length));
      final refs = [...preset['reference_models']! as List];
      refs[index] = put(refs[index]);
      preset['reference_models'] = refs;
    }
    return fromJson({
      ..._raw,
      'presets': {...presets, this.preset: preset},
    })!;
  }

  /// A plain JSON copy, with every map typed as the generated client expects.
  Map<String, dynamic> toJson() =>
      jsonDecode(jsonEncode(_raw)) as Map<String, dynamic>;

  static ModelChoice? _choice(Object? row) {
    if (row is! Map) return null;
    final provider = row['provider'];
    final model = row['model'];
    final effort = row['reasoning_effort'];
    if (provider is! String || provider.isEmpty) return null;
    if (model is! String || model.isEmpty) return null;
    return ModelChoice(
      provider,
      model,
      effort: effort is String && effort.isNotEmpty ? effort : null,
    );
  }
}
