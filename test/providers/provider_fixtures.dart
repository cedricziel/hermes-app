// Answers of the provider routes. The `recorded…` constants at the end are
// answers of a throwaway Hermes d923a5eb (0.22.2) run on Linux, with invented
// names, example model ids and fake keys (see design.md, "Recorded answers");
// the builders above them are hand-made variants for the cases a healthy
// server does not produce (a 404 per source, an unknown `auth_type`, a short
// key preview, malformed rows). The contract test checks both against a real
// backend.

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
  String? source,
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
  'source': ?source,
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
  optionsRow(
    'llamacpp',
    name: 'llama.cpp',
    authType: 'local',
    source: 'local-runtime',
  ),
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

// ---- Recorded from Hermes d923a5eb ----

/// `GET /api/model/options?include_unconfigured=true` of a profile with nothing
/// set: ten of the 55 skeleton rows, verbatim (`key_env` is `""` for OpenRouter,
/// Nous and `custom`; GitHub Copilot is `api_key`; no `moa` or local-runtime row).
const recordedEmptyOptions = <String, Object?>{
  'providers': [
    {
      'slug': 'nous',
      'name': 'Nous Portal',
      'is_current': false,
      'is_user_defined': false,
      'models': <Object?>[],
      'total_models': 0,
      'source': 'canonical',
      'authenticated': false,
      'auth_type': 'oauth_device_code',
      'key_env': '',
      'warning': 'run `hermes model` to configure (oauth_device_code)',
      'capabilities': <String, Object?>{},
      'featured_models': <Object?>[],
    },
    {
      'slug': 'openrouter',
      'name': 'OpenRouter',
      'is_current': false,
      'is_user_defined': false,
      'models': <Object?>[],
      'total_models': 0,
      'source': 'canonical',
      'authenticated': false,
      'auth_type': 'api_key',
      'key_env': '',
      'warning': 'run `hermes model` to configure (api_key)',
      'capabilities': <String, Object?>{},
      'featured_models': <Object?>[],
    },
    {
      'slug': 'copilot',
      'name': 'GitHub Copilot',
      'is_current': false,
      'is_user_defined': false,
      'models': <Object?>[],
      'total_models': 0,
      'source': 'canonical',
      'authenticated': false,
      'auth_type': 'api_key',
      'key_env': 'COPILOT_GITHUB_TOKEN',
      'warning': 'paste COPILOT_GITHUB_TOKEN to activate',
      'capabilities': <String, Object?>{},
      'featured_models': <Object?>[],
    },
    {
      'slug': 'openai-codex',
      'name': 'ChatGPT or Codex Subscription',
      'is_current': false,
      'is_user_defined': false,
      'models': <Object?>[],
      'total_models': 0,
      'source': 'canonical',
      'authenticated': false,
      'auth_type': 'oauth_external',
      'key_env': '',
      'warning': 'run `hermes model` to configure (oauth_external)',
      'capabilities': <String, Object?>{},
      'featured_models': <Object?>[],
    },
    {
      'slug': 'openai-api',
      'name': 'OpenAI API',
      'is_current': false,
      'is_user_defined': false,
      'models': <Object?>[],
      'total_models': 0,
      'source': 'canonical',
      'authenticated': false,
      'auth_type': 'api_key',
      'key_env': 'OPENAI_API_KEY',
      'warning': 'paste OPENAI_API_KEY to activate',
      'capabilities': <String, Object?>{},
      'featured_models': <Object?>[],
    },
    {
      'slug': 'vertex',
      'name': 'Google Vertex AI',
      'is_current': false,
      'is_user_defined': false,
      'models': <Object?>[],
      'total_models': 0,
      'source': 'canonical',
      'authenticated': false,
      'auth_type': 'vertex',
      'key_env': '',
      'warning': 'run `hermes model` to configure (vertex)',
      'capabilities': <String, Object?>{},
      'featured_models': <Object?>[],
    },
    {
      'slug': 'bedrock',
      'name': 'AWS Bedrock',
      'is_current': false,
      'is_user_defined': false,
      'models': <Object?>[],
      'total_models': 0,
      'source': 'canonical',
      'authenticated': false,
      'auth_type': 'aws_sdk',
      'key_env': '',
      'warning': 'run `hermes model` to configure (aws_sdk)',
      'capabilities': <String, Object?>{},
      'featured_models': <Object?>[],
    },
    {
      'slug': 'minimax-oauth',
      'name': 'MiniMax (OAuth)',
      'is_current': false,
      'is_user_defined': false,
      'models': <Object?>[],
      'total_models': 0,
      'source': 'canonical',
      'authenticated': false,
      'auth_type': 'oauth_minimax',
      'key_env': '',
      'warning': 'run `hermes model` to configure (oauth_minimax)',
      'capabilities': <String, Object?>{},
      'featured_models': <Object?>[],
    },
    {
      'slug': 'custom',
      'name': 'custom',
      'is_current': false,
      'is_user_defined': false,
      'models': <Object?>[],
      'total_models': 0,
      'source': 'canonical',
      'authenticated': false,
      'auth_type': 'api_key',
      'key_env': '',
      'warning': 'run `hermes model` to configure (api_key)',
      'capabilities': <String, Object?>{},
      'featured_models': <Object?>[],
    },
    {
      'slug': 'lmstudio',
      'name': 'LM Studio',
      'is_current': false,
      'is_user_defined': false,
      'models': <Object?>[],
      'total_models': 0,
      'source': 'canonical',
      'authenticated': false,
      'auth_type': 'api_key',
      'key_env': 'LM_API_KEY',
      'warning': 'paste LM_API_KEY to activate',
      'capabilities': <String, Object?>{},
      'featured_models': <Object?>[],
    },
  ],
  'model': '',
  'provider': '',
};

