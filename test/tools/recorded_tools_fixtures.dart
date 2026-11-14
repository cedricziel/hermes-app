// Answers of the tools routes recorded from a throwaway Hermes d923a5eb on Linux
// (task 1.2): verbatim shapes, with invented model ids and prices and shorter
// provider lists, and fake keys. `tools_fixtures.dart` keeps the small
// hand-made ones the controller tests use. `serveRecordedTools` answers the
// read routes with these on a [FakeHermesServer].

import '../support/fake_hermes_server.dart';

/// `GET /api/tools/toolsets` of a fresh profile: all 27 rows, verbatim. `available`
/// copies `enabled`; `vision` is on; two rows are for the
/// `discord` platform; twelve names are not in the app's risk table.
const recordedToolsets = <Object?>[
  {
    'name': 'web',
    'label': 'Web Search & Scraping',
    'description': 'web_search, web_extract',
    'platform': 'cli',
    'platform_label': 'CLI',
    'enabled': true,
    'available': true,
    'configured': true,
    'tools': ['web_extract', 'web_search'],
  },
  {
    'name': 'browser',
    'label': 'Browser Automation',
    'description': 'navigate, click, type, scroll',
    'platform': 'cli',
    'platform_label': 'CLI',
    'enabled': true,
    'available': true,
    'configured': true,
    'tools': [
      'browser_back',
      'browser_cdp',
      'browser_click',
      'browser_console',
      'browser_dialog',
      'browser_exec',
      'browser_get_images',
      'browser_navigate',
      'browser_press',
      'browser_scroll',
      'browser_snapshot',
      'browser_type',
      'browser_vault',
      'browser_vision',
    ],
  },
  {
    'name': 'terminal',
    'label': 'Terminal & Processes',
    'description': 'terminal, process',
    'platform': 'cli',
    'platform_label': 'CLI',
    'enabled': true,
    'available': true,
    'configured': true,
    'tools': ['process_manage', 'terminal'],
  },
  {
    'name': 'file',
    'label': 'File Operations',
    'description': 'read, write, patch, search',
    'platform': 'cli',
    'platform_label': 'CLI',
    'enabled': true,
    'available': true,
    'configured': true,
    'tools': ['patch', 'read_file', 'search_files', 'write_file'],
  },
  {
    'name': 'code_execution',
    'label': 'Code Execution',
    'description': 'execute_code',
    'platform': 'cli',
    'platform_label': 'CLI',
    'enabled': true,
    'available': true,
    'configured': true,
    'tools': ['execute_code'],
  },
  {
    'name': 'vision',
    'label': 'Vision / Image Analysis',
    'description': 'vision_analyze',
    'platform': 'cli',
    'platform_label': 'CLI',
    'enabled': true,
    'available': true,
    'configured': true,
    'tools': ['vision_analyze'],
  },
  {
    'name': 'video',
    'label': 'Video Analysis',
    'description': 'video_analyze (requires video-capable model)',
    'platform': 'cli',
    'platform_label': 'CLI',
    'enabled': false,
    'available': false,
    'configured': true,
    'tools': ['video_analyze'],
  },
  {
    'name': 'image_gen',
    'label': 'Image Generation',
    'description': 'image_generate',
    'platform': 'cli',
    'platform_label': 'CLI',
    'enabled': true,
    'available': true,
    'configured': true,
    'tools': ['image_generate'],
  },
  {
    'name': 'video_gen',
    'label': 'Video Generation',
    'description': 'video_generate (text/image/reference)',
    'platform': 'cli',
    'platform_label': 'CLI',
    'enabled': false,
    'available': false,
    'configured': true,
    'tools': ['video_generate', 'xai_video_edit', 'xai_video_extend'],
  },
  {
    'name': 'x_search',
    'label': 'X (Twitter) Search',
    'description': 'x_search (requires xAI OAuth or XAI_API_KEY)',
    'platform': 'cli',
    'platform_label': 'CLI',
    'enabled': false,
    'available': false,
    'configured': true,
    'tools': ['x_search'],
  },
  {
    'name': 'tts',
    'label': 'Text-to-Speech',
    'description': 'text_to_speech',
    'platform': 'cli',
    'platform_label': 'CLI',
    'enabled': true,
    'available': true,
    'configured': true,
    'tools': ['text_to_speech'],
  },
  {
    'name': 'stt',
    'label': 'Speech-to-Text',
    'description': 'voice transcription (gateway voice messages + voice mode)',
    'platform': 'cli',
    'platform_label': 'CLI',
    'enabled': true,
    'available': true,
    'configured': true,
    'tools': <Object?>[],
  },
  {
    'name': 'skills',
    'label': 'Skills',
    'description': 'list, view, manage',
    'platform': 'cli',
    'platform_label': 'CLI',
    'enabled': true,
    'available': true,
    'configured': true,
    'tools': ['skill_manage', 'skill_view', 'skills_list'],
  },
  {
    'name': 'todo',
    'label': 'Task Planning',
    'description': 'todo_list',
    'platform': 'cli',
    'platform_label': 'CLI',
    'enabled': true,
    'available': true,
    'configured': true,
    'tools': ['todo_list'],
  },
  {
    'name': 'kanban',
    'label': 'Kanban',
    'description': 'opt-in task board tools for this platform',
    'platform': 'cli',
    'platform_label': 'CLI',
    'enabled': false,
    'available': false,
    'configured': true,
    'tools': [
      'kanban_attach',
      'kanban_attach_url',
      'kanban_attachments',
      'kanban_block',
      'kanban_comment',
      'kanban_complete',
      'kanban_create',
      'kanban_heartbeat',
      'kanban_link',
      'kanban_list',
      'kanban_request_changes',
      'kanban_request_review',
      'kanban_schedule',
      'kanban_show',
      'kanban_unblock',
    ],
  },
  {
    'name': 'memory',
    'label': 'Memory',
    'description': 'persistent memory across sessions',
    'platform': 'cli',
    'platform_label': 'CLI',
    'enabled': true,
    'available': true,
    'configured': true,
    'tools': ['memory'],
  },
  {
    'name': 'context_engine',
    'label': 'Context Engine',
    'description': 'runtime tools from the active context engine',
    'platform': 'cli',
    'platform_label': 'CLI',
    'enabled': false,
    'available': false,
    'configured': true,
    'tools': <Object?>[],
  },
  {
    'name': 'session_search',
    'label': 'Session Search',
    'description': 'search past conversations',
    'platform': 'cli',
    'platform_label': 'CLI',
    'enabled': true,
    'available': true,
    'configured': true,
    'tools': ['session_search'],
  },
  {
    'name': 'connections',
    'label': 'Connections',
    'description': 'remote connector tools and account authorization',
    'platform': 'cli',
    'platform_label': 'CLI',
    'enabled': true,
    'available': true,
    'configured': true,
    'tools': ['manage_connections'],
  },
  {
    'name': 'clarify',
    'label': 'Clarifying Questions',
    'description': 'clarify',
    'platform': 'cli',
    'platform_label': 'CLI',
    'enabled': true,
    'available': true,
    'configured': true,
    'tools': ['clarify'],
  },
  {
    'name': 'delegation',
    'label': 'Task Delegation',
    'description': 'delegate_task',
    'platform': 'cli',
    'platform_label': 'CLI',
    'enabled': true,
    'available': true,
    'configured': true,
    'tools': ['delegate_task'],
  },
  {
    'name': 'cronjob',
    'label': 'Cron Jobs',
    'description':
        'create/list/update/pause/resume/run, with optional attached skills',
    'platform': 'cli',
    'platform_label': 'CLI',
    'enabled': true,
    'available': true,
    'configured': true,
    'tools': ['cronjob_manage'],
  },
  {
    'name': 'discord',
    'label': 'Discord (read/participate)',
    'description': 'fetch messages, search members, create thread',
    'platform': 'discord',
    'platform_label': 'Discord',
    'enabled': false,
    'available': false,
    'configured': true,
    'tools': ['discord'],
  },
  {
    'name': 'discord_admin',
    'label': 'Discord Server Admin',
    'description': 'list channels/roles, pin, assign roles',
    'platform': 'discord',
    'platform_label': 'Discord',
    'enabled': false,
    'available': false,
    'configured': true,
    'tools': ['discord_admin'],
  },
  {
    'name': 'yuanbao',
    'label': 'Yuanbao',
    'description': 'group info, member queries, DM',
    'platform': 'cli',
    'platform_label': 'CLI',
    'enabled': false,
    'available': false,
    'configured': true,
    'tools': [
      'yb_query_group_info',
      'yb_query_group_members',
      'yb_search_sticker',
      'yb_send_dm',
      'yb_send_sticker',
    ],
  },
  {
    'name': 'computer_use',
    'label': 'Computer Use (macOS/Windows/Linux)',
    'description': 'background desktop control via cua-driver',
    'platform': 'cli',
    'platform_label': 'CLI',
    'enabled': true,
    'available': true,
    'configured': true,
    'tools': ['computer_use'],
  },
  {
    'name': 'a2a',
    'label': 'A2A',
    'description': 'A2A (Agent-to-Agent) protocol v1.0 support for Hermes Agent — both directions of the open Linux Foundation standard for inter-agent communication.\nOUTBOUND (client tools): a2a_discover, a2a_call, a2a_list, a2a_history, and a2a_orchestrate let the agent fetch another agent\'s Agent Card and send it tasks over JSON-RPC — works with any A2A-compliant peer (Hermes, LangChain, CrewAI, Google ADK, OpenClaw, ...).\nINBOUND (platform adapter): exposes Hermes as an A2A-discoverable agent. An Agent Card is served at /.well-known/agent-card.json (v1.0 canonical path; legacy agent.json also answers) and incoming tasks are routed into the agent\'s live gateway session like any other platform — so the agent that replies is the same one talking to its user, with full memory and context, not a throwaway clone.\nSecurity is on by default: no bearer token configured => localhost-only bind. Inbound task text passes through prompt-injection filters; outbound text is scrubbed of credential-shaped strings; every exchange is audit-logged and persisted to disk outside the context-compaction pipeline so conversations survive compaction and restarts.\nPure stdlib transport (http.server + urllib) — no a2a-sdk dependency required.\n',
    'platform': 'cli',
    'platform_label': 'CLI',
    'enabled': false,
    'available': false,
    'configured': true,
    'tools': [
      'a2a_call',
      'a2a_discover',
      'a2a_history',
      'a2a_list',
      'a2a_orchestrate',
    ],
  },
];

