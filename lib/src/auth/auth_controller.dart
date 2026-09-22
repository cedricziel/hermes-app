import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_otel/flutter_otel.dart'
    show AppEventLogger, noopAppEventLogger;
import 'package:shared_preferences/shared_preferences.dart';

import '../api/hermes_api_client.dart';
import '../models/auth_provider_info.dart';
import '../models/hermes_session.dart';
import '../models/hermes_status.dart';
import '../network/network_signals.dart';
import 'connect_failure.dart';
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

const _unexpectedResponseMessage = 'Unexpected response from the server';

const _sessionTokenHeader = 'X-Hermes-Session-Token';

/// Dev/test override: `flutter run --dart-define=HERMES_SERVER_URL=<url>`.
const _devServerUrlDefine = String.fromEnvironment('HERMES_SERVER_URL');

/// App-wide auth/connection state machine. Owns the authenticated [Dio]
/// client (token attach + transparent refresh via
/// `POST /auth/native/refresh`, mirroring the gate's own cookie-refresh
/// semantics on the server side) and the [TokenStore].
class AuthController extends ChangeNotifier {
  AuthController({
    TokenStore? tokenStore,
    SharedPreferencesAsync? prefs,
    String? devServerUrl,
    this._interceptors = const [],
    this._events = noopAppEventLogger,
    this._login = runNativeLogin,
    NetworkSignals networkSignals = const NoNetworkSignals(),
  }) : _tokenStore = tokenStore ?? TokenStore(),
       _prefs = prefs ?? SharedPreferencesAsync(),
       _devServerUrl = devServerUrl ?? _devServerUrlDefine,
       _network = networkSignals {
    _networkChanges = _network.changes.listen((_) => _retryUnreachable());
  }

  final TokenStore _tokenStore;
  final SharedPreferencesAsync _prefs;

  /// Set only in dev/test runs. Wins over the saved address and is never
  /// saved, so parallel runs on one machine can't overwrite each other's
  /// (or the developer's own) saved server.
  final String _devServerUrl;

  /// Added to every [Dio] client this controller builds.
  final List<Interceptor> _interceptors;

  final AppEventLogger _events;

  final NativeLogin _login;

  final NetworkSignals _network;
  StreamSubscription<void>? _networkChanges;

  HermesConnectionState _state = HermesConnectionState.initializing;
  String? _baseUrl;
  String? _savedServerUrl;
  int _connectGeneration = 0;
  Future<void>? _savedServerWrites;
  HermesStatus? _status;
  List<AuthProviderInfo> _providers = const [];
  HermesSession? _session;
  HermesIdentity? _identity;
  String? _errorMessage;
  ConnectFailure? _lastFailure;

  /// The address the last failed connect went to.
  String? _failedUrl;

  Dio? _dio;
  Dio? _tokenDio;
  HermesApiClient? _api;
  Future<HermesSession>? _refreshInFlight;
  Completer<void>? _signInCancel;
  final _signedOut = StreamController<void>.broadcast(sync: true);

  /// Fires when the stored session is dropped, whether the user signs out or
  /// removes the server, or the server rejects the refresh token. Things
  /// that hold data fetched with the session, such as downloaded files,
  /// delete it here. A request that races to refresh the token does not fire.
  Stream<void> get signedOut => _signedOut.stream;

  HermesConnectionState get state => _state;
  String? get baseUrl => _baseUrl;

  /// The remembered server address, known from launch on. Unlike [baseUrl] it
  /// does not mean the server was reached.
  String? get savedServerUrl => _savedServerUrl;
  HermesStatus? get status => _status;
  List<AuthProviderInfo> get providers => _providers;
  HermesIdentity? get identity => _identity;
  String? get errorMessage => _errorMessage;

  /// Why the last connect failed, when it failed reaching the server.
  ConnectFailure? get lastFailure => _lastFailure;

  /// Whether a VPN is active, or null where the platform cannot tell.
  bool? get vpnActive => _network.vpnActive;

  /// The authenticated API client. Only valid once [state] is
  /// [HermesConnectionState.ready].
  HermesApiClient? get api => _api;

  Future<void> bootstrap() async {
    if (_devServerUrl.isNotEmpty) {
      await connect(_devServerUrl, remember: false, restoring: true);
      return;
    }
    final savedUrl = await _prefs.getString(_prefsBaseUrlKey);
    if (savedUrl == null || savedUrl.isEmpty) {
      _setState(HermesConnectionState.needsServerUrl);
      return;
    }
    _savedServerUrl = savedUrl;
    await connect(savedUrl, restoring: true);
  }