/// Four provider rows of `GET /api/env` of the same profile, verbatim.
const recordedEmptyEnv = <String, Object?>{
  'OPENROUTER_API_KEY': {
    'is_set': false,
    'redacted_value': null,
    'description':
        'OpenRouter API key (for vision, web scraping helpers, and MoA)',
    'url': 'https://openrouter.ai/keys',
    'category': 'provider',
    'is_password': true,
    'tools': ['vision_analyze'],
    'advanced': true,
    'channel_managed': false,
    'provider': 'openrouter',
    'provider_label': 'OpenRouter',
    'provider_profiles': <Object?>[],
    'provider_primary': true,
    'custom': false,
  },
  'OPENAI_API_KEY': {
    'is_set': false,
    'redacted_value': null,
    'description': 'OpenAI API (api.openai.com, API key)',
    'url': null,
    'category': 'provider',
    'is_password': true,
    'tools': <Object?>[],
    'advanced': false,
    'channel_managed': false,
    'provider': 'openai-api',
    'provider_label': 'OpenAI API',
    'provider_profiles': <Object?>[],
    'provider_primary': true,
    'custom': false,
  },
  'LM_API_KEY': {
    'is_set': false,
    'redacted_value': null,
    'description': 'LM Studio bearer token for auth-enabled local servers',
    'url': null,
    'category': 'provider',
    'is_password': true,
    'tools': <Object?>[],
    'advanced': true,
    'channel_managed': false,
    'provider': 'lmstudio',
    'provider_label': 'LM Studio',
    'provider_profiles': <Object?>[],
    'provider_primary': true,
    'custom': false,
  },
  'COPILOT_GITHUB_TOKEN': {
    'is_set': false,
    'redacted_value': null,
    'description': 'GitHub Copilot (Uses GITHUB_TOKEN or gh auth token)',
    'url': null,
    'category': 'provider',
    'is_password': true,
    'tools': <Object?>[],
    'advanced': false,
    'channel_managed': false,
    'provider': 'copilot',
    'provider_label': 'GitHub Copilot',
    'provider_profiles': <Object?>[],
    'provider_primary': true,
    'custom': false,
  },
};

