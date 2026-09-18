import 'package:dio/dio.dart';

import '../models/auth_provider_info.dart';
import '../models/hermes_session.dart';
import '../models/hermes_status.dart';

/// Thin typed wrapper around the Hermes dashboard REST API
/// (`hermes_cli/web_server.py` + `hermes_cli/dashboard_auth/routes.py`).
///
/// This client only issues requests; it does not attach auth headers or
/// handle 401/refresh itself — [AuthController] owns the [Dio] instance and
/// its interceptors so token refresh and sign-out can update app state.
class HermesApiClient {
  HermesApiClient(this._dio);

  final Dio _dio;

  /// `GET /api/status` — public, unauthenticated. Used to discover whether
  /// the auth gate is engaged and which flows are supported before any
  /// sign-in attempt.
  Future<HermesStatus> fetchStatus() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/status');
    return HermesStatus.fromJson(response.data ?? const {});
  }

  /// `GET /api/auth/providers` — public. Lists the registered sign-in
  /// options for the login screen.
  Future<List<AuthProviderInfo>> fetchAuthProviders() async {
    final response =
        await _dio.get<Map<String, dynamic>>('/api/auth/providers');
    final raw = response.data?['providers'] as List<dynamic>? ?? const [];
    return raw
        .map((e) => AuthProviderInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `GET /api/auth/me` — auth-required. The verified session for the
  /// signed-in user.
  Future<HermesIdentity> fetchMe() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/auth/me');
    return HermesIdentity.fromJson(response.data ?? const {});
  }
}