/// `…/web/config`, six of its seventeen providers: no row is active
/// (`active_provider: null`) while `active_search_backend` names one.
const recordedWebConfig = <String, Object?>{
  'name': 'web',
  'has_category': true,
  'providers': [
    {
      'name': 'Firecrawl Self-Hosted',
      'badge': 'free · self-hosted',
      'tag': 'Run your own Firecrawl instance (Docker)',
      'env_vars': [
        {
          'key': 'FIRECRAWL_API_URL',
          'prompt': 'Your Firecrawl instance URL (e.g., http://localhost:3002)',
          'url': null,
          'default': null,
          'is_set': false,
        },
      ],
      'post_setup': null,
      'requires_nous_auth': false,
      'managed_nous_feature': null,
      'is_active': false,
      'status': 'needs_keys',
      'web_backend': 'firecrawl',
      'capabilities': ['search', 'extract'],
    },
    {
      'name': 'DuckDuckGo (ddgs)',
      'badge': 'free · no key · search only',
      'tag': 'Search via the ddgs Python package — no API key (pair with any extract provider)',
      'env_vars': <Object?>[],
      'post_setup': 'ddgs',
      'requires_nous_auth': false,
      'managed_nous_feature': null,
      'is_active': false,
      'status': 'needs_setup',
      'web_backend': 'ddgs',
      'capabilities': ['search'],
    },
    {
      'name': 'Exa · Free (keyless)',
      'badge': 'free · no key',
      'tag': 'Semantic + neural web search with content extraction on Exa\'s anonymous free tier. Rate-limited under burst load.',
      'env_vars': <Object?>[],
      'post_setup': null,
      'requires_nous_auth': false,
      'managed_nous_feature': null,
      'is_active': false,
      'status': 'ready',
      'web_backend': 'exa',
      'capabilities': ['search', 'extract'],
    },
    {
      'name': 'Firecrawl',
      'badge': 'keyless/paid · optional gateway',
      'tag': 'Full search + extract; supports keyless cloud, direct API, and Nous tool-gateway routing.',
      'env_vars': [
        {
          'key': 'FIRECRAWL_API_KEY',
          'prompt': 'Firecrawl API key (optional; blank = keyless cloud or self-hosted)',
          'url': 'https://docs.firecrawl.dev/introduction',
          'default': null,
          'is_set': false,
        },
      ],
      'post_setup': null,
      'requires_nous_auth': false,
      'managed_nous_feature': null,
      'is_active': false,
      'status': 'needs_keys',
      'web_backend': 'firecrawl',
      'capabilities': ['search', 'extract'],
    },
    {
      'name': 'OpenAI Native Web Search (Codex Responses)',
      'badge': 'native',
      'tag': 'Search runs on the provider side (needs the Codex Responses transport + an openai-codex login); search only, extraction still uses another backend',
      'env_vars': <Object?>[],
      'post_setup': null,
      'requires_nous_auth': false,
      'managed_nous_feature': null,
      'is_active': false,
      'status': 'needs_auth',
      'web_backend': 'openai-native',
      'capabilities': ['search'],
    },
    {
      'name': 'xAI Web Search (Grok)',
      'badge': 'paid',
      'tag': 'Agentic web search via Grok\'s web_search tool — uses xAI Grok OAuth or XAI_API_KEY.',
      'env_vars': <Object?>[],
      'post_setup': 'xai_grok',
      'requires_nous_auth': false,
      'managed_nous_feature': null,
      'is_active': false,
      'status': 'needs_auth',
      'web_backend': 'xai',
      'capabilities': ['search'],
    },
  ],
  'active_provider': null,
  'active_search_backend': 'keenable',
  'active_extract_backend': 'keenable',
  'search_via_nous': false,
  'extract_via_nous': false,
};

