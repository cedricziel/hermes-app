/// Whether a memory provider can be used: `ready`, `needs_config` (found but
/// not configured) or anything else, which reads as unavailable.
enum ProviderStatus { ready, needsSetup, unavailable }

/// A tool a memory provider needs outside Hermes, and how to install it.
class ExternalDependency {
  const ExternalDependency({
    required this.name,
    this.install = '',
    this.check = '',
  });

  final String name;

  /// A shell command for the user to run on the server. The app only shows it.
  final String install;
  final String check;
}

/// One memory provider the server knows, with what it needs to be ready. The
/// server sends names of environment variables, never their values.
class MemoryProviderOption {
  const MemoryProviderOption({
    required this.name,
    this.description = '',
    this.status = ProviderStatus.unavailable,
    this.requiredEnv = const [],
    this.externalDependencies = const [],
    this.pipDependencies = const [],
  });

  final String name;
  final String description;
  final ProviderStatus status;
  final List<String> requiredEnv;
  final List<ExternalDependency> externalDependencies;
  final List<String> pipDependencies;

  bool get ready => status == ProviderStatus.ready;

  bool get namesRequirements =>
      requiredEnv.isNotEmpty ||
      externalDependencies.isNotEmpty ||
      pipDependencies.isNotEmpty;
}

class ContextEngineOption {
  const ContextEngineOption({required this.name, this.description = ''});

  final String name;
  final String description;
}

/// Which memory provider and context engine the server uses, and what it
/// offers. An empty [memoryProvider] is the built-in one.
class ProviderSettings {
  const ProviderSettings({
    this.memoryProvider = '',
    this.memoryOptions = const [],
    this.contextEngine = '',
    this.contextOptions = const [],
  });

  final String memoryProvider;
  final List<MemoryProviderOption> memoryOptions;
  final String contextEngine;
  final List<ContextEngineOption> contextOptions;
}
