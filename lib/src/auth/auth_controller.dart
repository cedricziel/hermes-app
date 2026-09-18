import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/hermes_api_client.dart';
import '../models/auth_provider_info.dart';
import '../models/hermes_session.dart';
import '../models/hermes_status.dart';
import 'native_login_flow.dart';
import 'token_store.dart';

enum HermesConnectionState {
  /// Restoring a previously-saved server URL / session.
  initializing,

  /// No dashboard URL has been configured yet.
  needsServerUrl,

  /// `GET /api/status` in flight against a candidate URL.
  connecting,

  /// The dashboard's auth gate is engaged and no valid session was found.
  needsLogin,

  /// The RFC 8252 native login flow (system browser) is in progress.
  signingIn,

  /// Either the gate isn't engaged (loopback dev mode) or a valid session
  /// is loaded — the app can call the API.
  ready,

  /// Couldn't reach the dashboard at the configured URL.
  connectionError,
}

const _prefsBaseUrlKey = 'hermes.server_base_url';

/// App-wide auth/connection state machine. Owns the authenticated [Dio]
/// client (token attach + transparent refresh via
/// `POST /auth/native/refresh`, mirroring the gate's own cookie-refresh
/// semantics on the server side) and the [TokenStore].
class AuthController extends ChangeNotifier {
  AuthController({TokenStore? tokenStore, SharedPreferencesAsync? prefs})
      : _tokenStore = tokenStore ?? TokenStore(),
        _prefs = prefs ?? SharedPreferencesAsync();

  final TokenStore _tokenStore;
  final SharedPreferencesAsync _prefs;

  HermesConnectionState _state = HermesConnectionState.initializing;
  String? _baseUrl;
  HermesStatus? _status;
  List<AuthProviderInfo> _providers = const [];
  HermesSession? _session;
  HermesIdentity? _identity;
  String? _errorMessage;

  Dio? _dio;
  HermesApiClient? _api;
  Future<HermesSession>? _refreshInFlight;

  HermesConnectionState get state => _state;
  String? get baseUrl => _baseUrl;
  HermesStatus? get status => _status;
  List<AuthProviderInfo> get providers => _providers;
  HermesIdentity? get identity => _identity;
  String? get errorMessage => _errorMessage;

  /// The authenticated API client. Only valid once [state] is
  /// [HermesConnectionState.ready].
  HermesApiClient? get api => _api;

  Future<void> bootstrap() async {
    final savedUrl = await _prefs.getString(_prefsBaseUrlKey);
    if (savedUrl == null || savedUrl.isEmpty) {
      _setState(HermesConnectionState.needsServerUrl);
      return;
    }
    await connect(savedUrl);
  }

  /// Normalizes and connects to a dashboard base URL, then figures out
  /// whether sign-in is needed.
  Future<void> connect(String rawUrl) async {
    final normalized = _normalizeUrl(rawUrl);
    if (normalized == null) {
      _errorMessage = 'Enter a valid http(s) URL, e.g. http://192.168.1.20:9119';
      _setState(HermesConnectionState.connectionError);
      return;
    }

    _errorMessage = null;
    _setState(HermesConnectionState.connecting);

    final probeDio = Dio(BaseOptions(
      baseUrl: normalized,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ));

    final HermesStatus status;
    try {
      final response =
          await probeDio.get<Map<String, dynamic>>('/api/status');
      status = HermesStatus.fromJson(response.data ?? const {});
    } on DioException catch (e) {
      _errorMessage = _describeDioError(e, fallback: 'Could not reach $normalized');
      _setState(HermesConnectionState.connectionError);
      return;
    }

    _baseUrl = normalized;
    _status = status;
    await _prefs.setString(_prefsBaseUrlKey, normalized);

    _dio = _buildAuthenticatedDio(normalized);
    _api = HermesApiClient(_dio!);

    if (!status.authRequired) {
      _session = null;
      _identity = null;
      _setState(HermesConnectionState.ready);
      return;
    }

    try {
      _providers = await _api!.fetchAuthProviders();
    } on DioException catch (e) {
      _errorMessage = _describeDioError(e, fallback: 'Could not load sign-in options');
      _setState(HermesConnectionState.connectionError);
      return;
    }

    final storedSession = await _tokenStore.read();
    if (storedSession == null) {
      _setState(HermesConnectionState.needsLogin);
      return;
    }

    _session = storedSession;
    try {
      _identity = await _api!.fetchMe();
      _setState(HermesConnectionState.ready);
    } on DioException catch (_) {
      // The request interceptor already tried a refresh; if we're still
      // here the session is unrecoverable.
      await _tokenStore.clear();
      _session = null;
      _setState(HermesConnectionState.needsLogin);
    }
  }