/// `GET /api/providers/oauth`, all eight rows (the `qwen-oauth` label is a path on
/// the server; scrubbed).
const recordedOauth = <String, Object?>{
  'providers': [
    {
      'id': 'nous',
      'name': 'Nous Portal',
      'flow': 'device_code',
      'cli_command': 'hermes auth add nous',
      'docs_url': 'https://portal.nousresearch.com',
      'disconnect_hint': null,
      'disconnect_command': null,
      'disconnectable': true,
      'status': {
        'logged_in': false,
        'source': 'nous_portal',
        'source_label': 'Nous Portal',
        'token_preview': '',
        'expires_at': null,
        'has_refresh_token': false,
        'free_tier': false,
        'account_tier': null,
      },
    },
    {
      'id': 'openai-codex',
      'name': 'ChatGPT or Codex Subscription',
      'flow': 'device_code',
      'cli_command': 'hermes auth add openai-codex',
      'docs_url': 'https://platform.openai.com/docs',
      'disconnect_hint': null,
      'disconnect_command': null,
      'disconnectable': true,
      'status': {
        'logged_in': false,
        'source': 'openai_codex',
        'source_label': 'OpenAI Codex',
        'token_preview': '',
        'expires_at': null,
        'has_refresh_token': false,
        'last_refresh': null,
      },
    },
    {
      'id': 'qwen-oauth',
      'name': 'Qwen (via Qwen CLI)',
      'flow': 'external',
      'cli_command': 'hermes auth add qwen-oauth',
      'docs_url': 'https://github.com/QwenLM/qwen-code',
      'disconnect_hint': 'Managed by that provider\'s CLI; remove it there.',
      'disconnect_command': null,
      'disconnectable': false,
      'status': {
        'logged_in': false,
        'source': 'qwen_cli',
        'source_label': '/home/demo/.qwen/oauth_creds.json',
        'token_preview': '',
        'expires_at': null,
        'has_refresh_token': false,
      },
    },
    {
      'id': 'minimax-oauth',
      'name': 'MiniMax (OAuth)',
      'flow': 'device_code',
      'cli_command': 'hermes auth add minimax-oauth',
      'docs_url': 'https://www.minimax.io',
      'disconnect_hint': null,
      'disconnect_command': null,
      'disconnectable': true,
      'status': {
        'logged_in': false,
        'source': 'minimax_oauth',
        'source_label': 'MiniMax (global)',
        'token_preview': null,
        'expires_at': null,
        'has_refresh_token': true,
      },
    },
    {
      'id': 'xai-oauth',
      'name': 'xAI Grok OAuth (SuperGrok / Premium+)',
      'flow': 'device_code',
      'cli_command': 'hermes auth add xai-oauth',
      'docs_url':
          'https://hermes-agent.nousresearch.com/docs/guides/xai-grok-oauth',
      'disconnect_hint': null,
      'disconnect_command': null,
      'disconnectable': true,
      'status': {
        'logged_in': false,
        'source': 'xai_oauth',
        'source_label': '/home/demo/.qwen/oauth_creds.json',
        'token_preview': '',
        'expires_at': null,
        'has_refresh_token': true,
        'last_refresh': null,
      },
    },
    {
      'id': 'copilot-acp',
      'name': 'GitHub Copilot (ACP)',
      'flow': 'external',
      'cli_command': 'copilot login',
      'docs_url': 'https://docs.github.com/en/copilot',
      'disconnect_hint': 'Managed by that provider\'s CLI; remove it there.',
      'disconnect_command': null,
      'disconnectable': false,
      'status': {
        'logged_in': false,
        'source': 'copilot_cli',
        'source_label': 'GitHub Copilot CLI not found on PATH',
        'token_preview': null,
        'expires_at': null,
        'has_refresh_token': false,
        'configured': false,
      },
    },
    {
      'id': 'anthropic',
      'name': 'Anthropic Account',
      'flow': 'external',
      'cli_command': 'hermes auth add anthropic',
      'docs_url': 'https://docs.example.com/anthropic',
      'disconnect_hint': null,
      'disconnect_command': null,
      'disconnectable': true,
      'status': {'logged_in': false, 'source': null},
    },
    {
      'id': 'coder-cli',
      'name':
          'Anthropic OAuth: Required Extra Usage Credits to Use Subscription',
      'flow': 'external',
      'cli_command': 'coder setup-token',
      'docs_url': 'https://docs.example.com/coder-cli',
      'disconnect_hint':
          'Managed outside Hermes — run the disconnect command to remove it.',
      'disconnect_command': 'rm -f ~/.coder/.credentials.json',
      'disconnectable': false,
      'status': {'logged_in': false, 'source': null},
    },
  ],
};

