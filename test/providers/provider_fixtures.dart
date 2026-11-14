// Answers of the provider routes, in the shapes design.md records from Hermes
// d923a5eb (0.22.2). Hand-made from that description: task 1.1's recording
// against a throwaway backend was not possible in the delivery environment,
// so the contract test checks these shapes against a real one. Model names
// are neutral examples, and no key here is real.

/// A skeleton or connected row of `GET /api/model/options`.
Map<String, Object?> optionsRow(
  String slug, {
  String? name,
  bool authenticated = true,
  bool current = false,
  bool userDefined = false,
  List<String> models = const [],
  int? total,
  String? authType,
  String? keyEnv,
  String? warning,
}) => {
  'slug': slug,
  'name': name ?? slug,
  'is_current': current,
  'is_user_defined': userDefined,
  'models': models,
  'total_models': total ?? models.length,
  'authenticated': authenticated,
  'auth_type': ?authType,
  'key_env': ?keyEnv,
  'warning': ?warning,
};

Map<String, Object?> optionsBody(
  List<Object?> rows, {
  String model = '',
  String provider = '',
}) => {'providers': rows, 'model': model, 'provider': provider};

/// A `GET /api/env` variable row.
Map<String, Object?> envRow({
  required String provider,
  String? label,
  bool isSet = false,
  String? redacted,
  bool primary = true,
  bool password = true,
  String? url,
  String category = 'provider',
}) => {
  'is_set': isSet,
  'redacted_value': isSet ? redacted : null,
  'description': '${label ?? provider} API key',
  'url': url,
  'category': category,
  'is_password': password,
  'advanced': false,
  'provider': provider,
  'provider_label': label ?? provider,
  'provider_primary': primary,
  'custom': false,
};

/// A `GET /api/providers/oauth` row.
Map<String, Object?> oauthRow(
  String id, {
  String? name,
  String flow = 'device_code',
  bool loggedIn = false,
  String? source,
  String? cliCommand,
  bool disconnectable = true,
  String? disconnectHint,
  String? disconnectCommand,
  String? docsUrl,
}) => {
  'id': id,
  'name': name ?? id,
  'flow': flow,
  'cli_command': cliCommand ?? 'hermes auth add $id',
  'docs_url': docsUrl ?? 'https://docs.example.com/$id',
  'disconnect_hint': disconnectHint,
  'disconnect_command': disconnectCommand,
  'disconnectable': disconnectable,
  'status': {
    'logged_in': loggedIn,
    'source': source,
    'source_label': source == null ? null : 'label of $source',
    'token_preview': loggedIn ? 'abcdef' : null,
    'expires_at': null,
    'has_refresh_token': loggedIn,
  },
};

Map<String, Object?> endpointRow(
  String id, {
  String? name,
  String baseUrl = 'http://127.0.0.1:8283/v1',
  String model = 'example-model-a',
  List<String> models = const ['example-model-a', 'example-model-b'],
  bool hasKey = false,
  String? keyPreview,
  bool current = false,
}) => {
  'id': id,
  'name': name ?? id,
  'base_url': baseUrl,
  'model': model,
  'models': models,
  'api_mode': null,
  'context_length': null,
  'discover_models': true,
  'has_api_key': hasKey,
  'api_key_preview': keyPreview,
  'is_current': current,
  'source': 'providers',
};

Map<String, Object?> poolEntry({
  int index = 1,
  String source = 'manual',
  String authType = 'api_key',
  String? label,
  String tokenPreview = 'abc123',
}) => {
  'index': index,
  'id': 'cred$index',
  'label': label ?? 'key $index',
  'auth_type': authType,
  'source': source,
  'priority': 0,
  'last_status': null,
  'request_count': 0,
  'token_preview': tokenPreview,
  'has_refresh': false,
};

