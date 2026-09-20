enum CatalogTier { official, community }

/// One plugin of the Hermes catalog, with what the server knows about it
/// locally. The server pins each entry to a reviewed commit and resolves the
/// repository itself, so the repository URL is not read.
class CatalogEntry {
  const CatalogEntry({
    required this.name,
    this.description = '',
    this.maintainer = '',
    this.tier = CatalogTier.community,
    this.requiresHermes = '',
    this.platforms = const [],
    this.docsUrl = '',
    this.commit = '',
    this.providesTools = const [],
    this.providesHooks = const [],
    this.providesMiddleware = const [],
    this.requiresEnv = const [],
    this.installed = false,
    this.updateAvailable = false,
  });

  final String name;
  final String description;
  final String maintainer;
  final CatalogTier tier;

  /// A version constraint such as `>=0.20`, shown as text. Empty when none.
  final String requiresHermes;
  final List<String> platforms;
  final String docsUrl;

  /// The first characters of the pinned commit.
  final String commit;
  final List<String> providesTools;
  final List<String> providesHooks;
  final List<String> providesMiddleware;
  final List<String> requiresEnv;
  final bool installed;
  final bool updateAvailable;

  bool get official => tier == CatalogTier.official;
}
