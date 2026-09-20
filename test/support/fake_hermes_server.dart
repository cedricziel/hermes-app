import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show mapEquals;
import 'package:hermes_app/src/api/hermes_api_client.dart';

typedef FakeResponse = ({int status, Object? body});

/// Stands in for the Hermes dashboard at the HTTP layer, so tests drive the
/// real generated client and the real Dio pipeline rather than a mock of it.
class FakeHermesServer implements HttpClientAdapter {
  final _routes = <_Route>[];

  /// Every request the client sent, in order.
  final List<RequestOptions> requests = [];

  /// Answers [method] [path] with [body]: a [String] is served as is (an HTML
  /// page), a [Uint8List] as a binary file, anything else as JSON. With [query], only requests carrying those
  /// parameters match, and they win over a route without.
  void on(
    String method,
    String path,
    Object? body, {
    int status = 200,
    Map<String, String> query = const {},
  }) => onRequest(
    method,
    path,
    (_) => (status: status, body: body),
    query: query,
  );

  /// Answers by looking at the request, and may hold the answer back to let a
  /// test observe the app while a call is in flight.
  void onRequest(
    String method,
    String path,
    FutureOr<FakeResponse> Function(RequestOptions request) respond, {
    Map<String, String> query = const {},
  }) {
    _routes
      ..removeWhere(
        (r) =>
            r.method == method && r.path == path && mapEquals(r.query, query),
      )
      ..add(_Route(method, path, query, respond));
  }

  _Route? _match(RequestOptions options) {
    _Route? best;
    for (final route in _routes) {
      if (route.method != options.method || route.path != options.path) {
        continue;
      }
      final matches = route.query.entries.every(
        (e) => options.queryParameters[e.key]?.toString() == e.value,
      );
      if (matches && (best == null || route.query.length > best.query.length)) {
        best = route;
      }
    }
    return best;
  }

  Iterable<RequestOptions> requestsTo(String method, String path) =>
      requests.where((r) => r.method == method && r.path == path);

  Dio dio() =>
      Dio(BaseOptions(baseUrl: 'http://hermes.test'))..httpClientAdapter = this;

