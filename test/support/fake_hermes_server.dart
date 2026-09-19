import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:hermes_app/src/api/hermes_api_client.dart';

/// Stands in for the Hermes dashboard at the HTTP layer, so tests drive the
/// real generated client and the real Dio pipeline rather than a mock of it.
class FakeHermesServer implements HttpClientAdapter {
  final _routes = <String, ({int status, Object? body})>{};

  /// Every request the client sent, in order.
  final List<RequestOptions> requests = [];

  void on(String method, String path, Object? body, {int status = 200}) {
    _routes['$method $path'] = (status: status, body: body);
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
    final route = _routes['${options.method} ${options.path}'];
    final status = route?.status ?? 404;
    final body = route == null ? {'detail': 'Not Found'} : route.body;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
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

/// A `GET /api/messaging/platforms` entry as the dashboard serialises it.
Map<String, Object?> platformRow({
  required String id,
  required String name,
  String description = '',
  bool enabled = false,
  bool configured = false,
  String state = 'disabled',
  String? errorMessage,
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
  'env_vars': <Object?>[],
};

Map<String, Object?> platformListBody(List<Map<String, Object?>> rows) => {
  'env_path': '/home/hermes/.env',
  'gateway_start_command': 'hermes gateway start',
  'platforms': rows,
};

Map<String, Object?> activeProfileBody({
  required String active,
  String? current,
}) => {'active': active, 'current': current ?? active};