/// `…/browser/config`, four of seven providers, read after `CAMOFOX_URL` was
/// saved (so Camofox is `ready`). Which provider is active depends on the
/// profile's config: a read of a fresh profile had `Browser Use` active and `ready`.
const recordedBrowserConfig = <String, Object?>{
  'name': 'browser',
  'has_category': true,
  'providers': [
    {
      'name': 'Local Browser',
      'badge': '★ recommended · free',
      'tag': 'Headless Chromium, no API key needed',
      'env_vars': <Object?>[],
      'post_setup': 'agent_browser',
      'requires_nous_auth': false,
      'managed_nous_feature': null,
      'is_active': false,
      'status': 'needs_setup',
    },
    {
      'name': 'Nous Subscription (Browser Use cloud)',
      'badge': 'subscription',
      'tag': 'Managed Browser Use billed to your subscription',
      'env_vars': <Object?>[],
      'post_setup': 'browserbase',
      'requires_nous_auth': true,
      'managed_nous_feature': 'browser',
      'is_active': false,
      'status': 'needs_auth',
    },
    {
      'name': 'Camofox',
      'badge': 'free · local',
      'tag': 'Anti-detection browser (Firefox/Camoufox)',
      'env_vars': [
        {
          'key': 'CAMOFOX_URL',
          'prompt': 'Camofox server URL',
          'url': 'https://github.com/jo-inc/camofox-browser',
          'default': 'http://localhost:9377',
          'is_set': true,
        },
      ],
      'post_setup': 'camofox',
      'requires_nous_auth': false,
      'managed_nous_feature': null,
      'is_active': false,
      'status': 'ready',
    },
    {
      'name': 'Browser Use',
      'badge': 'free · local · cloud',
      'tag': 'New SOTA web harness (CLI 3.0)',
      'env_vars': <Object?>[],
      'post_setup': 'browser_use_cli',
      'requires_nous_auth': false,
      'managed_nous_feature': null,
      'is_active': false,
      'status': 'needs_setup',
    },
  ],
  'active_provider': null,
};

