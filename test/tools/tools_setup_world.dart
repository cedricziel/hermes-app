import 'dart:convert';

import 'package:dio/dio.dart';

import '../support/fake_hermes_server.dart';
import 'tools_screen_fixtures.dart' show toolsetRow, writeBody;

/// A key typed in the tests. Invented, and never a real key.
const typedKey = 'sk-test-0123456789';

/// The Hermes a setup test talks to: a catalog with Web (needs a key), Image
/// generation, Terminal and Computer use, their setup, and the routes that
/// change them. Every name is invented. Tests read what was sent from
/// [server] and change the world through the fields.
class SetupWorld {
  SetupWorld() {
    _route();
  }

  final server = FakeHermesServer();

  // Web.
  var webActive = 'Search Co';
  var webKeySet = false;
  var webSearch = 'searchco';
  var webExtract = 'searchco';
  var webNeedsNous = false;
  var webInstalled = false;

  // Image generation.
  var imageModel = 'fast-1';

  // Terminal.
  var backend = 'local';

  // Computer use.
  var driverInstalled = false;
  var screenRecording = false;
  String platform = 'darwin';
  var computerUseEnabled = false;

  /// What the install log answers; [installRunning] false with an exit code is
  /// a finished run.
  var installRunning = true;
  int? installExit;
  List<String> installLines = ['Downloading the driver', 'Unpacking'];
  var grantRunning = true;
  int? grantExit;

  final enabled = <String>{'web'};

  bool get webConfigured => webKeySet || webInstalled;

