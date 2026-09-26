/// The reasoning-effort levels Hermes accepts (`VALID_REASONING_EFFORTS`),
/// with `none` for thinking off.
const kReasoningEfforts = [
  'none',
  'minimal',
  'low',
  'medium',
  'high',
  'xhigh',
  'max',
  'ultra',
];

/// What the dashboard calls [effort].
String effortLabel(String effort) => switch (effort) {
  'none' => 'Off',
  'xhigh' => 'Extra High',
  '' => '',
  _ => effort[0].toUpperCase() + effort.substring(1),
};

/// A model and, optionally, a reasoning effort to run a chat with. A model id
/// is only unique within its provider, so the two travel together. A null
/// [effort] leaves the level to the server.
class ModelChoice {
  const ModelChoice(this.providerId, this.modelId, {this.effort});

  final String providerId;
  final String modelId;
  final String? effort;

  bool sameModel(ModelChoice other) =>
      providerId == other.providerId && modelId == other.modelId;

  @override
  bool operator ==(Object other) =>
      other is ModelChoice && sameModel(other) && effort == other.effort;

  @override
  int get hashCode => Object.hash(providerId, modelId, effort);

  @override
  String toString() => 'ModelChoice($providerId, $modelId, effort: $effort)';
}

/// One model a provider offers, with whether it reasons and whether that can
/// be turned off.
class ModelOption {
  const ModelOption({
    required this.id,
    this.reasoning = true,
    this.canDisableReasoning = false,
  });

  final String id;
  final bool reasoning;
  final bool canDisableReasoning;

  /// The effort levels to offer for this model; empty when it takes none.
  List<String> get efforts => !reasoning
      ? const []
      : canDisableReasoning
      ? kReasoningEfforts
      : kReasoningEfforts.sublist(1);
}

/// One authenticated provider from `GET /api/model/options` and its models.
class ModelProviderOption {
  const ModelProviderOption({
    required this.id,
    this.label = '',
    this.models = const [],
  });

  final String id;
  final String label;
  final List<ModelOption> models;

  String get displayLabel => label.isEmpty ? id : label;
}

/// The models a profile can chat with, and the one it uses by default.
class ModelOptions {
  const ModelOptions({this.providers = const [], this.current});

  /// Reads `GET /api/model/options`, which has no response schema. Only
  /// providers that are authenticated and list models are kept; rows that
  /// don't fit are skipped.
  factory ModelOptions.fromJson(Object? body) {
    final json = body is Map ? body : const {};
    final rows = json['providers'] is List ? json['providers'] as List : [];
    final model = json['model'];
    final provider = json['provider'];
    return ModelOptions(
      providers: [
        for (final row in rows.whereType<Map<Object?, Object?>>())
          ?_provider(row),
      ],
      current:
          model is String &&
              model.isNotEmpty &&
              provider is String &&
              provider.isNotEmpty
          ? ModelChoice(provider, model)
          : null,
    );
  }

  final List<ModelProviderOption> providers;

  /// The profile's configured model, which a chat without a choice runs.
  final ModelChoice? current;

  ModelOption? model(ModelChoice choice) {
    for (final provider in providers) {
      if (provider.id != choice.providerId) continue;
      for (final model in provider.models) {
        if (model.id == choice.modelId) return model;
      }
    }
    return null;
  }

  static ModelProviderOption? _provider(Map<Object?, Object?> row) {
    final slug = row['slug'];
    final ids = row['models'];
    if (slug is! String || slug.isEmpty || ids is! List) return null;
    if (row['authenticated'] == false) return null;
    final capabilities = row['capabilities'] is Map
        ? row['capabilities'] as Map
        : const {};
    final models = [
      for (final id in ids)
        if (id is String && id.isNotEmpty) _model(id, capabilities[id]),
    ];
    if (models.isEmpty) return null;
    final name = row['name'];
    return ModelProviderOption(
      id: slug,
      label: name is String ? name : '',
      models: models,
    );
  }

  static ModelOption _model(String id, Object? capabilities) {
    final caps = capabilities is Map ? capabilities : const {};
    return ModelOption(
      id: id,
      reasoning: caps['reasoning'] != false,
      canDisableReasoning: caps['can_disable_reasoning'] == true,
    );
  }
}