/// `…/image_gen/config`, four of nine providers.
const recordedImageGenConfig = <String, Object?>{
  'name': 'image_gen',
  'has_category': true,
  'providers': [
    {
      'name': 'Nous Subscription',
      'badge': 'subscription',
      'tag': 'Managed image generation (FAL, Krea 2, Nous Portal models) billed to your subscription',
      'env_vars': <Object?>[],
      'post_setup': null,
      'requires_nous_auth': true,
      'managed_nous_feature': 'image_gen',
      'is_active': false,
      'status': 'needs_auth',
    },
    {
      'name': 'DeepInfra',
      'badge': 'paid',
      'tag': 'FLUX, Qwen-Image, … — live catalog from api.deepinfra.com',
      'env_vars': [
        {
          'key': 'DEEPINFRA_API_KEY',
          'prompt': 'DeepInfra API key',
          'url': 'https://deepinfra.com/dash/api_keys',
          'default': null,
          'is_set': false,
        },
      ],
      'post_setup': null,
      'requires_nous_auth': false,
      'managed_nous_feature': null,
      'is_active': false,
      'status': 'needs_keys',
    },
    {
      'name': 'FAL.ai',
      'badge': 'paid',
      'tag': 'Pick from several image models, text-to-image and image editing',
      'env_vars': [
        {
          'key': 'FAL_KEY',
          'prompt': 'FAL API key',
          'url': 'https://fal.ai/dashboard/keys',
          'default': null,
          'is_set': true,
        },
      ],
      'post_setup': null,
      'requires_nous_auth': false,
      'managed_nous_feature': null,
      'is_active': false,
      'status': 'ready',
    },
    {
      'name': 'OpenAI (Codex auth)',
      'badge': 'free',
      'tag': 'Image model via an account sign-in, no API key required',
      'env_vars': <Object?>[],
      'post_setup': 'openai_codex',
      'requires_nous_auth': false,
      'managed_nous_feature': null,
      'is_active': false,
      'status': 'needs_auth',
    },
  ],
  'active_provider': null,
};

