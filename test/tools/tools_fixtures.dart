import 'package:hermes_app/src/tools/hermes_tools_repository.dart';

import '../support/fake_hermes_server.dart';

/// Answers shaped like the ones in `openspec/changes/toolsets/design.md`,
/// which were read from Hermes' route code. They are not recordings of a
/// running server; the contract tests check the shapes against one.
const toolsetsFixture = <Object?>[
  {
    'name': 'web',
    'label': 'Web Search & Scraping',
    'description': 'web_search, web_extract',
    'platform': 'cli',
    'platform_label': 'CLI',
    'enabled': true,
    'available': true,
    'configured': false,
    'tools': ['web_extract', 'web_search'],
  },
  {
    'name': 'terminal',
    'label': 'Terminal & Processes',
    'description': 'terminal, process',
    'platform': 'cli',
    'platform_label': 'CLI',
    'enabled': false,
    'available': false,
    'configured': true,
    'tools': ['process', 'terminal'],
  },
];

const webConfigFixture = <String, Object?>{
  'name': 'web',
  'has_category': true,
  'active_provider': 'Search Co',
  'active_search_backend': 'searchco',
  'active_extract_backend': 'searchco',
  'search_via_nous': false,
  'extract_via_nous': false,
  'providers': [
    {
      'name': 'Search Co',
      'badge': 'paid',
      'tag': 'Search and extract',
      'web_backend': 'searchco',
      'capabilities': ['search', 'extract'],
      'env_vars': [
        {
          'key': 'SEARCHCO_API_KEY',
          'prompt': 'Search Co API key',
          'url': 'https://searchco.example/keys',
          'default': null,
          'is_set': false,
        },
      ],
      'post_setup': null,
      'requires_nous_auth': false,
      'managed_nous_feature': null,
      'is_active': true,
      'status': 'needs_keys',
    },
    {
      'name': 'Local Driver',
      'badge': 'free',
      'tag': 'Runs on the server',
      'env_vars': [],
      'post_setup': 'local_driver',
      'requires_nous_auth': false,
      'is_active': false,
      'status': 'needs_setup',
    },
  ],
};

const imageModelsFixture = <String, Object?>{
  'name': 'image_gen',
  'has_models': true,
  'provider': 'Image Co',
  'plugin': 'imageco',
  'models': [
    {
      'id': 'fast-1',
      'display': 'Fast One',
      'speed': '~5s',
      'strengths': 'Quick drafts',
      'price': r'$0.01/image',
    },
  ],
  'current': 'fast-1',
  'default': 'fast-1',
};

const backendsFixture = <String, Object?>{
  'active': 'local',
  'backends': [
    {
      'name': 'local',
      'label': 'Local',
      'description': 'Run on the same machine as Hermes',
      'active': true,
      'status': 'ready',
    },
    {
      'name': 'docker',
      'label': 'Docker',
      'description': 'Run in a container',
      'active': false,
      'status': 'needs_setup',
      'detail': 'Docker CLI not found — install Docker Desktop.',
    },
  ],
};

const computerUseFixture = <String, Object?>{
  'platform': 'darwin',
  'platform_supported': true,
  'installed': true,
  'version': '1.2.3',
  'ready': false,
  'can_grant': true,
  'checks': [
    {'label': 'Driver', 'status': 'ok', 'message': 'Found'},
  ],
  'source': null,
  'error': null,
  'accessibility': true,
  'screen_recording': false,
  'screen_recording_capturable': null,
};

/// Serves the read routes of the tools feature with the fixtures above.
void serveToolsReads(FakeHermesServer server) {
  server
    ..on('GET', '/api/tools/toolsets', toolsetsFixture)
    ..on('GET', '/api/tools/toolsets/web/config', webConfigFixture)
    ..on('GET', '/api/tools/toolsets/image_gen/models', imageModelsFixture)
    ..on('GET', '/api/tools/terminal/backends', backendsFixture)
    ..on('GET', '/api/tools/computer-use/status', computerUseFixture);
}

HermesToolsRepository toolsRepository(
  FakeHermesServer server, {
  String profile = 'work',
}) => HermesToolsRepository(server.client().raw, profile: profile);