/// A fresh profile: every canonical provider is a skeleton, nothing is
/// connected, and the `moa` and local-runtime rows are among them.
Map<String, Object?> emptyProfileOptions() => optionsBody([
  optionsRow(
    'openrouter',
    name: 'OpenRouter',
    authenticated: false,
    authType: 'api_key',
    keyEnv: 'OPENROUTER_API_KEY',
  ),
  optionsRow(
    'nous',
    name: 'Nous Portal',
    authenticated: false,
    authType: 'oauth_device_code',
  ),
  optionsRow(
    'anthropic',
    name: 'Anthropic',
    authenticated: false,
    authType: 'api_key',
    keyEnv: 'ANTHROPIC_API_KEY',
  ),
  optionsRow(
    'openai-codex',
    name: 'ChatGPT or Codex',
    authenticated: false,
    authType: 'oauth_external',
  ),
  optionsRow(
    'copilot',
    name: 'GitHub Copilot',
    authenticated: false,
    authType: 'copilot',
  ),
  optionsRow(
    'zeta',
    name: 'Zeta Labs',
    authenticated: false,
    authType: 'api_key',
    keyEnv: 'ZETA_API_KEY',
  ),
  optionsRow('moa', name: 'Mixture of agents', authType: 'virtual'),
  optionsRow('local-runtime', name: 'Local runtime', authenticated: false),
  optionsRow('mystery', name: 'Mystery', authenticated: false, authType: 'x9'),
]);

Map<String, Object?> emptyProfileEnv() => {
  'OPENROUTER_API_KEY': envRow(
    provider: 'openrouter',
    label: 'OpenRouter',
    url: 'https://openrouter.ai/keys',
  ),
  'ANTHROPIC_API_KEY': envRow(
    provider: 'anthropic',
    label: 'Anthropic',
    url: 'https://console.example.com/keys',
  ),
  'ZETA_API_KEY': envRow(provider: 'zeta', label: 'Zeta Labs'),
  'ZETA_BASE_URL': envRow(provider: 'zeta', primary: false, password: false),
  'TELEGRAM_BOT_TOKEN': envRow(provider: 'telegram', category: 'messaging'),
};

Map<String, Object?> emptyProfileOauth() => {
  'providers': [
    oauthRow('nous', name: 'Nous Portal'),
    oauthRow('openai-codex', name: 'ChatGPT or Codex'),
    oauthRow(
      'anthropic',
      name: 'Anthropic account',
      flow: 'external',
      cliCommand: 'hermes auth add anthropic',
    ),
    oauthRow('qwen-oauth', name: 'Qwen', flow: 'external'),
  ],
};

Map<String, Object?> noEndpoints() => {
  'endpoints': <Object?>[],
  'current': {'provider': '', 'model': '', 'base_url': ''},
};

Map<String, Object?> emptyPool() => {'providers': <Object?>[]};

/// OpenRouter connected by a key and the default, with a custom endpoint
/// and a ChatGPT sign-in.
Map<String, Object?> connectedOptions() => optionsBody(
  [
    optionsRow(
      'openrouter',
      name: 'OpenRouter',
      current: true,
      models: ['example-model-a', 'example-model-b'],
      total: 40,
    ),
    optionsRow(
      'openai-codex',
      name: 'ChatGPT or Codex',
      models: ['example-model-c'],
    ),
    optionsRow(
      'anthropic',
      name: 'Anthropic',
      authenticated: false,
      authType: 'api_key',
      keyEnv: 'ANTHROPIC_API_KEY',
    ),
    optionsRow(
      'custom:lab',
      name: 'lab',
      userDefined: true,
      models: ['example-model-a'],
    ),
  ],
  model: 'example-model-a',
  provider: 'openrouter',
);

Map<String, Object?> connectedEnv() => {
  'OPENROUTER_API_KEY': envRow(
    provider: 'openrouter',
    label: 'OpenRouter',
    isSet: true,
    redacted: '«redacted:sk-o...4f2a»',
    url: 'https://openrouter.ai/keys',
  ),
  'ANTHROPIC_API_KEY': envRow(provider: 'anthropic', label: 'Anthropic'),
};

Map<String, Object?> connectedOauth() => {
  'providers': [
    oauthRow(
      'openai-codex',
      name: 'ChatGPT or Codex',
      loggedIn: true,
      source: 'device_code',
    ),
    oauthRow('nous', name: 'Nous Portal'),
  ],
};

Map<String, Object?> oneEndpoint() => {
  'endpoints': [
    endpointRow(
      'lab',
      name: 'Lab server',
      hasKey: true,
      keyPreview: r'${LAB_API_KEY}',
    ),
  ],
  'current': {'provider': '', 'model': '', 'base_url': ''},
};

Map<String, Object?> connectedPool() => {
  'providers': [
    {
      'provider': 'openrouter',
      'entries': [
        poolEntry(source: 'env:OPENROUTER_API_KEY'),
        poolEntry(index: 2, label: 'spare', tokenPreview: 'zz9876'),
      ],
    },
    {
      'provider': 'openai-codex',
      'entries': [poolEntry(source: 'device_code', authType: 'oauth')],
    },
  ],
};
