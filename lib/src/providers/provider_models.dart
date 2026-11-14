/// What the server's four provider answers say, merged into one list.
///
/// None of the routes declares a response schema, so everything here reads
/// plain decoded JSON leniently: a row that does not fit is skipped and
/// counted, and no input makes the merge throw. See
/// `openspec/changes/provider-setup/design.md`, "Merging four answers".
library;

/// How a provider is connected, first match wins: the OAuth catalog lists it
/// with a device-code flow, then an API key, then something only the server
/// can do, and a custom endpoint is its own kind.
enum ConnectMethod { account, key, onServer, endpoint }

/// What a saved credential is.
enum CredentialKind { apiKey, account, endpointKey, poolKey }

/// One credential a connected provider holds. It carries at most the last
/// four characters of a key, never the key.
class ProviderCredential {
  const ProviderCredential({
    required this.kind,
    this.keyEnv,
    this.lastFour,
    this.source,
    this.label,
  });

  final CredentialKind kind;

  /// The `.env` variable of an [CredentialKind.apiKey].
  final String? keyEnv;

  /// The last four characters; null when the server shows none (a short key).
  final String? lastFour;

  /// Where a sign-in came from (`status.source`), such as `env_var`.
  final String? source;

  /// A hand-added pool key's label.
  final String? label;
}

/// The extra facts of a custom endpoint.
class EndpointDetails {
  const EndpointDetails({
    required this.baseUrl,
    this.model = '',
    this.models = const [],
    this.apiMode,
    this.contextLength,
    this.discoverModels = false,
    this.hasApiKey = false,
    this.source = '',
  });

  final String baseUrl;
  final String model;
  final List<String> models;

  /// `chat_completions`, `codex_responses`, `anthropic_messages`, or null.
  final String? apiMode;
  final int? contextLength;
  final bool discoverModels;
  final bool hasApiKey;

  /// `providers`, `custom_providers` (legacy) or `direct-config`.
  final String source;
}

/// One provider, connected or not.
class ProviderEntry {
  const ProviderEntry({
    required this.id,
    required this.name,
    required this.method,
    this.connected = false,
    this.isDefault = false,
    this.credentials = const [],
    this.models = const [],
    this.totalModels = 0,
    this.keyEnv,
    this.keyUrl,
    this.serverCommand,
    this.externalAccount = false,
    this.authType = '',
    this.warning,
    this.docsUrl,
    this.disconnectable = false,
    this.disconnectHint,
    this.disconnectCommand,
    this.endpoint,
  });

  /// The slug: the options row's, the sign-in's or the endpoint's id.
  final String id;
  final String name;
  final ConnectMethod method;
  final bool connected;
  final bool isDefault;
  final List<ProviderCredential> credentials;

  /// Model ids Hermes lists for it (none while its catalog warms up).
  final List<String> models;
  final int totalModels;

  /// The variable a key is saved under, for [ConnectMethod.key].
  final String? keyEnv;

  /// Where the provider issues keys, as the server sent it. Not checked here:
  /// the one link check runs before anything opens it.
  final String? keyUrl;

  /// The command to run on the server for [ConnectMethod.onServer], and for a
  /// key provider that also has a server-side account.
  final String? serverCommand;

  /// A key provider that can also be connected by an account on the server.
  final bool externalAccount;

  /// The registry's `auth_type`, as given (only skeleton rows carry one).
  final String authType;
  final String? warning;
  final String? docsUrl;

  /// Whether Hermes can sign the account out, and what to show otherwise.
  final bool disconnectable;
  final String? disconnectHint;
  final String? disconnectCommand;
  final EndpointDetails? endpoint;

  /// The sign-in this provider holds, if any.
  ProviderCredential? get account {
    for (final c in credentials) {
      if (c.kind == CredentialKind.account) return c;
    }
    return null;
  }
}

/// Providers Hermes recommends first when adding one, in this order. The
/// server sends no ranking; this only orders the list.
const kRecommendedProviderSlugs = ['nous', 'openrouter', 'openai', 'anthropic'];