  HermesApiClient client() => HermesApiClient(dio());

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final route = _match(options);
    final (:status, :body) = route == null
        ? (status: 404, body: {'detail': 'Not Found'})
        : await route.respond(options);
    if (body is Uint8List) {
      return ResponseBody.fromBytes(
        body,
        status,
        headers: {
          Headers.contentTypeHeader: ['application/octet-stream'],
        },
      );
    }
    final page = body is String;
    return ResponseBody.fromString(
      page ? body : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [
          page ? Headers.textPlainContentType : Headers.jsonContentType,
        ],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Route {
  const _Route(this.method, this.path, this.query, this.respond);

  final String method;
  final String path;
  final Map<String, String> query;
  final FutureOr<FakeResponse> Function(RequestOptions) respond;
}

/// The JSON body a request carried (the generated client sends it encoded).
Object? jsonBody(RequestOptions request) =>
    request.data is String ? jsonDecode(request.data as String) : request.data;

/// A `GET /api/sessions` row as the dashboard serialises it.
Map<String, Object?> sessionRow({
  required String id,
  String? title,
  String? preview,
  double startedAt = 1780000000,
  double? lastActive,
  bool pinned = false,
  bool archived = false,
}) => {
  'id': id,
  'source': 'cli',
  'title': title,
  'model': 'hermes-4',
  'started_at': startedAt,
  'ended_at': null,
  'message_count': 2,
  'preview': preview,
  'archived': archived,
  'pinned': pinned,
  'last_active': lastActive ?? startedAt,
};

/// A `GET /api/sessions/{id}/messages` row.
Map<String, Object?> messageRow({
  required int id,
  required String role,
  Object? content,
  List<Object?>? toolCalls,
  String? toolName,
  Object? reasoning,
  double timestamp = 1780000000,
}) => {
  'id': id,
  'role': role,
  'content': content,
  'tool_calls': toolCalls,
  'tool_name': toolName,
  'reasoning': reasoning,
  'timestamp': timestamp,
};

Map<String, Object?> sessionListBody(
  List<Map<String, Object?>> rows, {
  int? total,
  int limit = 50,
  int offset = 0,
}) => {
  'sessions': rows,
  'total': total ?? rows.length,
  'limit': limit,
  'offset': offset,
};

/// What `PATCH /api/sessions/{id}` answers: `ok`, the stored title and an echo
/// of each flag that was set.
Map<String, Object?> sessionPatchBody({
  String title = '',
  Map<String, bool> flags = const {},
}) => {'ok': true, 'title': title, ...flags};

Map<String, Object?> messageListBody(
  String sessionId,
  List<Map<String, Object?>> rows,
) => {
  'session_id': sessionId,
  'messages': rows,
  'pagination': {'limit': 100, 'offset': 0, 'returned': rows.length},
};

Map<String, Object?> functionCall(String name, String arguments) => {
  'id': 'call_$name',
  'type': 'function',
  'function': {'name': name, 'arguments': arguments},
};

/// A `GET /api/profiles` row as the dashboard serialises it.
Map<String, Object?> profileRow({
  required String name,
  bool isDefault = false,
  String? model,
  String? provider,
  String description = '',
  String displayName = '',
  int skillCount = 58,
  bool gatewayRunning = false,
}) => {
  'name': name,
  'path': '/home/hermes/$name',
  'is_default': isDefault,
  'model': model,
  'provider': provider,
  'has_env': false,
  'skill_count': skillCount,
  'gateway_running': gatewayRunning,
  'description': description,
  'description_auto': false,
  'display_name': displayName,
};

Map<String, Object?> profileListBody(List<Map<String, Object?>> rows) => {
  'profiles': rows,
};

/// One of a platform's `env_vars`, as the dashboard serialises it.
Map<String, Object?> envVarRow({
  required String key,
  String? prompt,
  bool required = false,
  bool isSet = false,
  String? redactedValue,
  String description = '',
  String help = '',
  bool isPassword = false,
  bool advanced = false,
}) => {
  'key': key,
  'required': required,
  'is_set': isSet,
  'redacted_value': isSet ? redactedValue ?? '***' : null,
  'description': description,
  'prompt': prompt ?? key,
  'help': help,
  'url': null,
  'is_password': isPassword,
  'advanced': advanced,
};

/// A `GET /api/messaging/platforms` entry as the dashboard serialises it.
Map<String, Object?> platformRow({
  required String id,
  required String name,
  String description = '',
  bool enabled = false,
  bool configured = false,
  String state = 'disabled',
  String? errorMessage,
  List<Map<String, Object?>> envVars = const [],
}) => {
  'id': id,
  'name': name,
  'description': description,
  'docs_url': 'https://example.com/$id',
  'enabled': enabled,
  'configured': configured,
  'gateway_running': false,
  'state': state,
  'error_code': errorMessage == null ? null : 'error',
  'error_message': errorMessage,
  'updated_at': null,
  'home_channel': null,
  'env_vars': envVars,
};

Map<String, Object?> platformListBody(List<Map<String, Object?>> rows) => {
  'env_path': '/home/hermes/.env',
  'gateway_start_command': 'hermes gateway start',
  'platforms': rows,
};

/// The reply to `POST /api/messaging/telegram/onboarding/start`.
Map<String, Object?> telegramPairingStartBody({String id = 'p1'}) => {
  'pairing_id': id,
  'suggested_username': 'hermes_1_bot',
  'deep_link': 'https://t.me/HermesBot?start=pair_$id',
  'qr_payload': 'https://t.me/HermesBot?start=pair_$id',
  'expires_at': '2026-09-19T10:57:52.075Z',
};

Map<String, Object?> activeProfileBody({
  required String active,
  String? current,
}) => {'active': active, 'current': current ?? active};

/// A `GET /api/skills` row as the dashboard serialises it.
Map<String, Object?> skillRow({
  required String name,
  String description = '',
  String? category,
  bool enabled = true,
  int usage = 0,
  String provenance = 'bundled',
}) => {
  'name': name,
  'description': description,
  'category': category,
  'enabled': enabled,
  'usage': usage,
  'provenance': provenance,
};

/// A hub skill as `/api/skills/hub/*` serialises it.
Map<String, Object?> hubSkillRow({
  required String name,
  String? identifier,
  String description = '',
  String source = 'github',
  String trustLevel = 'community',
  List<String> tags = const [],
  String? category,
  bool? installed,
}) => {
  'name': name,
  'description': description,
  'source': source,
  'identifier': identifier ?? '$source/$name',
  'trust_level': trustLevel,
  'repo': null,
  'tags': tags,
  'category': ?category,
  'installed': ?installed,
};

/// What `GET /api/skills/hub/scan` answers.
Map<String, Object?> hubScanBody({
  String policy = 'allow',
  String verdict = 'safe',
  String summary = 'No findings',
  String reason = '',
  List<Map<String, Object?>> findings = const [],
  Map<String, int> counts = const {
    'critical': 0,
    'high': 0,
    'medium': 0,
    'low': 0,
  },
}) => {
  'name': 'web-scraper',
  'identifier': 'github/web-scraper',
  'source': 'github',
  'trust_level': 'community',
  'verdict': verdict,
  'summary': summary,
  'policy': policy,
  'policy_reason': reason,
  'findings': findings,
  'severity_counts': counts,
  'tier1': null,
};

Map<String, Object?> hubFindingRow({
  String severity = 'high',
  String description = 'Downloads and runs a remote script',
  String file = 'scripts/fetch.sh',
  int line = 12,
}) => {
  'severity': severity,
  'category': 'exfil',
  'file': file,
  'line': line,
  'description': description,
};

/// What `GET /api/actions/{name}/status` answers.
Map<String, Object?> jobStatusBody({
  String name = 'skills-install-web-scraper',
  bool running = false,
  int? exitCode = 0,
  int pid = 4242,
  List<String> lines = const [],
}) => {
  'name': name,
  'running': running,
  'exit_code': exitCode,
  'pid': pid,
  'lines': lines,
};

/// A `GET /api/mcp/servers` entry as the dashboard serialises it. Environment
/// values arrive redacted.
Map<String, Object?> mcpServerRow({
  required String name,
  String? url,
  String? command,
  List<String> args = const [],
  Map<String, String> env = const {},
  String? auth,
  bool? enabled = true,
}) => {
  'name': name,
  'transport': url != null ? 'http' : (command != null ? 'stdio' : 'unknown'),
  'url': url,
  'command': command,
  'args': args,
  'env': {for (final key in env.keys) key: '***'},
  'auth': auth,
  'enabled': ?enabled,
  'tools': null,
};

Map<String, Object?> mcpServerListBody(List<Map<String, Object?>> rows) => {
  'servers': rows,
};

/// A successful `POST /api/mcp/servers/{name}/test` answer.
Map<String, Object?> mcpTestBody({
  List<Map<String, Object?>> tools = const [],
  int prompts = 0,
  int resources = 0,
}) => {'ok': true, 'tools': tools, 'prompts': prompts, 'resources': resources};

Map<String, Object?> mcpToolRow({
  required String name,
  String description = '',
  int? schemaChars,
}) => {'name': name, 'description': description, 'schema_chars': ?schemaChars};

/// A failed `POST /api/mcp/servers/{name}/test` answer: HTTP 200, `ok: false`.
Map<String, Object?> mcpTestFailureBody(String error) => {
  'ok': false,
  'error': error,
  'tools': <Object?>[],
};
