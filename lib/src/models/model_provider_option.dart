/// Whether a model provider is authenticated on the server. `GET
/// /api/model/options` only lists a provider's models once it is; an
/// unauthenticated one (when `include_unconfigured` is set) still names what
/// it needs.
enum ModelProviderStatus { ready, needsSetup }

/// One model a provider offers, and the reasoning-effort levels the server
/// reports it accepts. An empty [supportedEfforts] means the model takes
/// none.
class ModelOption {
  const ModelOption({
    required this.id,
    this.label = '',
    this.supportedEfforts = const [],
  });

  final String id;
  final String label;
  final List<String> supportedEfforts;

  String get displayLabel => label.isEmpty ? id : label;
}

/// One provider from `GET /api/model/options`, scoped to a profile, with the
/// models it offers and what it still needs if it is not authenticated.
class ModelProviderOption {
  const ModelProviderOption({
    required this.id,
    this.label = '',
    this.status = ModelProviderStatus.needsSetup,
    this.models = const [],
    this.requiredEnv = const [],
  });

  final String id;
  final String label;
  final ModelProviderStatus status;
  final List<ModelOption> models;

  /// Names of environment variables the server needs for this provider. The
  /// server sends names only, never values.
  final List<String> requiredEnv;

  String get displayLabel => label.isEmpty ? id : label;

  bool get ready => status == ModelProviderStatus.ready;
}