/// Rows that are not providers to connect: the mixture-of-agents pseudo
/// provider and the managed local runtime.
const _hiddenSlugs = {'moa', 'local-runtime', 'local_runtime'};
const _hiddenAuthTypes = {'virtual', 'local_runtime', 'managed_local'};

/// The merged answer: every provider, the default model and how many rows
/// did not parse.
class ProviderCatalog {
  const ProviderCatalog({
    this.entries = const [],
    this.defaultProvider = '',
    this.defaultModel = '',
    this.skippedRows = 0,
  });

  /// Connected providers first (the default's first, then Hermes' order, then
  /// endpoints), then the rest, recommended ones ahead of the alphabet.
  final List<ProviderEntry> entries;
  final String defaultProvider;
  final String defaultModel;
  final int skippedRows;

  List<ProviderEntry> get connected => [
    for (final e in entries)
      if (e.connected) e,
  ];

  List<ProviderEntry> get available => [
    for (final e in entries)
      if (!e.connected) e,
  ];

  ProviderEntry? byId(String id) {
    for (final e in entries) {
      if (e.id == id) return e;
    }
    return null;
  }
}

/// The last four characters of a saved key from Hermes' display sentinel
/// `«redacted:sk-o...4f2a»`; null for `«redacted:***»` (a short key shows
/// nothing), for anything else, and for a string that is no sentinel.
String? lastFourFromRedacted(Object? value) {
  if (value is! String) return null;
  const open = '«redacted:';
  if (!value.startsWith(open) || !value.endsWith('»')) return null;
  final inner = value.substring(open.length, value.length - 1);
  final cut = inner.lastIndexOf('...');
  if (cut < 0) return null;
  final tail = inner.substring(cut + 3);
  return tail.length < 4 ? null : tail.substring(tail.length - 4);
}