  Map<String, Object?> webConfig() => {
    'name': 'web',
    'has_category': true,
    'active_provider': webActive,
    'active_search_backend': webSearch,
    'active_extract_backend': webExtract,
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
            'is_set': webKeySet,
          },
        ],
        'post_setup': null,
        'requires_nous_auth': false,
        'is_active': webActive == 'Search Co',
        'status': webKeySet ? 'ready' : 'needs_keys',
      },
      {
        'name': 'Local Driver',
        'badge': 'free',
        'tag': 'Runs on the server',
        'web_backend': 'localdriver',
        'capabilities': ['extract'],
        'env_vars': <Object?>[],
        'post_setup': 'local_driver',
        'requires_nous_auth': false,
        'is_active': webActive == 'Local Driver',
        'status': webInstalled ? 'ready' : 'needs_setup',
      },
      {
        'name': 'Nous Web',
        'badge': 'subscription',
        'tag': 'Search and extract',
        'web_backend': 'nousweb',
        'capabilities': ['search', 'extract'],
        'env_vars': <Object?>[],
        'post_setup': null,
        'requires_nous_auth': true,
        'is_active': webActive == 'Nous Web',
        'status': 'needs_auth',
      },
    ],
  };

  Map<String, Object?> imageConfig() => {
    'name': 'image_gen',
    'has_category': true,
    'active_provider': 'Image Co',
    'providers': [
      {
        'name': 'Image Co',
        'badge': 'paid',
        'tag': 'Pictures from a description',
        'env_vars': [
          {
            'key': 'IMAGECO_API_KEY',
            'prompt': 'Image Co API key',
            'url': 'https://imageco.example/keys',
            'is_set': true,
          },
        ],
        'post_setup': null,
        'requires_nous_auth': false,
        'is_active': true,
        'status': 'ready',
      },
    ],
  };

  Map<String, Object?> images() => {
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
      {
        'id': 'fine-2',
        'display': 'Fine Two',
        'speed': '~20s',
        'strengths': 'Detail',
        'price': r'$0.05/image',
      },
    ],
    'current': imageModel,
    'default': 'fast-1',
  };

  Map<String, Object?> computerConfig() => {
    'name': 'computer_use',
    'has_category': true,
    'active_provider': 'Cua driver',
    'providers': [
      {
        'name': 'Cua driver',
        'badge': 'free',
        'tag': 'Runs on the server',
        'env_vars': <Object?>[],
        'post_setup': 'cua_driver',
        'requires_nous_auth': false,
        'is_active': true,
        'status': driverInstalled ? 'ready' : 'needs_setup',
      },
    ],
  };

  Map<String, Object?> backends() => {
    'active': backend,
    'backends': [
      {
        'name': 'local',
        'label': 'Local',
        'description': 'Run on the same machine as Hermes',
        'active': backend == 'local',
        'status': 'ready',
      },
      {
        'name': 'docker',
        'label': 'Docker',
        'description': 'Run in a container',
        'active': backend == 'docker',
        'status': 'needs_setup',
        'detail': 'Docker CLI not found.',
      },
    ],
  };

  Map<String, Object?> computerStatus() => {
    'platform': platform,
    'platform_supported': true,
    'installed': driverInstalled,
    'version': '1.2.3',
    'ready': driverInstalled && screenRecording,
    'can_grant': platform == 'darwin',
    'checks': [
      {'label': 'Driver', 'status': 'ok', 'message': 'Found'},
    ],
    'error': null,
    'accessibility': driverInstalled ? true : null,
    'screen_recording': driverInstalled ? screenRecording : null,
  };

  List<Map<String, Object?>> catalog() => [
    toolsetRow(
      'web',
      label: 'Web Search & Scraping',
      enabled: enabled.contains('web'),
      configured: webConfigured,
      tools: ['web_extract', 'web_search'],
    ),
    toolsetRow(
      'image_gen',
      label: 'Image Generation',
      enabled: enabled.contains('image_gen'),
      tools: ['image_generate'],
    ),
    toolsetRow(
      'terminal',
      label: 'Terminal & Processes',
      enabled: enabled.contains('terminal'),
      tools: ['process', 'terminal'],
    ),
    toolsetRow(
      'computer_use',
      label: 'Computer Use',
      enabled: enabled.contains('computer_use'),
      configured: driverInstalled,
      tools: ['computer_use'],
    ),
    toolsetRow('todo', label: 'Task Planning', tools: ['todo']),
  ];

  /// The server's answer to a lost reply: the request is recorded and the
  /// answer never comes.
  void loseAnswer(String method, String path) =>
      server.onRequest(method, path, (request) {
        throw DioException.receiveTimeout(
          timeout: const Duration(seconds: 1),
          requestOptions: request,
        );
      });

  /// Every body sent to [path] with [method], decoded.
  List<Map<String, Object?>> bodies(String method, String path) => [
    for (final request in server.requestsTo(method, path)) writeBody(request),
  ];

  /// All the text of everything that was sent, for the secret trace test.
  String get sentText => [
    for (final r in server.requests)
      '${r.method} ${r.uri} ${jsonEncode(r.data)}',
  ].join('\n');

  void _route() {
    server
      ..onRequest(
        'GET',
        '/api/tools/toolsets',
        (_) => (status: 200, body: catalog()),
      )
      ..onRequest(
        'GET',
        '/api/tools/toolsets/web/config',
        (_) => (status: 200, body: webConfig()),
      )
      ..onRequest(
        'GET',
        '/api/tools/toolsets/image_gen/config',
        (_) => (status: 200, body: imageConfig()),
      )
      ..onRequest(
        'GET',
        '/api/tools/toolsets/image_gen/models',
        (_) => (status: 200, body: images()),
      )
      ..onRequest(
        'GET',
        '/api/tools/toolsets/computer_use/config',
        (_) => (status: 200, body: computerConfig()),
      )
      ..on('GET', '/api/tools/toolsets/terminal/config', _plain('terminal'))
      ..on('GET', '/api/tools/toolsets/todo/config', _plain('todo'))
      ..onRequest(
        'GET',
        '/api/tools/terminal/backends',
        (_) => (status: 200, body: backends()),
      )
      ..onRequest(
        'GET',
        '/api/tools/computer-use/status',
        (_) => (status: 200, body: computerStatus()),
      )
      ..onRequest('PUT', '/api/tools/terminal/backend', (request) {
        backend = writeBody(request)['backend']! as String;
        return (status: 200, body: {'ok': true, 'backend': backend});
      })
      ..onRequest('PUT', '/api/tools/toolsets/web/provider', (request) {
        final body = writeBody(request);
        final name = body['provider']! as String;
        final capability = body['capability'];
        String? backendOf(String n) => switch (n) {
          'Search Co' => 'searchco',
          'Local Driver' => 'localdriver',
          _ => 'nousweb',
        };
        if (capability == 'search') {
          webSearch = backendOf(name)!;
        } else if (capability == 'extract') {
          webExtract = backendOf(name)!;
        } else {
          webActive = name;
        }
        return (
          status: 200,
          body: {
            'ok': true,
            'name': 'web',
            'provider': name,
            if (name == 'Nous Web') 'needs_nous_auth': true,
          },
        );
      })
      ..onRequest('PUT', '/api/tools/toolsets/web/env', (request) {
        final env = writeBody(request)['env']! as Map<String, Object?>;
        webKeySet = env.containsKey('SEARCHCO_API_KEY');
        return (
          status: 200,
          body: {
            'ok': true,
            'name': 'web',
            'saved': env.keys.toList(),
            'skipped': <Object?>[],
            'is_set': {for (final k in env.keys) k: true},
          },
        );
      })
      ..onRequest('PUT', '/api/tools/toolsets/image_gen/model', (request) {
        imageModel = writeBody(request)['model']! as String;
        return (status: 200, body: {'ok': true, 'name': 'image_gen'});
      })
      ..onRequest('POST', '/api/tools/toolsets/web/post-setup', (request) {
        return (
          status: 200,
          body: {'ok': true, 'pid': 4242, 'name': 'tools-post-setup'},
        );
      })
      ..onRequest('POST', '/api/tools/toolsets/computer_use/post-setup', (_) {
        return (
          status: 200,
          body: {'ok': true, 'pid': 4242, 'name': 'tools-post-setup'},
        );
      })
      ..onRequest(
        'GET',
        '/api/actions/tools-post-setup/status',
        (_) => (
          status: 200,
          body: jobStatusBody(
            name: 'tools-post-setup',
            running: installRunning,
            exitCode: installRunning ? null : installExit,
            lines: installLines,
          ),
        ),
      )
      ..onRequest('POST', '/api/tools/computer-use/permissions/grant', (_) {
        return (
          status: 200,
          body: {'ok': true, 'pid': 5151, 'name': 'computer-use-grant'},
        );
      })
      ..onRequest(
        'GET',
        '/api/actions/computer-use-grant/status',
        (_) => (
          status: 200,
          body: jobStatusBody(
            name: 'computer-use-grant',
            running: grantRunning,
            exitCode: grantRunning ? null : grantExit,
            pid: 5151,
            lines: ['Waiting for the permission window'],
          ),
        ),
      );
    for (final name in [
      'web',
      'image_gen',
      'terminal',
      'computer_use',
      'todo',
    ]) {
      server.onRequest('PUT', '/api/tools/toolsets/$name', (request) {
        final on = writeBody(request)['enabled'] == true;
        if (on) {
          enabled.add(name);
        } else {
          enabled.remove(name);
        }
        return (status: 200, body: {'ok': true, 'name': name, 'enabled': on});
      });
    }
  }

  static Map<String, Object?> _plain(String name) => {
    'name': name,
    'has_category': false,
    'providers': <Object?>[],
  };
}