/// `GET /api/providers/custom-endpoints` with none saved.
const recordedNoEndpoints = <String, Object?>{
  'endpoints': <Object?>[],
  'current': {'provider': '', 'model': '', 'base_url': ''},
};

/// `GET /api/credentials/pool` with nothing in it.
const recordedEmptyPool = <String, Object?>{'providers': <Object?>[]};

/// After `PUT /api/env` of `OPENROUTER_API_KEY` with `provider_setup: true` on a
/// profile with no default model: the connected row lists its models at once
/// (72 of them, three kept; `total_models` stays 72), carries no `auth_type` or
/// `key_env`, and `model` and `provider` are still empty. The local-runtime row
/// is the machine-wide staged model.
const recordedKeyOptions = <String, Object?>{
  'providers': [
    {
      'slug': 'openrouter',
      'name': 'OpenRouter',
      'is_current': false,
      'is_user_defined': false,
      'models': ['example-model-a', 'example-model-b', 'example-model-c'],
      'total_models': 72,
      'source': 'built-in',
      'authenticated': true,
      'capabilities': {
        'example-model-a': {
          'fast': false,
          'reasoning': true,
          'can_disable_reasoning': false,
        },
        'example-model-b': {
          'fast': false,
          'reasoning': true,
          'can_disable_reasoning': false,
        },
        'example-model-c': {
          'fast': false,
          'reasoning': true,
          'can_disable_reasoning': false,
        },
      },
      'featured_models': [
        'example-model-a',
        'example-model-b',
        'example-model-c',
      ],
    },
    {
      'slug': 'anthropic',
      'name': 'Anthropic',
      'is_current': false,
      'is_user_defined': false,
      'models': <Object?>[],
      'total_models': 0,
      'source': 'canonical',
      'authenticated': false,
      'auth_type': 'api_key',
      'key_env': 'ANTHROPIC_API_KEY',
      'warning': 'paste ANTHROPIC_API_KEY to activate',
      'capabilities': <String, Object?>{},
      'featured_models': <Object?>[],
    },
    {
      'slug': 'nous',
      'name': 'Nous Portal',
      'is_current': false,
      'is_user_defined': false,
      'models': <Object?>[],
      'total_models': 0,
      'source': 'canonical',
      'authenticated': false,
      'auth_type': 'oauth_device_code',
      'key_env': '',
      'warning': 'run `hermes model` to configure (oauth_device_code)',
      'capabilities': <String, Object?>{},
      'featured_models': <Object?>[],
    },
    {
      'slug': 'llamacpp',
      'name': 'Local',
      'is_current': false,
      'is_user_defined': false,
      'models': ['demo-local-model-q4'],
      'total_models': 1,
      'source': 'local-runtime',
      'authenticated': true,
      'auth_type': 'local',
      'warning': null,
      'capabilities': {
        'demo-local-model-q4': {'fast': false, 'reasoning': true},
      },
      'featured_models': <Object?>[],
    },
  ],
  'model': '',
  'provider': '',
};

/// The same key in `GET /api/env`: `«redacted:sk-o...0000»`, `provider_primary`.
const recordedKeyEnv = <String, Object?>{
  'OPENROUTER_API_KEY': {
    'is_set': true,
    'redacted_value': '«redacted:sk-o...0000»',
    'description':
        'OpenRouter API key (for vision, web scraping helpers, and MoA)',
    'url': 'https://openrouter.ai/keys',
    'category': 'provider',
    'is_password': true,
    'tools': ['vision_analyze'],
    'advanced': true,
    'channel_managed': false,
    'provider': 'openrouter',
    'provider_label': 'OpenRouter',
    'provider_profiles': <Object?>[],
    'provider_primary': true,
    'custom': false,
  },
};

/// And in the pool: an `env:` entry that mirrors the variable.
const recordedKeyPool = <String, Object?>{
  'providers': [
    {
      'provider': 'openrouter',
      'entries': [
        {
          'index': 1,
          'id': '19467f',
          'label': 'OPENROUTER_API_KEY',
          'auth_type': 'api_key',
          'source': 'env:OPENROUTER_API_KEY',
          'priority': 0,
          'last_status': null,
          'request_count': 0,
          'token_preview': 'sk-o...0000',
          'has_refresh': false,
        },
      ],
    },
  ],
};