String? _text(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

List<String> _strings(Object? value) => [
  if (value is List)
    for (final item in value)
      if (item is String && item.isNotEmpty) item,
];

/// A JSON object, with any key type turned into strings.
Map<String, Object?>? _map(Object? value) =>
    value is Map ? {for (final e in value.entries) '${e.key}': e.value} : null;

class _Draft {
  _Draft(this.id, this.name);

  final String id;
  String name;
  bool optionsRow = false;
  bool authenticated = false;
  bool current = false;
  String authType = '';
  String? keyEnv;
  String? warning;
  List<String> models = const [];
  int totalModels = 0;
  Map<String, Object?>? oauth;
  final keys = <(String, Map<String, Object?>)>[];
}

/// Merges the answers into one [ProviderCatalog]. Each argument is a decoded
/// JSON body, or null (anything that is no object counts as null) when the
/// source is missing, failed or is not offered; the rest still merge. Never
/// throws.
ProviderCatalog mergeProviders({
  Object? options,
  Object? env,
  Object? oauth,
  Object? endpoints,
  Object? pool,
}) {
  var skipped = 0;
  final optionsBody = _map(options);
  final envBody = _map(env);
  final oauthBody = _map(oauth);
  final endpointsBody = _map(endpoints);
  final poolBody = _map(pool);

  final drafts = <String, _Draft>{};
  final order = <String>[];
  _Draft draft(String id, String name) {
    final existing = drafts[id];
    if (existing != null) return existing;
    order.add(id);
    return drafts[id] = _Draft(id, name);
  }

  final defaultProvider = _text(optionsBody?['provider']) ?? '';
  final defaultModel = _text(optionsBody?['model']) ?? '';

  // Rows the options answer holds for custom endpoints come from the
  // endpoints answer instead, when that was read.
  for (final raw in _list(optionsBody?['providers'])) {
    final row = _map(raw);
    final slug = _text(row?['slug']);
    if (row == null || slug == null) {
      skipped++;
      continue;
    }
    final authType = _text(row['auth_type']) ?? '';
    if (_hiddenSlugs.contains(slug) || _hiddenAuthTypes.contains(authType)) {
      continue;
    }
    if (row['is_user_defined'] == true && endpointsBody != null) continue;
    final d = draft(slug, _text(row['name']) ?? slug)
      ..optionsRow = true
      ..authenticated = row['authenticated'] != false
      ..current = row['is_current'] == true
      ..authType = authType
      ..keyEnv = _text(row['key_env'])
      ..warning = _text(row['warning'])
      ..models = _strings(row['models']);
    final total = row['total_models'];
    d.totalModels = total is int && total >= d.models.length
        ? total
        : d.models.length;
  }

  if (envBody != null) {
    for (final e in envBody.entries) {
      final row = _map(e.value);
      if (row == null) {
        skipped++;
        continue;
      }
      final slug = _text(row['provider']);
      if (slug == null || row['category'] != 'provider') continue;
      final isKey =
          row['is_password'] == true || row['provider_primary'] == true;
      if (!isKey) continue;
      drafts[slug]?.keys.add((e.key, row));
    }
  }

  if (oauthBody != null) {
    for (final raw in _list(oauthBody['providers'])) {
      final row = _map(raw);
      final id = _text(row?['id']);
      if (row == null || id == null) {
        skipped++;
        continue;
      }
      draft(id, _text(row['name']) ?? id).oauth = row;
    }
  }

  final entries = <ProviderEntry>[];
  for (final id in order) {
    entries.add(_build(drafts[id]!, defaultProvider));
  }

  // Credentials of hand-added pool keys, read-only.
  if (poolBody != null) {
    final extra = <String, List<ProviderCredential>>{};
    for (final raw in _list(poolBody['providers'])) {
      final group = _map(raw);
      final slug = _text(group?['provider']);
      if (group == null || slug == null) {
        skipped++;
        continue;
      }
      for (final rawEntry in _list(group['entries'])) {
        final entry = _map(rawEntry);
        if (entry == null) {
          skipped++;
          continue;
        }
        // Only keys a person added by hand. Sign-ins also make pool entries,
        // and an `env:` entry mirrors a key that is listed already.
        if (entry['source'] != 'manual' || entry['auth_type'] != 'api_key') {
          continue;
        }
        final preview = _text(entry['token_preview']);
        extra
            .putIfAbsent(slug, () => [])
            .add(
              ProviderCredential(
                kind: CredentialKind.poolKey,
                label: _text(entry['label']),
                lastFour:
                    lastFourFromRedacted(preview) ??
                    (preview != null && preview.length >= 4
                        ? preview.substring(preview.length - 4)
                        : null),
              ),
            );
      }
    }
    for (var i = 0; i < entries.length; i++) {
      final more = extra[entries[i].id];
      if (more == null) continue;
      entries[i] = _with(entries[i], [...entries[i].credentials, ...more]);
    }
  }

  final endpointEntries = <ProviderEntry>[];
  if (endpointsBody != null) {
    final seen = <String>{};
    for (final raw in _list(endpointsBody['endpoints'])) {
      final row = _map(raw);
      final id = _text(row?['id']);
      if (row == null || id == null || !seen.add(id)) {
        skipped++;
        continue;
      }
      final hasKey = row['has_api_key'] == true;
      final models = _strings(row['models']);
      final context = row['context_length'];
      endpointEntries.add(
        ProviderEntry(
          id: id,
          name: _text(row['name']) ?? id,
          method: ConnectMethod.endpoint,
          connected: true,
          isDefault: row['is_current'] == true,
          models: models,
          totalModels: models.length,
          credentials: [
            if (hasKey)
              ProviderCredential(
                kind: CredentialKind.endpointKey,
                lastFour: lastFourFromRedacted(row['api_key_preview']),
              ),
          ],
          endpoint: EndpointDetails(
            baseUrl: _text(row['base_url']) ?? '',
            model: _text(row['model']) ?? '',
            models: models,
            apiMode: _text(row['api_mode']),
            contextLength: context is int && context > 0 ? context : null,
            discoverModels: row['discover_models'] == true,
            hasApiKey: hasKey,
            source: _text(row['source']) ?? '',
          ),
        ),
      );
    }
  }

  final connected = [...entries.where((e) => e.connected), ...endpointEntries];
  final defaultAt = connected.indexWhere((e) => e.isDefault);
  if (defaultAt > 0) connected.insert(0, connected.removeAt(defaultAt));

  final rest = entries.where((e) => !e.connected).toList();
  int rank(ProviderEntry e) {
    final at = kRecommendedProviderSlugs.indexOf(e.id);
    return at < 0 ? kRecommendedProviderSlugs.length : at;
  }

  rest.sort((a, b) {
    final byRank = rank(a).compareTo(rank(b));
    if (byRank != 0) return byRank;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });

  return ProviderCatalog(
    entries: [...connected, ...rest],
    defaultProvider: defaultProvider,
    defaultModel: defaultModel,
    skippedRows: skipped,
  );
}

List<Object?> _list(Object? value) => value is List ? value : const [];

ProviderEntry _with(ProviderEntry e, List<ProviderCredential> credentials) =>
    ProviderEntry(
      id: e.id,
      name: e.name,
      method: e.method,
      connected: e.connected,
      isDefault: e.isDefault,
      credentials: credentials,
      models: e.models,
      totalModels: e.totalModels,
      keyEnv: e.keyEnv,
      keyUrl: e.keyUrl,
      serverCommand: e.serverCommand,
      externalAccount: e.externalAccount,
      authType: e.authType,
      warning: e.warning,
      docsUrl: e.docsUrl,
      disconnectable: e.disconnectable,
      disconnectHint: e.disconnectHint,
      disconnectCommand: e.disconnectCommand,
      endpoint: e.endpoint,
    );

ProviderEntry _build(_Draft d, String defaultProvider) {
  final oauth = d.oauth;
  final flow = _text(oauth?['flow']);
  final status = _map(oauth?['status']);
  final loggedIn = status?['logged_in'] == true;

  // The env key the provider's card asks for: the primary one, else the
  // skeleton's, else the first password variable.
  (String, Map<String, Object?>)? primary;
  for (final k in d.keys) {
    if (k.$2['provider_primary'] == true) {
      primary = k;
      break;
    }
  }
  final keyEnv =
      primary?.$1 ?? d.keyEnv ?? (d.keys.isEmpty ? null : d.keys.first.$1);
  final hasKeyMethod =
      primary != null || (d.authType == 'api_key' && d.keyEnv != null);

  final ConnectMethod method;
  if (oauth != null && flow == 'device_code') {
    method = ConnectMethod.account;
  } else if (hasKeyMethod) {
    method = ConnectMethod.key;
  } else {
    method = ConnectMethod.onServer;
  }

  final externalAccount =
      oauth != null && flow != 'device_code' && method == ConnectMethod.key;
  final command = _text(oauth?['cli_command']);
  final serverCommand = method == ConnectMethod.onServer || externalAccount
      ? command ?? 'hermes auth add ${d.id}'
      : null;

  final credentials = [
    for (final k in d.keys)
      if (k.$2['is_set'] == true)
        ProviderCredential(
          kind: CredentialKind.apiKey,
          keyEnv: k.$1,
          lastFour: lastFourFromRedacted(k.$2['redacted_value']),
        ),
    if (loggedIn)
      ProviderCredential(
        kind: CredentialKind.account,
        source: _text(status?['source']),
      ),
  ];

  final keyRow = primary?.$2 ?? (d.keys.isEmpty ? null : d.keys.first.$2);
  return ProviderEntry(
    id: d.id,
    name: d.name,
    method: method,
    connected: (d.optionsRow && d.authenticated) || loggedIn,
    isDefault:
        d.current || (defaultProvider.isNotEmpty && d.id == defaultProvider),
    credentials: credentials,
    models: d.models,
    totalModels: d.totalModels,
    keyEnv: method == ConnectMethod.key ? keyEnv : null,
    keyUrl: _text(keyRow?['url']),
    serverCommand: serverCommand,
    externalAccount: externalAccount,
    authType: d.authType,
    warning: d.warning,
    docsUrl: _text(oauth?['docs_url']),
    disconnectable: oauth?['disconnectable'] == true,
    disconnectHint: _text(oauth?['disconnect_hint']),
    disconnectCommand: _text(oauth?['disconnect_command']),
  );
}