  /// Runs the RFC 8252 native login flow for [provider] and, on success,
  /// stores the resulting token set and loads the identity.
  Future<void> signInWithProvider(AuthProviderInfo provider) async {
    final url = _baseUrl;
    if (url == null) return;
    _errorMessage = null;
    _setState(HermesConnectionState.signingIn);
    try {
      final session = await runNativeLogin(url, provider: provider.name);
      await _tokenStore.write(session);
      _session = session;
      _identity = await _api!.fetchMe();
      _setState(HermesConnectionState.ready);
    } on NativeLoginException catch (e) {
      _errorMessage = e.message;
      _setState(HermesConnectionState.needsLogin);
    } on DioException catch (e) {
      _errorMessage = _describeDioError(e, fallback: 'Sign-in succeeded but loading your profile failed');
      _setState(HermesConnectionState.needsLogin);
    }
  }

  Future<void> signOut() async {
    await _tokenStore.clear();
    _session = null;
    _identity = null;
    _setState(
      (_status?.authRequired ?? true)
          ? HermesConnectionState.needsLogin
          : HermesConnectionState.ready,
    );
  }

  /// Forgets the configured server entirely and returns to setup.
  Future<void> changeServer() async {
    await _tokenStore.clear();
    await _prefs.remove(_prefsBaseUrlKey);
    _baseUrl = null;
    _status = null;
    _providers = const [];
    _session = null;
    _identity = null;
    _dio = null;
    _api = null;
    _setState(HermesConnectionState.needsServerUrl);
  }

  Dio _buildAuthenticatedDio(String baseUrl) {
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final session = _session;
        if (session != null) {
          final token = await _ensureFreshAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final session = _session;
        final alreadyRetried =
            error.requestOptions.extra['hermes_retried'] == true;
        if (error.response?.statusCode == 401 &&
            session != null &&
            session.refreshToken.isNotEmpty &&
            !alreadyRetried) {
          try {
            final refreshed = await _refreshSession(session);
            final retryOptions = error.requestOptions
              ..headers['Authorization'] = 'Bearer ${refreshed.accessToken}'
              ..extra['hermes_retried'] = true;
            final response = await dio.fetch(retryOptions);
            handler.resolve(response);
            return;
          } catch (_) {
            await _handleSessionExpired();
          }
        } else if (error.response?.statusCode == 401) {
          await _handleSessionExpired();
        }
        handler.next(error);
      },
    ));
    return dio;
  }

  Future<String?> _ensureFreshAccessToken() async {
    final session = _session;
    if (session == null) return null;
    if (!session.needsRefresh()) return session.accessToken;
    if (session.refreshToken.isEmpty) return session.accessToken;
    try {
      final refreshed = await _refreshSession(session);
      return refreshed.accessToken;
    } catch (_) {
      // Fall through with the (possibly stale) token; the server will 401
      // and the response interceptor drives re-login.
      return session.accessToken;
    }
  }

  /// Refreshes [current], de-duplicating concurrent callers onto a single
  /// in-flight request.
  Future<HermesSession> _refreshSession(HermesSession current) {
    final inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight;

    final url = _baseUrl;
    if (url == null) {
      return Future.error(StateError('No server configured'));
    }

    final future = refreshNativeSession(url, current).then((refreshed) async {
      _session = refreshed;
      await _tokenStore.write(refreshed);
      return refreshed;
    }).whenComplete(() {
      _refreshInFlight = null;
    });
    _refreshInFlight = future;
    return future;
  }

  Future<void> _handleSessionExpired() async {
    if (_session == null) return;
    await _tokenStore.clear();
    _session = null;
    _identity = null;
    _errorMessage = 'Your session expired. Please sign in again.';
    _setState(HermesConnectionState.needsLogin);
  }

  void _setState(HermesConnectionState next) {
    _state = next;
    notifyListeners();
  }

  String? _normalizeUrl(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return null;
    if (!value.contains('://')) {
      value = 'http://$value';
    }
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    final path = uri.path.replaceAll(RegExp(r'/+$'), '');
    return uri.replace(path: path).toString();
  }

  String _describeDioError(DioException e, {required String fallback}) {
    final data = e.response?.data;
    if (data is Map && data['detail'] is String) {
      return data['detail'] as String;
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return fallback;
    }
    return e.message ?? fallback;
  }
}