  /// Normalizes and connects to a dashboard base URL, then figures out
  /// whether sign-in is needed. A [restoring] connect (app launch) stays in
  /// [HermesConnectionState.initializing] instead of flashing the setup form.
  Future<void> connect(
    String rawUrl, {
    bool remember = true,
    bool restoring = false,
    bool automatic = false,
  }) async {
    final generation = ++_connectGeneration;
    bool stale() => generation != _connectGeneration;
    final normalized = _normalizeUrl(rawUrl);
    if (normalized == null) {
      _errorMessage =
          'Enter a valid http(s) URL, e.g. http://192.168.1.20:9119';
      _setState(HermesConnectionState.connectionError);
      return;
    }

    _errorMessage = null;
    _lastFailure = null;
    _failedUrl = null;
    if (!restoring) _setState(HermesConnectionState.connecting);

    final probeDio = _plainDio(
      normalized,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    );

    final HermesStatus status;
    try {
      status = await HermesApiClient(probeDio).fetchStatus();
    } on DioException catch (e) {
      if (stale()) return;
      _failConnect(
        e,
        normalized,
        fallback: 'Could not reach $normalized',
        automatic: automatic,
      );
      return;
    } on FormatException {
      if (stale()) return;
      _errorMessage = _unexpectedResponseMessage;
      _setState(HermesConnectionState.connectionError);
      return;
    }
    if (stale()) return;

    _baseUrl = normalized;
    _status = status;
    if (remember) {
      await _writeSavedServer(() async {
        if (stale()) return;
        _savedServerUrl = normalized;
        await _prefs.setString(_prefsBaseUrlKey, normalized);
      });
      if (stale()) return;
    }

    _dio = _buildAuthenticatedDio(normalized, gated: status.authRequired);
    _tokenDio = _plainDio(normalized);
    _api = HermesApiClient(_dio!);

    if (!status.authRequired) {
      _session = null;
      _identity = null;
      _setState(HermesConnectionState.ready);
      return;
    }

    try {
      _providers = await _api!.fetchAuthProviders();
      if (stale()) return;
    } on DioException catch (e) {
      if (stale()) return;
      _failConnect(
        e,
        normalized,
        fallback: 'Could not load sign-in options',
        automatic: automatic,
      );
      return;
    } on FormatException {
      if (stale()) return;
      _errorMessage = 'Could not load sign-in options';
      _setState(HermesConnectionState.connectionError);
      return;
    }

    final storedSession = await _tokenStore.read();
    if (stale()) return;
    if (storedSession == null) {
      _setState(HermesConnectionState.needsLogin);
      return;
    }

    _session = storedSession;
    try {
      final identity = await _api!.fetchMe();
      if (stale()) return;
      _identity = identity;
      _setState(HermesConnectionState.ready);
    } on DioException catch (e) {
      // When the interceptor confirmed the credential is dead it has already
      // cleared the session and asked for a login. Anything else (network,
      // 5xx) leaves the tokens alone so the user can simply retry.
      if (stale() || _session == null) return;
      _failConnect(
        e,
        normalized,
        fallback: 'Could not verify your session',
        automatic: automatic,
      );
    } on FormatException {
      if (stale()) return;
      _errorMessage = _unexpectedResponseMessage;
      _setState(HermesConnectionState.connectionError);
    }
  }

  void _failConnect(
    DioException e,
    String url, {
    required String fallback,
    required bool automatic,
  }) {
    final failure = classifyConnectFailure(e, Uri.parse(url));
    _lastFailure = failure;
    _failedUrl = url;
    _errorMessage = _describeDioError(e, fallback: fallback);
    _events('auth.connect.failed', {
      'reason': failure.kind.name,
      'host_kind': failure.hostKind.name,
      'retry': automatic,
    });
    _setState(HermesConnectionState.connectionError);
  }

  /// Asks the saved server again after the network changed, when the last
  /// attempt at it failed for a reason the network can explain.
  void _retryUnreachable() {
    final saved = _savedServerUrl;
    if (_state != HermesConnectionState.connectionError ||
        saved == null ||
        _failedUrl != saved ||
        _lastFailure?.retryable != true) {
      return;
    }
    unawaited(connect(saved, automatic: true));
  }

