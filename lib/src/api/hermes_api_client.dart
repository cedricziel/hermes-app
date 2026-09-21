import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:hermes_api/hermes_api.dart';

import '../models/auth_provider_info.dart';
import '../models/hermes_session.dart';
import '../models/hermes_status.dart';

/// Thin typed wrapper around the Hermes dashboard REST API
/// (`hermes_cli/web_server.py` + `hermes_cli/dashboard_auth/routes.py`).
///
/// This client only issues requests; it does not attach auth headers or
/// handle 401/refresh itself — [AuthController] owns the [Dio] instance and
/// its interceptors so token refresh and sign-out can update app state.
///
/// [fetchStatus], [fetchAuthProviders] and [fetchMe] are hand-parsed because
/// the backend's OpenAPI spec doesn't declare response schemas for those
/// three routes (see `openapi/hermes-agent.openapi.json`), so codegen has
/// nothing to build a typed model from. [fetchSessionToken] reads a page, not
/// an API route, and needs the same [Dio]. Every other endpoint has a
/// generated, typed method on [raw] — see
/// `scripts/generate_hermes_api_client.sh` to regenerate it from a newer
/// spec, and prefer adding to [raw]'s call sites over hand-rolling another
/// `_dio.get`/`.post` for new features.
class HermesApiClient {
  HermesApiClient(this._dio) : raw = DefaultApi(_dio);

  final Dio _dio;

  /// The generated client, covering every endpoint the spec declares a
  /// response or request schema for.
  final DefaultApi raw;

  /// `GET /api/status` — public, unauthenticated. Used to discover whether
  /// the auth gate is engaged and which flows are supported before any
  /// sign-in attempt.
  Future<HermesStatus> fetchStatus() async {
    final response = await _dio.get<dynamic>('/api/status');
    return _parseObject(response.data, HermesStatus.fromJson, 'status');
  }

  /// `GET /api/auth/providers` — public. Lists the registered sign-in
  /// options for the login screen.
  Future<List<AuthProviderInfo>> fetchAuthProviders() async {
    final response = await _dio.get<dynamic>('/api/auth/providers');
    final data = response.data;
    if (data == null) return const [];
    if (data is! Map) throw const FormatException('malformed providers body');
    final raw = data['providers'];
    if (raw == null) return const [];
    if (raw is! List || raw.any((e) => e is! Map<String, dynamic>)) {
      throw const FormatException('malformed providers list');
    }
    return raw
        .map((e) => AuthProviderInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `GET /` — the dashboard page embeds the session token that opens
  /// `/api/ws` on a server without the auth gate (there is no REST route
  /// for it). Null when the page carries none.
  Future<String?> fetchSessionToken() async {
    final response = await _dio.get<String>(
      '/',
      options: Options(responseType: ResponseType.plain),
    );
    return RegExp(r'__HERMES_SESSION_TOKEN__="([^"]+)"')
        .firstMatch(response.data ?? '')
        ?.group(1);
  }

  /// `GET /api/plugins/kanban/attachments/{id}` — a task attachment's bytes.
  /// The generated method cannot return them: it decodes the body as JSON, which
  /// would corrupt a binary file, and takes no way to ask for raw bytes.
  Future<Uint8List> fetchKanbanAttachment(int id, {String? board}) =>
      _getBytes('/api/plugins/kanban/attachments/$id', {'board': ?board});

  /// `GET /api/files/download?path=` — the bytes of a file on the server, by
  /// its absolute path. The generated method decodes the body as JSON, which
  /// would corrupt a binary file, so this asks for raw bytes like
  /// [fetchKanbanAttachment]. The session goes in the header, never in the URL.
  Future<Uint8List> fetchManagedFile(String path) =>
      _getBytes('/api/files/download', {'path': path});

  Future<Uint8List> _getBytes(String route, Map<String, dynamic> query) async {
    final response = await _dio.get<List<int>>(
      route,
      queryParameters: query,
      options: Options(responseType: ResponseType.bytes),
    );
    final data = response.data;
    return data is Uint8List ? data : Uint8List.fromList(data ?? const []);
  }

  /// `GET /api/auth/me` — auth-required. The verified session for the
  /// signed-in user. With [accessToken] the request carries that token
  /// explicitly, to check one that is not the stored session yet.
  Future<HermesIdentity> fetchMe({String? accessToken}) async {
    final response = await _dio.get<dynamic>(
      '/api/auth/me',
      options: accessToken == null
          ? null
          : Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    return _parseObject(response.data, HermesIdentity.fromJson, 'identity');
  }

  /// Throws [FormatException] for a body that is not an object; [parse]
  /// rejects wrongly typed fields the same way.
  static T _parseObject<T>(
    dynamic data,
    T Function(Map<String, dynamic>) parse,
    String what,
  ) {
    if (data == null) return parse(const {});
    if (data is! Map<String, dynamic>) {
      throw FormatException('malformed $what body');
    }
    return parse(data);
  }
}
