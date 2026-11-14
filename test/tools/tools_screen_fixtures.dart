import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:dio/dio.dart';

import '../support/fake_hermes_server.dart';

Map<String, Object?> toolsetRow(
  String name, {
  String? label,
  String description = '',
  bool enabled = false,
  bool configured = true,
  List<String> tools = const ['one', 'two'],
  String platform = 'cli',
  String platformLabel = 'CLI',
}) => {
  'name': name,
  'label': label ?? name,
  'description': description,
  'platform': platform,
  'platform_label': platformLabel,
  'enabled': enabled,
  'available': enabled,
  'configured': configured,
  'tools': tools,
};

/// The catalog the screen tests and the workflow run against: Web is on and
/// needs setup, File is on, Terminal, Task planning, Text to speech and a
/// plugin's toolset are off. Names invented; none is a real plugin.
List<Map<String, Object?>> toolsCatalog({
  Set<String> on = const {},
  bool withPlugin = true,
}) => [
  toolsetRow(
    'web',
    label: 'Web Search & Scraping',
    description: 'web_search, web_extract',
    enabled: true,
    configured: false,
    tools: ['web_extract', 'web_search'],
  ),
  toolsetRow(
    'file',
    label: 'File Operations',
    enabled: true,
    tools: ['patch', 'read_file', 'search_files', 'write_file'],
  ),
  toolsetRow(
    'terminal',
    label: 'Terminal & Processes',
    enabled: on.contains('terminal'),
    tools: ['process', 'terminal'],
  ),
  toolsetRow(
    'todo',
    label: 'Task Planning',
    enabled: on.contains('todo'),
    tools: ['todo'],
  ),
  toolsetRow('tts', label: 'Text-to-Speech', enabled: on.contains('tts')),
  if (withPlugin)
    toolsetRow(
      'acme_digest',
      label: 'Acme digest',
      description: 'Summarize the team channel every morning.',
      enabled: on.contains('acme_digest'),
      tools: ['digest_post'],
    ),
];

/// A config answer for a toolset with no providers.
Map<String, Object?> plainConfig(String name) => {
  'name': name,
  'has_category': false,
  'providers': <Object?>[],
};

/// A config answer whose one provider has an install step.
Map<String, Object?> installingConfig(String name) => {
  'name': name,
  'has_category': true,
  'providers': [
    {
      'name': 'Local Voice',
      'badge': 'free',
      'tag': 'Runs on the server',
      'env_vars': <Object?>[],
      'post_setup': 'local_voice',
      'requires_nous_auth': false,
      'is_active': false,
      'status': 'needs_setup',
    },
  ],
};

/// Routes for the list, the config reads a switch makes and the writes.
/// [on] is the set of toolsets the next list read says are on; a successful
/// switch changes it.
void routeTools(FakeHermesServer server, {Set<String>? on}) {
  final state = <String>{...?on};
  server
    ..onRequest('GET', '/api/tools/toolsets', (_) {
      return (status: 200, body: toolsCatalog(on: state));
    })
    ..on('GET', '/api/tools/toolsets/terminal/config', plainConfig('terminal'))
    ..on('GET', '/api/tools/toolsets/todo/config', plainConfig('todo'))
    ..on('GET', '/api/tools/toolsets/tts/config', installingConfig('tts'))
    ..on(
      'GET',
      '/api/tools/toolsets/acme_digest/config',
      plainConfig('acme_digest'),
    )
    ..on('GET', '/api/tools/toolsets/web/config', plainConfig('web'))
    ..on('GET', '/api/tools/toolsets/file/config', plainConfig('file'));
  for (final name in [
    'terminal',
    'todo',
    'tts',
    'acme_digest',
    'web',
    'file',
  ]) {
    server.onRequest('PUT', '/api/tools/toolsets/$name', (request) {
      final enabled = writeBody(request)['enabled'] == true;
      if (enabled) {
        state.add(name);
      } else {
        state.remove(name);
      }
      return (
        status: 200,
        body: {'ok': true, 'name': name, 'enabled': enabled},
      );
    });
  }
}

/// Makes a route's answer never come, as a dropped connection does after the
/// request left.
void loseAnswer(FakeHermesServer server, String method, String path) =>
    server.onRequest(method, path, (request) {
      throw DioException.receiveTimeout(
        timeout: const Duration(seconds: 1),
        requestOptions: request,
      );
    });

/// Makes a route hang until the returned completer finishes.
Completer<void> holdAnswer(
  FakeHermesServer server,
  String method,
  String path,
) {
  final gate = Completer<void>();
  server.onRequest(method, path, (_) async {
    await gate.future;
    return (status: 200, body: toolsCatalog());
  });
  return gate;
}

/// Makes a route fail as a device with no network does.
void goOffline(FakeHermesServer server, String method, String path) =>
    server.onRequest(method, path, (request) {
      throw DioException.connectionError(
        requestOptions: request,
        reason: 'offline',
        error: const SocketException('offline'),
      );
    });

/// The JSON body of a write.
Map<String, Object?> writeBody(RequestOptions request) {
  final data = request.data;
  return (data is String ? jsonDecode(data) : data) as Map<String, Object?>;
}