  /// Runs the RFC 8252 native login flow for [provider] and, on success,
  /// loads the identity with the new token and only then stores the token set.
  Future<void> signInWithProvider(AuthProviderInfo provider) async {
    final url = _baseUrl;
    if (url == null) return;
    _errorMessage = null;
    _setState(HermesConnectionState.signingIn);
    final cancel = _signInCancel = Completer<void>();
    final elapsed = Stopwatch()..start();
    void report(String outcome, [Map<String, Object> extra = const {}]) =>
        _events('auth.sign_in.$outcome', {
          'auth.password': provider.supportsPassword,
          'duration_ms': elapsed.elapsedMilliseconds,
          ...extra,
        });
    _events('auth.sign_in.started', {
      'auth.password': provider.supportsPassword,
    });
    // Signing out or switching server while the browser flow or the identity
    // request was finishing must not bring the result back.
    bool abandoned() {
      if (!cancel.isCompleted && _state == HermesConnectionState.signingIn) {
        return false;
      }
      report('cancelled');
      if (_state == HermesConnectionState.signingIn) {
        _setState(HermesConnectionState.needsLogin);
      }
      return true;
    }

    try {
      final session = await _login(
        url,
        provider: provider.name,
        httpClient: _tokenDio,
        cancelled: cancel.future,
      );
      if (abandoned()) return;
      // The session is neither in use nor stored until the server has
      // accepted its token, so a failure leaves nothing behind.
      final identity = await _api!.fetchMe(accessToken: session.accessToken);
      if (abandoned()) return;
      await _tokenStore.write(session);
      _session = session;
      _identity = identity;
      report('succeeded');
      _setState(HermesConnectionState.ready);
    } on NativeLoginCancelled {
      report('cancelled');
      _setState(HermesConnectionState.needsLogin);
    } on NativeLoginException catch (e) {
      report('failed', {
        'reason': e.reason.name,
        'http.response.status_code': ?e.statusCode,
      });
      _errorMessage = e.message;
      _setState(HermesConnectionState.needsLogin);
    } on DioException catch (e) {
      report('failed', {
        'reason': 'profile_load',
        'http.response.status_code': ?e.response?.statusCode,
      });
      _errorMessage = _describeDioError(
        e,
        fallback: 'Sign-in succeeded but loading your profile failed',
      );
      _setState(HermesConnectionState.needsLogin);
    } on FormatException {
      report('failed', {'reason': 'profile_load'});
      _errorMessage = _unexpectedResponseMessage;
      _setState(HermesConnectionState.needsLogin);
    } on Object catch (e) {
      report('failed', {
        'reason': 'unexpected',
        'exception.type': e.runtimeType.toString(),
      });
      _errorMessage = 'Sign-in failed. Please try again.';
      _setState(HermesConnectionState.needsLogin);
    } finally {
      _signInCancel = null;
    }
  }

  /// Abandons a sign-in that is waiting on the browser.
  void cancelSignIn() {
    final cancel = _signInCancel;
    if (cancel != null && !cancel.isCompleted) cancel.complete();
  }

  Future<void> signOut() async {
    await _tokenStore.clear();
    _session = null;
    _identity = null;
    _announceSignedOut();
    _setState(
      (_status?.authRequired ?? true)
          ? HermesConnectionState.needsLogin
          : HermesConnectionState.ready,
    );
  }

  /// Forgets the configured server entirely and returns to setup.
  /// Runs writes of the saved server one at a time, so a slow write from a
  /// superseded connect can't land after a newer one.
  Future<void> _writeSavedServer(Future<void> Function() write) {
    final previous = _savedServerWrites;
    final done = previous == null ? write() : previous.then((_) => write());
    _savedServerWrites = done.catchError((Object _) {});
    return done;
  }

  Future<void> changeServer() async {
    ++_connectGeneration;
    _savedServerUrl = null;
    await _tokenStore.clear();
    await _writeSavedServer(() => _prefs.remove(_prefsBaseUrlKey));
    _baseUrl = null;
    _status = null;
    _providers = const [];
    _session = null;
    _identity = null;
    _dio = null;
    _tokenDio = null;
    _api = null;
    _announceSignedOut();
    _setState(HermesConnectionState.needsServerUrl);
  }