/// `…/tts/config`, four of ten providers; each carries `tts_provider`.
const recordedTtsConfig = <String, Object?>{
  'name': 'tts',
  'has_category': true,
  'providers': [
    {
      'name': 'Microsoft Edge TTS',
      'badge': '★ recommended · free',
      'tag': 'Good quality, no API key needed',
      'env_vars': <Object?>[],
      'post_setup': null,
      'requires_nous_auth': false,
      'managed_nous_feature': null,
      'is_active': true,
      'status': 'ready',
      'tts_provider': 'edge',
    },
    {
      'name': 'OpenAI TTS',
      'badge': 'paid',
      'tag': 'High quality voices',
      'env_vars': [
        {
          'key': 'VOICE_TOOLS_OPENAI_KEY',
          'prompt': 'OpenAI API key',
          'url': 'https://platform.openai.com/api-keys',
          'default': null,
          'is_set': false,
        },
      ],
      'post_setup': null,
      'requires_nous_auth': false,
      'managed_nous_feature': null,
      'is_active': false,
      'status': 'needs_keys',
      'tts_provider': 'openai',
    },
    {
      'name': 'xAI TTS',
      'badge': '',
      'tag': 'Grok voices — uses xAI Grok OAuth or XAI_API_KEY',
      'env_vars': <Object?>[],
      'post_setup': 'xai_grok',
      'requires_nous_auth': false,
      'managed_nous_feature': null,
      'is_active': false,
      'status': 'needs_auth',
      'tts_provider': 'xai',
    },
    {
      'name': 'Piper',
      'badge': 'local · free',
      'tag': 'Local neural TTS, 44 languages (voices ~20-90MB)',
      'env_vars': <Object?>[],
      'post_setup': 'piper',
      'requires_nous_auth': false,
      'managed_nous_feature': null,
      'is_active': false,
      'status': 'needs_setup',
      'tts_provider': 'piper',
    },
  ],
  'active_provider': 'Microsoft Edge TTS',
};

