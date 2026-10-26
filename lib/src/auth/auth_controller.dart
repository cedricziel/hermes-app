import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_otel/flutter_otel.dart' show AppEventLogger;
import 'package:shared_preferences/shared_preferences.dart';

import '../api/hermes_api_client.dart';
import '../api/request_timeout.dart';
import '../models/auth_provider_info.dart';
import '../models/hermes_session.dart';
import '../models/hermes_status.dart';
import '../network/network_signals.dart';
import '../telemetry/telemetry.dart';
import 'account_key.dart';
import 'connect_failure.dart';
import 'native_login_flow.dart';
import 'page_token.dart';
import 'token_store.dart';
import 'verified_session_owner.dart';

enum HermesConnectionState {
  /// Restoring a previously-saved server URL / session.
  initializing,

  /// No dashboard URL has been configured yet.
  needsServerUrl,

  /// `GET /api/status` in flight against a candidate URL.
  connecting,

  /// The dashboard's auth gate is engaged and no valid session was found.
  needsLogin,

  /// The RFC 8252 native login flow (browser sign-in) is in progress.
  signingIn,

  /// Either the gate isn't engaged (loopback dev mode) or a valid session
  /// is loaded — the app can call the API.
  ready,

  /// Couldn't reach the dashboard at the configured URL.
  connectionError,
}

/// The shared-preferences key the connected server's address is saved under.
const kSavedServerUrlKey = 'hermes.server_base_url';

const _unexpectedResponseMessage = 'Unexpected response from the server';