  /// A dashboard without the auth gate still guards every route but
  /// `/api/status` with the session token its page embeds. The token dies with
  /// the server process, so a 401 re-reads it once and retries.
  Interceptor _pageTokenInterceptor(Dio dio, String baseUrl) {
    final page = HermesApiClient(
      Dio(BaseOptions(baseUrl: baseUrl))..interceptors.addAll(_interceptors),
    );
    Future<String?>? cached;
    Future<String?> token() async {
      final pending = cached ??= page.fetchSessionToken();
      try {
        return await pending;
      } on Object {
        cached = null;
        return null;
      }
    }

    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        final value = await token();
        if (value != null) options.headers[_sessionTokenHeader] = value;
        handler.next(options);
      },
      onError: (error, handler) async {
        final options = error.requestOptions;
        if (error.response?.statusCode != 401 ||
            options.extra['hermes_token_retried'] == true) {
          return handler.next(error);
        }
        cached = null;
        options.extra['hermes_token_retried'] = true;
        try {
          handler.resolve(await dio.fetch<dynamic>(options));
        } on DioException catch (e) {
          handler.next(e);
        }
      },
    );
  }

  Dio _buildAuthenticatedDio(String baseUrl, {required bool gated}) {
    final dio = _plainDio(baseUrl);
    if (!gated) dio.interceptors.add(_pageTokenInterceptor(dio, baseUrl));
    dio.interceptors.add(
      InterceptorsWrapper(
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
          final options = error.requestOptions;
          final session = _session;
          if (error.response?.statusCode != 401 || session == null) {
            return handler.next(error);
          }
          if (options.extra['hermes_retried'] == true) {
            await _handleSessionExpired('unauthorized_after_retry');
            return handler.next(error);
          }
          if (session.refreshToken.isEmpty) {
            await _handleSessionExpired('no_refresh_token');
            return handler.next(error);
          }

          // A request that went out with a token another request has since
          // rotated away only needs the new token. Refreshing again would
          // spend an already-used refresh token and sign the user out.
          final sentStaleToken =
              options.headers['Authorization'] !=
              'Bearer ${session.accessToken}';
          final HermesSession current;
          if (sentStaleToken) {
            current = session;
          } else {
            try {
              current = await _refreshSession(session, trigger: 'after_401');
            } on NativeLoginException catch (e) {
              if (e.rejected) await _handleSessionExpired('refresh_rejected');
              return handler.next(error);
            } on Object {
              return handler.next(error);
            }
          }

          options
            ..headers['Authorization'] = 'Bearer ${current.accessToken}'
            ..extra['hermes_retried'] = true;
          try {
            handler.resolve(await dio.fetch<dynamic>(options));
          } on DioException catch (e) {
            handler.next(e);
          }
        },
      ),
    );
    return dio;
  }

  Future<String?> _ensureFreshAccessToken() async {
    final session = _session;
    if (session == null) return null;
    if (!session.needsRefresh()) return session.accessToken;
    if (session.refreshToken.isEmpty) return session.accessToken;
    try {
      final refreshed = await _refreshSession(session, trigger: 'proactive');
      return refreshed.accessToken;
    } on NativeLoginException {
      // Already reported as auth.session.refresh_failed. Fall through with the
      // (possibly stale) token; the server will 401 and the response
      // interceptor drives re-login.
      return session.accessToken;
    } on FormatException {
      // The server answered the refresh with a token set that does not parse.
      return session.accessToken;
    } on StateError {
      // The session or server changed while the refresh was in flight.
      return session.accessToken;
    }
  }

  /// Refreshes [current], de-duplicating concurrent callers onto a single
  /// in-flight request.
  Future<HermesSession> _refreshSession(
    HermesSession current, {
    required String trigger,
  }) {
    final inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight;

    final url = _baseUrl;
    if (url == null) {
      return Future.error(StateError('No server configured'));
    }

    final future = refreshNativeSession(url, current, httpClient: _tokenDio)
        .then((refreshed) async {
          // Signing out or switching server while this was in flight must
          // not bring the old session back.
          if (!identical(_session, current)) {
            throw StateError('The session changed during the refresh');
          }
          _session = refreshed;
          await _tokenStore.write(refreshed);
          _events('auth.session.refreshed', {'trigger': trigger});
          return refreshed;
        })
        .onError<NativeLoginException>((e, stack) {
          _events('auth.session.refresh_failed', {
            'trigger': trigger,
            'rejected': e.rejected,
            'http.response.status_code': ?e.statusCode,
          });
          Error.throwWithStackTrace(e, stack);
        })
        .whenComplete(() {
          _refreshInFlight = null;
        });
    _refreshInFlight = future;
    return future;
  }

  Future<void> _handleSessionExpired(String cause) async {
    if (_session == null) return;
    _events('auth.session.expired', {'cause': cause});
    await _tokenStore.clear();
    _session = null;
    _identity = null;
    _errorMessage = 'Your session expired. Please sign in again.';
    _announceSignedOut();
    _setState(HermesConnectionState.needsLogin);
  }

  /// A client for [baseUrl] with this controller's interceptors. Also serves
  /// the token endpoints, which the authenticated client must not use (it
  /// would try to attach and refresh the very token being minted).
  Dio _plainDio(
    String baseUrl, {
    Duration connectTimeout = const Duration(seconds: 15),
    Duration receiveTimeout = const Duration(seconds: 30),
  }) => Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
    ),
  )..interceptors.addAll(_interceptors);

  void _announceSignedOut() {
    if (!_signedOut.isClosed) _signedOut.add(null);
  }

  @override
  void dispose() {
    _networkChanges?.cancel();
    _signedOut.close();
    super.dispose();
  }

  void _setState(HermesConnectionState next) {
    _state = next;
    _events('auth.state', {'state': next.name});
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
