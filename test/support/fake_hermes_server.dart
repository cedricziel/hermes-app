import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show mapEquals;
import 'package:hermes_app/src/api/hermes_api_client.dart';

/// Stands in for the Hermes dashboard at the HTTP layer, so tests drive the
/// real generated client and the real Dio pipeline rather than a mock of it.
class FakeHermesServer implements HttpClientAdapter {
  final _routes = <_Route>[];

  /// Every request the client sent, in order.
  final List<RequestOptions> requests = [];

  /// Answers [method] [path] with [body]: a [String] is served as is (an HTML
  /// page), anything else as JSON. With [query], only requests carrying those
  /// parameters match, and they win over a route without.
  void on(
    String method,
    String path,
    Object? body, {
    int status = 200,
    Map<String, String> query = const {},
  }) {
    _routes
      ..removeWhere(
        (r) =>
            r.method == method && r.path == path && mapEquals(r.query, query),
      )
      ..add(
        _Route(
          method: method,
          path: path,
          query: query,
          status: status,
          body: body,
        ),
      );
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
    final status = route?.status ?? 404;
    final body = route == null ? {'detail': 'Not Found'} : route.body;
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
  const _Route({
    required this.method,
    required this.path,
    required this.query,
    required this.status,
    required this.body,
  });

  final String method;
  final String path;
  final Map<String, String> query;
  final int status;
  final Object? body;
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
}) => {
  'id': id,
  'source': 'cli',
  'title': title,
  'model': 'hermes-4',
  'started_at': startedAt,
  'ended_at': null,
  'message_count': 2,
  'preview': preview,
  'archived': false,
  'pinned': false,
  'last_active': lastActive ?? startedAt,
};

/// A `GET /api/sessions/{id}/messages` row.
Map<String, Object?> messageRow({
  required int id,
  required String role,
  String? content,
  List<Object?>? toolCalls,
  String? toolName,
  double timestamp = 1780000000,
}) => {
  'id': id,
  'role': role,
  'content': content,
  'tool_calls': toolCalls,
  'tool_name': toolName,
  'timestamp': timestamp,
};

Map<String, Object?> sessionListBody(List<Map<String, Object?>> rows) => {
  'sessions': rows,
  'total': rows.length,
  'limit': 50,
  'offset': 0,
};

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