/// `…/computer_use/config`.
const recordedComputerUseConfig = <String, Object?>{
  'name': 'computer_use',
  'has_category': true,
  'providers': [
    {
      'name': 'cua-driver (background)',
      'badge': '★ recommended · free · local',
      'tag': 'Background computer-use via cua-driver — does NOT steal your cursor or focus. Works with any model.',
      'env_vars': <Object?>[],
      'post_setup': 'cua_driver',
      'requires_nous_auth': false,
      'managed_nous_feature': null,
      'is_active': false,
      'status': 'needs_setup',
    },
  ],
  'active_provider': null,
};

/// `…/terminal/config`: no provider matrix.
const recordedTerminalConfig = <String, Object?>{
  'name': 'terminal',
  'has_category': false,
  'providers': <Object?>[],
  'active_provider': null,
};

/// `…/web/models`: a toolset without a catalog.
const recordedWebModels = <String, Object?>{
  'name': 'web',
  'has_models': false,
  'models': <Object?>[],
  'current': null,
  'default': null,
};

/// `…/image_gen/models` once a provider with a catalog is picked (three of 25
/// models, names and prices invented): `current` and `default` may differ.
const recordedImageGenModels = <String, Object?>{
  'name': 'image_gen',
  'has_models': true,
  'provider': 'Image Co',
  'plugin': 'imageco',
  'models': [
    {
      'id': 'image-model-a',
      'display': 'Image model A',
      'speed': '<1s',
      'strengths': 'Example',
      'price': '\$0.006/MP',
    },
    {
      'id': 'image-model-b',
      'display': 'Image model B',
      'speed': '~6s',
      'strengths': 'Example',
      'price': '\$0.03/MP',
    },
    {
      'id': 'image-model-c',
      'display': 'Image model C',
      'speed': '~2s',
      'strengths': 'Example',
      'price': '\$0.005/MP',
    },
  ],
  'current': 'image-model-b',
  'default': 'image-model-a',
};

/// `GET /api/tools/terminal/backends`: `local` is active and ready, the five
/// others `needs_setup` with a `detail`.
const recordedBackends = <String, Object?>{
  'active': 'local',
  'backends': [
    {
      'name': 'local',
      'label': 'Local',
      'description': 'Run commands directly on this machine. No isolation.',
      'active': true,
      'status': 'ready',
      'detail': '',
    },
    {
      'name': 'docker',
      'label': 'Docker / Podman',
      'description': 'Run commands in an isolated Docker or Podman container with a persistent workspace.',
      'active': false,
      'status': 'needs_setup',
      'detail': 'Docker not reachable — start Docker and retry.',
    },
    {
      'name': 'singularity',
      'label': 'Singularity / Apptainer',
      'description': 'Run commands in a Singularity/Apptainer container (HPC-friendly, rootless).',
      'active': false,
      'status': 'needs_setup',
      'detail': 'Neither singularity nor apptainer found on PATH.',
    },
    {
      'name': 'modal',
      'label': 'Modal',
      'description': 'Run commands in a Modal cloud sandbox.',
      'active': false,
      'status': 'needs_setup',
      'detail': 'Modal credentials not found — set MODAL_TOKEN_ID and MODAL_TOKEN_SECRET (or run `modal setup`).',
    },
    {
      'name': 'daytona',
      'label': 'Daytona',
      'description': 'Run commands in a Daytona cloud sandbox.',
      'active': false,
      'status': 'needs_setup',
      'detail': 'Set DAYTONA_API_KEY to use the Daytona backend.',
    },
    {
      'name': 'ssh',
      'label': 'SSH',
      'description': 'Run commands on a remote host over SSH.',
      'active': false,
      'status': 'needs_setup',
      'detail': 'Set terminal.ssh_host and terminal.ssh_user in config.yaml (or the matching TERMINAL_SSH_* env vars).',
    },
  ],
};