/// The default provider's key removed (`DELETE /api/env`) on a profile whose
/// default is that provider: `provider` and `model` stay, and WITH
/// `include_unconfigured=true` the provider still has a row, unauthenticated, with
/// one model (the saved one) and Hermes' warning; without the flag (the chat
/// picker) it has none.
const recordedRemovedKeyOptions = <String, Object?>{
  'providers': [
    {
      'slug': 'openrouter',
      'name': 'OpenRouter',
      'is_current': true,
      'is_user_defined': false,
      'models': ['example-model-a'],
      'total_models': 1,
      'source': 'configured-current',
      'authenticated': false,
      'auth_type': 'api_key',
      'key_env': '',
      'warning': 'Configured provider is not authenticated; run `hermes model` to reactivate. Showing the saved model only.',
      'capabilities': {
        'example-model-a': {
          'fast': false,
          'reasoning': true,
          'can_disable_reasoning': false,
        },
      },
      'featured_models': <Object?>[],
    },
    {
      'slug': 'nous',
      'name': 'Nous Portal',
      'is_current': false,
      'is_user_defined': false,
      'models': <Object?>[],
      'total_models': 0,
      'source': 'canonical',
      'authenticated': false,
      'auth_type': 'oauth_device_code',
      'key_env': '',
      'warning': 'run `hermes model` to configure (oauth_device_code)',
      'capabilities': <String, Object?>{},
      'featured_models': <Object?>[],
    },
  ],
  'model': 'example-model-a',
  'provider': 'openrouter',
};

/// A custom endpoint saved (`POST /api/providers/custom-endpoints`) and made the
/// default (`POST /api/model/set` with provider `custom:demo-local`). Its row
/// is `is_user_defined` with the slug `demo-local` (NOT `custom:demo-local`; that
/// is one of its `aliases`), while the top-level `provider` is `custom:demo-local`.
const recordedEndpointOptions = <String, Object?>{
  'providers': [
    {
      'slug': 'demo-local',
      'name': 'Demo local',
      'is_current': true,
      'is_user_defined': true,
      'models': ['demo-model-a', 'demo-model-b'],
      'total_models': 2,
      'source': 'user-config',
      'api_url': 'http://127.0.0.1:8283/v1',
      'native_catalog_empty': false,
      'authenticated': true,
      'capabilities': {
        'demo-model-a': {'fast': false, 'reasoning': true},
        'demo-model-b': {'fast': false, 'reasoning': true},
      },
      'featured_models': <Object?>[],
      'aliases': ['custom:demo-local', 'demo local', 'demo-local'],
    },
    {
      'slug': 'custom',
      'name': 'custom',
      'is_current': false,
      'is_user_defined': false,
      'models': <Object?>[],
      'total_models': 0,
      'source': 'canonical',
      'authenticated': false,
      'auth_type': 'api_key',
      'key_env': '',
      'warning': 'run `hermes model` to configure (api_key)',
      'capabilities': <String, Object?>{},
      'featured_models': <Object?>[],
    },
  ],
  'model': 'demo-model-a',
  'provider': 'custom:demo-local',
};

/// The same endpoint in `GET /api/providers/custom-endpoints`: `api_key_preview` is
/// the variable reference, not a redaction.
const recordedEndpoints = <String, Object?>{
  'endpoints': [
    {
      'id': 'demo-local',
      'name': 'Demo local',
      'base_url': 'http://127.0.0.1:8283/v1',
      'model': 'demo-model-a',
      'models': ['demo-model-a'],
      'api_mode': '',
      'context_length': null,
      'discover_models': true,
      'has_api_key': true,
      'api_key_preview': '\${HERMES_CUSTOM_DEMO_LOCAL_API_KEY}',
      'is_current': true,
      'source': 'providers',
    },
  ],
  'current': {
    'provider': 'custom:demo-local',
    'model': 'demo-model-a',
    'base_url': 'http://127.0.0.1:8283/v1',
  },
};