/// Dev/test override: `flutter run --dart-define=HERMES_SERVER_URL=<url>`.
const kDevServerUrlDefine = String.fromEnvironment('HERMES_SERVER_URL');

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
    ConnectionTelemetryFactory telemetry = ConnectionTelemetry.off,
    this._login = runNativeLogin,
    NetworkSignals networkSignals = const NoNetworkSignals(),
    this._rejectionRecheck = const Duration(seconds: 1),
  }) : _telemetry = telemetry,
       _connection = telemetry(const {}),
       _tokenStore =
           tokenStore ?? TokenStore(events: telemetry(const {}).events),
       _prefs = prefs ?? SharedPreferencesAsync(),
       _devServerUrl = devServerUrl ?? kDevServerUrlDefine,
       _network = networkSignals {
    _networkChanges = _network.changes.listen((_) => _retryUnreachable());
  }

  final TokenStore _tokenStore;

  /// How long a rejected refresh waits for another isolate's write to land
  /// in the store before it gives up on the session.
  final Duration _rejectionRecheck;
  final SharedPreferencesAsync _prefs;

  /// Set only in dev/test runs. Wins over the saved address and is never
  /// saved, so parallel runs on one machine can't overwrite each other's
  /// (or the developer's own) saved server.
  final String _devServerUrl;

  /// Added to every [Dio] client this controller builds.
  final List<Interceptor> _interceptors;

  final ConnectionTelemetryFactory _telemetry;

  /// The telemetry of the current connection, from its status answer on.
  /// Before that, and after Change Server, it describes no server.
  ConnectionTelemetry _connection;

  AppEventLogger get _events => _connection.events;

  /// The telemetry of the current connection, for what is opened on it.
  ConnectionTelemetry get connectionTelemetry => _connection;

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

  /// The page's session token of a dashboard without the auth gate.
  PageToken? _pageToken;
  HermesApiClient? _api;
  Future<HermesSession>? _refreshInFlight;
  _PendingSessionWrite? _pendingSessionWrite;
  Timer? _sessionWriteRetry;

  Future<void> _persistPendingSession() => _mutateTokens(() async {
    final pending = _pendingSessionWrite;
    if (pending == null || _disposed) return;
    try {
      final written = await _tokenStore.replace(pending.expected, pending.next);
      if (!identical(_pendingSessionWrite, pending) || _disposed) return;
      _pendingSessionWrite = null;
      _sessionWriteRetry?.cancel();
      if (!written) await _adoptStored(pending.next);
    } on Object catch (error) {
      pending.errorType = error.runtimeType.toString();
      if (!identical(_pendingSessionWrite, pending) || _disposed) return;
      _sessionWriteRetry?.cancel();
      _sessionWriteRetry = Timer(const Duration(seconds: 1), () {
        unawaited(_persistPendingSession());
      });
    }
  });

  void _forgetPendingSession() {
    _pendingSessionWrite = null;
    _sessionWriteRetry?.cancel();
  }

  int _ownerEpoch = 0;
  int _requestEpoch = 0;
  int _apiOwnerEpoch = -1;
  bool _protectedRequestsAllowed = false;
  bool _identitySeen = false;
  bool _ignoreStoredSession = false;
  bool _disposed = false;
  VerifiedSessionOwner? _verifiedOwner;
  VerifiedSessionOwner? _expiredOwner;
  Dio? _bootstrapClient;
  Future<void> _tokenMutations = Future.value();
  Future<void>? _departureInFlight;
  Completer<void>? _signInCancel;
  final _signedOut = StreamController<void>.broadcast(sync: true);

  /// Fires when the stored session is dropped, whether the user signs out or
  /// removes the server, or the server rejects the refresh token. Things
  /// that hold data fetched with the session, such as downloaded files,
  /// delete it here. A request that races to refresh the token does not fire.
  Stream<void> get signedOut => _signedOut.stream;

  /// Whether current suspension or the last [signedOut] came from expiry.
  bool get sessionExpired => _sessionExpired;
  bool _sessionExpired = false;

  HermesConnectionState get state => _state;
  String? get baseUrl => _baseUrl;

  /// Tells this account on this server from any other (`accountKeyFor`); null
  /// before a server is connected.
  String? get accountKey {
    final url = _baseUrl;
    return url == null ? null : accountKeyFor(url, _session);
  }

  int _userGeneration = 0;
  int get userGeneration => _userGeneration;
  bool get hasDevServer => _devServerUrl.isNotEmpty;

  /// The remembered server address, known from launch on. Unlike [baseUrl] it
  /// does not mean the server was reached.
  String? get savedServerUrl => _savedServerUrl;
  HermesStatus? get status => _status;
  List<AuthProviderInfo> get providers => _providers;
  HermesIdentity? get identity => _identity;

  /// Protected access closes synchronously when cleanup starts.
  bool get protectedRequestsAllowed => _protectedRequestsAllowed;
  VerifiedSessionOwner? get verifiedOwner => _verifiedOwner;
  VerifiedSessionOwner? get expiredOwner => _expiredOwner;
  int get ownerGeneration => _ownerEpoch;
  int get sessionExpiryGeneration => _sessionExpiryGeneration;
  int _sessionExpiryGeneration = 0;
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
    final savedUrl = await _prefs.getString(kSavedServerUrlKey);
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
    final departure = _departureInFlight;
    if (departure != null) await departure;
    final generation = ++_connectGeneration;
    bool stale() => _disposed || generation != _connectGeneration;
    final typed = normalizeServerUrl(rawUrl);
    if (typed != _baseUrl) _protectedRequestsAllowed = false;
    if (typed == null) {
      _errorMessage =
          'Enter a valid http(s) URL, e.g. http://192.168.1.20:9119';
      _setState(HermesConnectionState.connectionError);
      return;
    }
    var normalized = typed;

    _errorMessage = null;
    _lastFailure = null;
    _failedUrl = null;
    _connection = _telemetry(const {});
    if (!restoring) _setState(HermesConnectionState.connecting);

    final probeDio = _plainDio(
      normalized,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    );

    final HermesStatus status;
    try {
      final probe = await HermesApiClient(probeDio).probeStatus();
      status = probe.status;
      normalized = probe.redirectedTo ?? normalized;
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

    if (_baseUrl != null && _baseUrl != normalized) {
      _retireClients('server_change');
    }
    if (_status != null && _status!.authRequired != status.authRequired) {
      _retireClients('auth_mode_changed');
      _identitySeen = false;
      _verifiedOwner = null;
    }
    _baseUrl = normalized;
    _status = status;
    _connection = _telemetry(status.serverAttributes);
    _events('server.connected', {
      'hermes.version': ?status.serverAttributes['hermes.version'],
    });
    if (remember) {
      await _writeSavedServer(() async {
        if (stale()) return;
        _savedServerUrl = normalized;
        await _prefs.setString(kSavedServerUrlKey, normalized);
      });
      if (stale()) return;
    }

    _replaceApiClient();
    _tokenDio = _plainDio(normalized);

    if (!status.authRequired) {
      _session = null;
      _identity = null;
      _verifiedOwner = null;
      _identitySeen = true;
      _protectedRequestsAllowed = true;
      _setState(HermesConnectionState.ready);
      return;
    }

    try {
      _providers = await HermesApiClient(_tokenDio!).fetchAuthProviders();
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

    final stored = _ignoreStoredSession
        ? const SessionEmpty()
        : await _tokenStore.readState();
    if (stale()) return;
    if (stored is SessionUnreadable) {
      _protectedRequestsAllowed = false;
      _errorMessage = 'Could not read your saved sign-in. Unlock your device and try again.';
      _events('auth.session.restore_failed', {
        'reason': 'keychain_unavailable',
        'locked': stored.locked,
      });
      _setState(HermesConnectionState.connectionError);
      return;
    }
    final storedSession = stored.session;
    // A session another dashboard minted is no use here. The address the
    // connect started from counts as well as the one it was redirected to:
    // a proxy that starts redirecting elsewhere is still the same dashboard.
    final minter = storedSession?.serverUrl;
    if (storedSession == null ||
        (minter != null && minter != normalized && minter != typed)) {
      _protectedRequestsAllowed = false;
      _setState(HermesConnectionState.needsLogin);
      return;
    }

    if (storedSession.accessToken != _session?.accessToken ||
        storedSession.refreshToken != _session?.refreshToken) {
      _protectedRequestsAllowed = false;
    }
    _session = storedSession.boundTo(normalized);
    final verifying = _bootstrapClient = _dio;
    try {
      final identity = await _api!.fetchMe();
      if (stale()) return;
      _acceptIdentity(identity);
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
    } finally {
      if (identical(_bootstrapClient, verifying)) _bootstrapClient = null;
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
    _errorMessage =
        connectFailureMessage(failure) ??
        _describeDioError(e, fallback: fallback);
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
    final ownerEpoch = _ownerEpoch;
    final departure = _departureInFlight;
    if (departure != null) await departure;
    if (url == null || url != _baseUrl || ownerEpoch != _ownerEpoch) return;
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
      if (!cancel.isCompleted &&
          identical(_signInCancel, cancel) &&
          ownerEpoch == _ownerEpoch &&
          url == _baseUrl &&
          _state == HermesConnectionState.signingIn) {
        return false;
      }
      report('cancelled');
      if (identical(_signInCancel, cancel) &&
          _state == HermesConnectionState.signingIn) {
        _setState(HermesConnectionState.needsLogin);
      }
      return true;
    }

    try {
      final session = (await _login(
        url,
        provider: provider.name,
        httpClient: _tokenDio,
        cancelled: cancel.future,
      )).mintedBy(url);
      if (abandoned()) return;
      // The session is neither in use nor stored until the server has
      // accepted its token, so a failure leaves nothing behind.
      final identity = await HermesApiClient(_tokenDio!)
          .fetchMe(accessToken: session.accessToken);
      if (abandoned()) return;
      try {
        await _writeTokens(
          session,
          () =>
              !cancel.isCompleted &&
              identical(_signInCancel, cancel) &&
              ownerEpoch == _ownerEpoch &&
              url == _baseUrl &&
              _state == HermesConnectionState.signingIn,
        );
      } on Object catch (e) {
        if (abandoned()) return;
        report('failed', {
          'reason': 'token_store',
          'exception.type': e.runtimeType.toString(),
        });
        _errorMessage =
            'Signed in, but this device could not save the sign-in.';
        _setState(HermesConnectionState.needsLogin);
        return;
      }
      if (abandoned()) return;
      _session = session;
      _acceptIdentity(identity);
      report('succeeded');
      _setState(HermesConnectionState.ready);
    } on NativeLoginCancelled {
      if (abandoned()) return;
      report('cancelled');
      _setState(HermesConnectionState.needsLogin);
    } on NativeLoginException catch (e) {
      if (abandoned()) return;
      report('failed', {
        'reason': e.reason.name,
        'http.response.status_code': ?e.statusCode,
      });
      _errorMessage = e.message;
      _setState(HermesConnectionState.needsLogin);
    } on DioException catch (e) {
      if (abandoned()) return;
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
      if (abandoned()) return;
      report('failed', {'reason': 'profile_load'});
      _errorMessage = _unexpectedResponseMessage;
      _setState(HermesConnectionState.needsLogin);
    } on Object catch (e) {
      if (abandoned()) return;
      report('failed', {
        'reason': 'unexpected',
        'exception.type': e.runtimeType.toString(),
      });
      _errorMessage = 'Sign-in failed. Please try again.';
      _setState(HermesConnectionState.needsLogin);
    } finally {
      if (identical(_signInCancel, cancel)) _signInCancel = null;
    }
  }

  /// Abandons a sign-in that is waiting on the browser.
  void cancelSignIn() {
    final cancel = _signInCancel;
    if (cancel != null && !cancel.isCompleted) cancel.complete();
  }

  Future<void> signOut() => _depart(removeServer: false);

  Future<void> _depart({required bool removeServer}) {
    final generation = ++_userGeneration;
    ++_connectGeneration;
    if (removeServer) _connection = _telemetry(const {});
    _retireClients(removeServer ? 'server_change' : 'sign_out');
    cancelSignIn();
    _session = null;
    _identity = null;
    _verifiedOwner = null;
    _expiredOwner = null;
    _identitySeen = false;
    _sessionExpired = false;
    _ignoreStoredSession = true;
    if (removeServer) {
      _savedServerUrl = null;
    }
    final departure = _finishDeparture(removeServer, generation);
    _departureInFlight = departure;
    notifyListeners();
    return departure.whenComplete(() {
      if (identical(_departureInFlight, departure)) _departureInFlight = null;
    });
  }

  Future<void> _finishDeparture(bool removeServer, int generation) async {
    final deletionFailed = !await _clearTokens();
    if (_disposed || generation != _userGeneration) return;
    _ignoreStoredSession = deletionFailed;
    var forgetFailed = false;
    if (removeServer) {
      try {
        await _writeSavedServer(() => _prefs.remove(kSavedServerUrlKey));
      } on Object {
        forgetFailed = true;
      }
      if (_disposed || generation != _userGeneration) return;
      _baseUrl = null;
      _status = null;
      _connection = _telemetry(const {});
      _providers = const [];
      _dio = null;
      _tokenDio = null;
      _pageToken = null;
      _api = null;
    } else if (!(_status?.authRequired ?? true)) {
      _replaceApiClient();
      _protectedRequestsAllowed = true;
    }
    _errorMessage = [
      if (deletionFailed) 'This device could not remove the saved sign-in.',
      if (forgetFailed) 'This device could not forget the saved server.',
    ].join(' ');
    if (_errorMessage!.isEmpty) _errorMessage = null;
    _announceSignedOut();
    _setState(
      removeServer
          ? HermesConnectionState.needsServerUrl
          : (_status?.authRequired ?? true)
          ? HermesConnectionState.needsLogin
          : HermesConnectionState.ready,
    );
  }

  /// Runs writes of the saved server one at a time, so a slow write from a
  /// superseded connect can't land after a newer one.
  Future<void> _writeSavedServer(Future<void> Function() write) {
    final previous = _savedServerWrites;
    final done = previous == null ? write() : previous.then((_) => write());
    _savedServerWrites = done.catchError((Object _) {});
    return done;
  }

  /// Forgets the configured server entirely and returns to setup.
  Future<void> changeServer() => _depart(removeServer: true);

  void _retireClients(String reason) {
    _forgetPendingSession();
    _protectedRequestsAllowed = false;
    _ownerEpoch++;
    _requestEpoch++;
    _refreshInFlight = null;
    _events('auth.client.retired', {'reason': reason});
  }

  void _replaceApiClient() {
    final url = _baseUrl!;
    _dio = _buildAuthenticatedDio(url, gated: _status?.authRequired ?? true);
    _apiOwnerEpoch = _ownerEpoch;
    _api = HermesApiClient(_dio!);
  }

  void _acceptIdentity(HermesIdentity identity) {
    final owner = VerifiedSessionOwner.fromIdentity(_baseUrl!, identity);
    if (_identitySeen && (owner == null || owner != _verifiedOwner)) {
      _retireClients('owner_changed');
    }
    _ignoreStoredSession = false;
    _identity = identity;
    _verifiedOwner = owner;
    _identitySeen = true;
    if (_apiOwnerEpoch != _ownerEpoch) _replaceApiClient();
    _protectedRequestsAllowed = true;
  }

  Future<T> _mutateTokens<T>(Future<T> Function() mutation) {
    final result = _tokenMutations.then((_) => mutation());
    _tokenMutations = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<void> _writeTokens(HermesSession session, bool Function() valid) =>
      _mutateTokens<void>(() async {
        if (!valid()) return;
        await _tokenStore.write(session);
        if (!valid()) await _tokenStore.replace(session, null);
      });

  Dio _buildAuthenticatedDio(String baseUrl, {required bool gated}) {
    _pageToken = null;
    final dio = _plainDio(baseUrl);
    final ownerEpoch = _ownerEpoch;
    bool allowed(RequestOptions options) =>
        !_disposed &&
        ownerEpoch == _ownerEpoch &&
        baseUrl == _baseUrl &&
        options.extra['hermes_request_epoch'] == _requestEpoch &&
        (options.path == '/api/auth/providers' ||
            ((!gated || _session != null) &&
                (_protectedRequestsAllowed ||
                    (identical(_bootstrapClient, dio) &&
                        options.path == '/api/auth/me'))));
    DioException cancelled(RequestOptions options) => DioException(
      requestOptions: options,
      type: DioExceptionType.cancel,
      message: 'Session access changed',
    );
    if (!gated) {
      final page = _pageToken = PageToken(HermesApiClient(_plainDio(baseUrl)));
      dio.interceptors.add(pageTokenInterceptor(dio, page));
    }
    dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          options.extra.putIfAbsent(
            'hermes_request_epoch',
            () => _requestEpoch,
          );
          if (!allowed(options)) return handler.reject(cancelled(options));
          final session = _session;
          if (gated &&
              session != null &&
              options.path != '/api/auth/providers') {
            final token = await _ensureFreshAccessToken();
            if (!allowed(options)) return handler.reject(cancelled(options));
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          if (!allowed(response.requestOptions)) {
            return handler.reject(cancelled(response.requestOptions));
          }
          handler.next(response);
        },
        onError: (error, handler) async {
          final options = error.requestOptions;
          if (!allowed(options)) return handler.next(cancelled(options));
          final session = _session;
          if (error.response?.statusCode != 401 || session == null) {
            return handler.next(error);
          }
          if (options.extra['hermes_retried'] == true) {
            if (options.headers['Authorization'] ==
                'Bearer ${session.accessToken}') {
              await _handleSessionExpired('unauthorized_after_retry');
            }
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
          HermesSession? current = session;
          if (!sentStaleToken) {
            try {
              current = await _refreshSession(session, trigger: 'after_401');
            } on NativeLoginException catch (e) {
              current = e.rejected
                  ? await _refreshRejected(
                      session,
                      ownerEpoch: ownerEpoch,
                      requestEpoch:
                          options.extra['hermes_request_epoch'] as int,
                    )
                  : null;
            } on Object {
              current = null;
            }
          }
          if (!allowed(options)) return handler.next(cancelled(options));
          if (current == null) return handler.next(error);

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
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (!allowed(options)) return handler.reject(cancelled(options));
          handler.next(options);
        },
      ),
    );
    return dio;
  }

  /// The headers for a request a conversation window sends. Those windows run
  /// in their own engines and never refresh the session: [rejected] are the
  /// headers of their request the server answered with 401, and only when
  /// they still hold the current token is the session refreshed, the same way
  /// this controller's own client does. Empty when signed out.
  Future<Map<String, String>> windowAuthHeaders({
    Map<String, String>? rejected,
  }) async {
    final ownerEpoch = _ownerEpoch;
    final requestEpoch = _requestEpoch;
    bool valid() =>
        !_disposed &&
        _protectedRequestsAllowed &&
        ownerEpoch == _ownerEpoch &&
        requestEpoch == _requestEpoch;
    if (!valid()) return const {};
    final page = _pageToken;
    if (page != null) {
      final current = await page.get();
      if (!valid()) return const {};
      if (current != null && rejected?[kSessionTokenHeader] == current) {
        page.forget();
      }
      final token = await page.get();
      return valid() ? {kSessionTokenHeader: ?token} : const {};
    }
    final session = _session;
    if (session == null) return const {};
    final sentCurrent =
        rejected?['Authorization'] == 'Bearer ${session.accessToken}';
    if (!sentCurrent) {
      final token = await _ensureFreshAccessToken();
      return valid()
          ? {'Authorization': ?(token == null ? null : 'Bearer $token')}
          : const {};
    }
    if (session.refreshToken.isEmpty) {
      await _handleSessionExpired('no_refresh_token');
      return const {};
    }
    try {
      final refreshed = await _refreshSession(session, trigger: 'window_401');
      return valid()
          ? {'Authorization': 'Bearer ${refreshed.accessToken}'}
          : const {};
    } on NativeLoginException catch (e) {
      if (e.rejected) {
        await _refreshRejected(
          session,
          ownerEpoch: ownerEpoch,
          requestEpoch: requestEpoch,
        );
      }
    } on Object {
      // Kept signed in; the window's request fails with its 401.
    }
    final now = _session;
    return !valid() || now == null
        ? const {}
        : {'Authorization': 'Bearer ${now.accessToken}'};
  }

  Future<String?> _ensureFreshAccessToken() async {
    if (_pendingSessionWrite != null) await _persistPendingSession();
    final ownerEpoch = _ownerEpoch;
    final requestEpoch = _requestEpoch;
    final session = _session;
    if (session == null) return null;
    if (!session.needsRefresh()) return session.accessToken;
    if (session.refreshToken.isEmpty) return session.accessToken;
    try {
      final refreshed = await _refreshSession(session, trigger: 'proactive');
      return refreshed.accessToken;
    } on NativeLoginException catch (e) {
      // Already reported as auth.session.refresh_failed. A spent refresh
      // token is not sent again: the store may hold the pair that replaced
      // it. Otherwise the (possibly stale) token goes out; the server will
      // 401 and the response interceptor drives re-login.
      if (!e.rejected) return session.accessToken;
      return (await _refreshRejected(
        session,
        ownerEpoch: ownerEpoch,
        requestEpoch: requestEpoch,
      ))?.accessToken;
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

    // Another isolate may already have rotated the pair; its refresh token
    // would be spent, so the stored pair is taken over without a request.
    final ownerEpoch = _ownerEpoch;
    final requestEpoch = _requestEpoch;
    bool valid() =>
        !_disposed &&
        ownerEpoch == _ownerEpoch &&
        requestEpoch == _requestEpoch &&
        url == _baseUrl;
    late final Future<HermesSession> future;
    future = _adoptStored(current)
        .then((adopted) async {
          if (!valid()) throw StateError('The session changed during refresh');
          return adopted ??
              (await refreshNativeSession(
                url,
                current,
                httpClient: _tokenDio,
                onRetry: () {
                  if (!valid()) {
                    throw StateError('The session changed during refresh');
                  }
                  _events('auth.session.refresh_retried', {'trigger': trigger});
                },
              )).rotatedFrom(current);
        })
        .then((refreshed) async {
          if (!valid()) throw StateError('The session changed during refresh');
          if (identical(refreshed, _session)) return refreshed;
          // Signing out or switching server must not bring the old session
          // back; the same session read again keeps the rotated tokens, as
          // its refresh token is spent.
          if (_session?.refreshToken != current.refreshToken) {
            throw StateError('The session changed during the refresh');
          }
          _session = refreshed;
          _pendingSessionWrite = _PendingSessionWrite(
            _pendingSessionWrite?.expected ?? current,
            refreshed,
          );
          await _persistPendingSession();
          if (_pendingSessionWrite != null) {
            _events('auth.session.store_failed', {
              'error.type': _pendingSessionWrite!.errorType,
            });
          }
          if (!valid()) throw StateError('The session changed during refresh');
          _events('auth.session.refreshed', {'trigger': trigger});
          return refreshed;
        })
        .onError<NativeLoginException>((e, stack) {
          if (!valid()) {
            Error.throwWithStackTrace(
              StateError('The session changed during refresh'),
              stack,
            );
          }
          _events('auth.session.refresh_failed', {
            'trigger': trigger,
            'rejected': e.rejected,
            'http.response.status_code': ?e.statusCode,
          });
          Error.throwWithStackTrace(e, stack);
        })
        .whenComplete(() {
          if (identical(_refreshInFlight, future)) _refreshInFlight = null;
        });
    _refreshInFlight = future;
    return future;
  }

  /// The server refused [sent]'s refresh token. Another isolate on the same
  /// keychain, such as the one that answers notification buttons, may have
  /// rotated it already: a newer pair of the same user on the same dashboard
  /// in the store is taken over instead of signing the user out. Its write
  /// may still be under way, so the store is read again a moment later.
  /// Returns the session to go on with, or null once it is gone.
  Future<HermesSession?> _refreshRejected(
    HermesSession sent, {
    required int ownerEpoch,
    required int requestEpoch,
  }) async {
    bool valid() =>
        !_disposed &&
        ownerEpoch == _ownerEpoch &&
        requestEpoch == _requestEpoch;
    for (final wait in [Duration.zero, _rejectionRecheck]) {
      if (wait > Duration.zero) await Future<void>.delayed(wait);
      if (!valid()) return null;
      final current = _session;
      // Signed out, or now someone else's session: not this refresh's to end.
      if (current == null || !current.sameOwner(sent)) return null;
      // A caller rejected with the same token already took over a pair.
      if (current.refreshToken != sent.refreshToken) return current;
      // A rejected token may already have been rotated by another engine.
      // Unreadable storage cannot establish that its replacement is absent.
      final SessionRead stored;
      try {
        stored = await _tokenStore.readState(repair: false);
      } on Object {
        return null;
      }
      if (!valid()) return null;
      if (stored is SessionUnreadable) return null;
      final adopted = await _adoptStored(sent, snapshot: stored);
      if (!valid()) return null;
      if (adopted != null) return adopted;
    }
    if (!valid()) return null;
    final current = _session;
    if (current == null || !current.sameOwner(sent)) return null;
    if (current.refreshToken != sent.refreshToken) return current;
    await _handleSessionExpired('refresh_rejected');
    return valid() ? _session : null;
  }

  /// Takes over the stored pair when it replaced [sent]: the same user on the
  /// same dashboard as this controller, received after [sent], while this
  /// controller still holds [sent]. Null otherwise.
  Future<HermesSession?> _adoptStored(
    HermesSession sent, {
    SessionRead? snapshot,
  }) async {
    final ownerEpoch = _ownerEpoch;
    final requestEpoch = _requestEpoch;
    final HermesSession? stored;
    try {
      stored = (snapshot ?? await _tokenStore.readState(repair: false)).session;
    } on Object {
      return null;
    }
    if (_disposed ||
        ownerEpoch != _ownerEpoch ||
        requestEpoch != _requestEpoch ||
        stored == null ||
        !stored.sameOwner(sent) ||
        stored.serverUrl != _baseUrl ||
        // An older pair is no replacement: it is what a failed write left.
        !stored.isNewerThan(sent) ||
        _session?.refreshToken != sent.refreshToken) {
      return null;
    }
    _session = stored;
    _events('auth.session.adopted', const {});
    return stored;
  }

  Future<void> _handleSessionExpired(String cause) {
    if (_session == null) return Future.value();
    final expected = _pendingSessionWrite?.expected ?? _session!;
    final identity = _identity;
    _forgetPendingSession();
    _sessionExpiryGeneration++;
    _events('auth.session.expired', {'cause': cause});
    _expiredOwner = _verifiedOwner;
    _protectedRequestsAllowed = false;
    _sessionExpired = true;
    _ignoreStoredSession = true;
    final requestEpoch = ++_requestEpoch;
    _refreshInFlight = null;
    _session = null;
    _identity = null;
    final expiry = _finishExpiry(requestEpoch, expected, identity);
    _departureInFlight = expiry;
    notifyListeners();
    return expiry.whenComplete(() {
      if (identical(_departureInFlight, expiry)) _departureInFlight = null;
    });
  }

  Future<bool> _clearTokens() async {
    try {
      await _mutateTokens<void>(_tokenStore.clear);
      return true;
    } on Object {
      return false;
    }
  }

  Future<void> _finishExpiry(
    int requestEpoch,
    HermesSession expected,
    HermesIdentity? identity,
  ) async {
    var deletionFailed = false;
    try {
      final removed = await _mutateTokens(
        () => _tokenStore.replace(expected, null),
      );
      if (_disposed || requestEpoch != _requestEpoch) return;
      if (!removed) {
        final stored = (await _tokenStore.readState(repair: false)).session;
        if (_disposed || requestEpoch != _requestEpoch) return;
        if (stored != null &&
            stored.sameOwner(expected) &&
            stored.isNewerThan(expected)) {
          _session = stored;
          _identity = identity;
          _sessionExpired = false;
          _ignoreStoredSession = false;
          _protectedRequestsAllowed = identity != null;
          _setState(
            identity == null
                ? HermesConnectionState.connectionError
                : HermesConnectionState.ready,
          );
          return;
        }
      }
    } on Object {
      deletionFailed = true;
    }
    if (_disposed || requestEpoch != _requestEpoch) return;
    _ignoreStoredSession = deletionFailed;
    _errorMessage = deletionFailed
        ? 'Your session expired. This device could not remove the saved sign-in. '
              'Sign in again to replace it.'
        : 'Your session expired. Please sign in again.';
    _announceSignedOut(expired: true);
    _setState(HermesConnectionState.needsLogin);
  }

  /// A client for [baseUrl] with this controller's interceptors and the
  /// current connection's telemetry. Also serves
  /// the token endpoints, which the authenticated client must not use (it
  /// would try to attach and refresh the very token being minted).
  Dio _plainDio(
    String baseUrl, {
    Duration connectTimeout = const Duration(seconds: 15),
    Duration receiveTimeout = const Duration(seconds: 30),
  }) =>
      Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: connectTimeout,
            receiveTimeout: receiveTimeout,
          ),
        )
        ..interceptors.addAll([
          RequestTimeoutInterceptor(),
          ..._interceptors,
          ?_connection.interceptor,
        ]);

  void _announceSignedOut({bool expired = false}) {
    _sessionExpired = expired;
    if (!_signedOut.isClosed) _signedOut.add(null);
  }

  @override
  void dispose() {
    _forgetPendingSession();
    _disposed = true;
    _protectedRequestsAllowed = false;
    _ownerEpoch++;
    _requestEpoch++;
    _networkChanges?.cancel();
    _signedOut.close();
    notifyListeners();
    super.dispose();
  }

  void _setState(HermesConnectionState next) {
    if (_disposed) return;
    _state = next;
    _events('auth.state', {'state': next.name});
    notifyListeners();
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

/// [raw] as a dashboard base URL (a scheme added when missing, no trailing
/// slash), or null when it is not an http(s) address.
String? normalizeServerUrl(String raw) {
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

class _PendingSessionWrite {
  _PendingSessionWrite(this.expected, this.next);
  String errorType = 'StateError';
  final HermesSession expected;
  final HermesSession next;
}