/// `GET /api/tools/computer-use/status` on a Linux server: nothing installed,
/// every permission `null`.
const recordedComputerUseStatus = <String, Object?>{
  'platform': 'linux',
  'platform_supported': true,
  'installed': false,
  'version': null,
  'ready': null,
  'can_grant': false,
  'checks': <Object?>[],
  'source': null,
  'error': null,
  'accessibility': null,
  'screen_recording': null,
  'screen_recording_capturable': null,
};

/// `PUT /api/tools/toolsets/web`.
const recordedSwitchAnswer = <String, Object?>{
  'ok': true,
  'name': 'web',
  'platform': 'cli',
  'enabled': false,
  'post_setup_started': null,
};

/// `PUT /api/tools/toolsets/computer_use` on: names the install step it started.
const recordedSwitchOnAnswer = <String, Object?>{
  'ok': true,
  'name': 'computer_use',
  'platform': 'cli',
  'enabled': true,
  'post_setup_started': 'cua_driver',
};

/// `PUT …/image_gen/provider`.
const recordedProviderAnswer = <String, Object?>{
  'ok': true,
  'name': 'image_gen',
  'provider': 'FAL.ai',
};

/// `PUT …/image_gen/env`: `is_set` covers every key of the toolset, not only the saved one.
const recordedEnvAnswer = <String, Object?>{
  'ok': true,
  'name': 'image_gen',
  'saved': ['FAL_KEY'],
  'skipped': <Object?>[],
  'is_set': {
    'OPENROUTER_API_KEY': false,
    'DEEPINFRA_API_KEY': false,
    'OPENAI_API_KEY': false,
    'KREA_API_KEY': false,
    'FAL_KEY': true,
    'META_MODEL_API_KEY': false,
  },
};

/// `PUT …/image_gen/model`.
const recordedModelAnswer = <String, Object?>{
  'ok': true,
  'name': 'image_gen',
  'model': 'image-model-b',
  'plugin': 'imageco',
};

/// `PUT /api/tools/terminal/backend`.
const recordedBackendAnswer = <String, Object?>{
  'ok': true,
  'backend': 'docker',
};

/// `POST …/post-setup`.
const recordedPostSetupAnswer = <String, Object?>{
  'ok': true,
  'pid': 21001,
  'name': 'tools-post-setup',
  'key': 'camofox',
};

/// `GET /api/actions/tools-post-setup/status` after a spawn that ended at once
/// (this install had no dependency environment): `running: false`, `exit_code: 1`,
/// and a log with a header per run, appended.
const recordedPostSetupFailed = <String, Object?>{
  'name': 'tools-post-setup',
  'running': false,
  'exit_code': 1,
  'pid': 21001,
  'lines': [
    '',
    '=== tools-post-setup started 2026-01-01 10:00:00 ===',
    'hermes: no dependency environment is committed for this install; run `hermes pm repair`',
  ],
};

/// Serves the read routes of the tools feature with the recorded answers; the
/// config is served for each toolset the recording holds.
void serveRecordedTools(FakeHermesServer server) {
  server
    ..on('GET', '/api/tools/toolsets', recordedToolsets)
    ..on('GET', '/api/tools/toolsets/web/config', recordedWebConfig)
    ..on('GET', '/api/tools/toolsets/browser/config', recordedBrowserConfig)
    ..on('GET', '/api/tools/toolsets/image_gen/config', recordedImageGenConfig)
    ..on('GET', '/api/tools/toolsets/tts/config', recordedTtsConfig)
    ..on(
      'GET',
      '/api/tools/toolsets/computer_use/config',
      recordedComputerUseConfig,
    )
    ..on('GET', '/api/tools/toolsets/terminal/config', recordedTerminalConfig)
    ..on('GET', '/api/tools/toolsets/web/models', recordedWebModels)
    ..on('GET', '/api/tools/toolsets/image_gen/models', recordedImageGenModels)
    ..on('GET', '/api/tools/terminal/backends', recordedBackends)
    ..on('GET', '/api/tools/computer-use/status', recordedComputerUseStatus);
}