/// `POST /api/providers/custom-endpoints/validate` against a loopback server.
const recordedEndpointValidate = <String, Object?>{
  'ok': true,
  'reachable': true,
  'message': '',
  'models': ['demo-model-a', 'demo-model-b'],
  'model_details': [
    {'id': 'demo-model-a'},
    {'id': 'demo-model-b'},
  ],
  'transport_checked': 'chat_completions',
  'resolved_base_url': 'http://127.0.0.1:8283/v1',
};

/// `GET /api/credentials/pool` after `POST /api/credentials/pool` of a manual key.
const recordedManualPool = <String, Object?>{
  'providers': [
    {
      'provider': 'openrouter',
      'entries': [
        {
          'index': 1,
          'id': '1fb54d',
          'label': 'manual demo',
          'auth_type': 'api_key',
          'source': 'manual',
          'priority': 0,
          'last_status': null,
          'request_count': 0,
          'token_preview': 'sk-o...0001',
          'has_refresh': false,
        },
      ],
    },
  ],
};

/// The options of that profile: a pool entry alone makes the provider
/// `authenticated` (its env variable is not set), and the opted-in `moa` row
/// (`auth_type: virtual`, `source: virtual`) and the local-runtime row
/// (`slug: llamacpp`, `name: Local`, `auth_type: local`, `source: local-runtime`) appear.
const recordedManualPoolOptions = <String, Object?>{
  'providers': [
    {
      'slug': 'openrouter',
      'name': 'OpenRouter',
      'is_current': false,
      'is_user_defined': false,
      'models': ['example-model-a', 'example-model-b', 'example-model-c'],
      'total_models': 59,
      'source': 'built-in',
      'authenticated': true,
      'capabilities': <String, Object?>{},
      'featured_models': [
        'example-model-a',
        'example-model-b',
        'example-model-c',
      ],
      'usage': {
        'accounts': [
          {
            'id': 'fp:155107ce24ab0881',
            'label': 'manual demo',
            'windows': <Object?>[],
            'state': 'unknown',
            'resets_at': null,
          },
          {
            'id': 'fp:228f64337b5beef1',
            'label': 'spare',
            'windows': <Object?>[],
            'state': 'unknown',
            'resets_at': null,
          },
        ],
      },
    },
    {
      'slug': 'moa',
      'name': 'Mixture of Agents',
      'is_current': false,
      'is_user_defined': false,
      'models': ['example-mix'],
      'total_models': 1,
      'source': 'virtual',
      'authenticated': true,
      'auth_type': 'virtual',
      'warning': 'Aggregator is the acting model billed for the run; references only advise once per user turn by default.',
      'capabilities': {
        'demo-mix': {'fast': false, 'reasoning': true},
      },
      'featured_models': <Object?>[],
    },
    {
      'slug': 'llamacpp',
      'name': 'Local',
      'is_current': false,
      'is_user_defined': false,
      'models': ['demo-local-model-q4'],
      'total_models': 1,
      'source': 'local-runtime',
      'authenticated': true,
      'auth_type': 'local',
      'warning': null,
      'capabilities': {
        'demo-local-model-q4': {'fast': false, 'reasoning': true},
      },
      'featured_models': <Object?>[],
    },
  ],
  'model': '',
  'provider': '',
};

/// `PUT /api/env` with `provider_setup: true`.
const recordedEnvSaved = <String, Object?>{
  'ok': true,
  'key': 'OPENROUTER_API_KEY',
  'config_updates': <Object?>[],
};

/// `POST /api/model/set` with provider `custom:demo-local`.
const recordedModelSet = <String, Object?>{
  'ok': true,
  'scope': 'main',
  'provider': 'custom:demo-local',
  'model': 'demo-model-a',
  'base_url': 'http://127.0.0.1:8283/v1',
  'gateway_tools': <Object?>[],
  'stale_aux': <Object?>[],
};

/// `POST /api/credentials/pool`.
const recordedPoolAdded = <String, Object?>{
  'ok': true,
  'provider': 'openrouter',
  'count': 2,
};

/// `GET /api/model/recommended-default?provider=openrouter`.
const recordedRecommendedDefault = <String, Object?>{
  'provider': 'openrouter',
  'model': 'example-model-a',
  'free_tier': null,
};
