import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/hermes_session.dart';
import 'pkce.dart';

/// The fixed set of reasons a login or refresh can fail.
enum NativeLoginFailure {
  listenerUnavailable,
  browserLaunch,
  timeout,
  exchange,
  refresh,
  idpError,
  missingCode,
  stateMismatch,
  listenerClosed,
  other,
}

/// Raised when the native login flow fails for a reason the user should see
/// (timeout, state mismatch, IdP error, browser launch failure, ...).
class NativeLoginException implements Exception {
  NativeLoginException(
    this.message, {
    this.statusCode,
    this.reason = NativeLoginFailure.other,
  });
  final String message;

  /// Why the flow failed. Its [Enum.name] is a fixed value, safe to record.
  final NativeLoginFailure reason;

  /// The HTTP status the server answered with, when the failure was one.
  final int? statusCode;

  /// True when the server refused the credential itself (as opposed to being
  /// unreachable or failing), so retrying with it cannot succeed.
  bool get rejected =>
      statusCode == 400 || statusCode == 401 || statusCode == 403;

  @override
  String toString() => message;
}

/// Raised when the caller abandons the flow through `cancelled`.
class NativeLoginCancelled implements Exception {
  const NativeLoginCancelled();
}

/// Runs the browser sign-in for [runNativeLogin]; replaced in tests.
typedef NativeLogin = Future<HermesSession> Function(
  String baseUrl, {
  String? provider,
  Dio? httpClient,
  Future<void>? cancelled,
});

const _loginTimeout = Duration(minutes: 5);

typedef BrowserLauncher = Future<bool> Function(Uri url);
typedef BrowserCloser = Future<void> Function();

// iOS suspends the app as soon as Safari takes the foreground, which freezes
// the loopback listener before the IdP redirects back to it. An in-app
// SFSafariViewController keeps the app active so the listener stays alive.
Future<bool> _defaultLaunchBrowser(Uri url) => launchUrl(
  url,
  mode: Platform.isIOS
      ? LaunchMode.inAppBrowserView
      : LaunchMode.externalApplication,
);

Future<void> _defaultCloseBrowser() async {
  if (Platform.isIOS) await closeInAppWebView();
}

// Closing the sheet is cleanup. It throws when the user already dismissed it,
// and that must not replace the flow's own outcome.
Future<void> _closeQuietly(BrowserCloser close) async {
  try {
    await close();
  } on Object {
    // Nothing left to close.
  }
}

// No tokens, no secrets — just a close affordance for the tab the system
// browser opened. Matches Hermes Desktop's DONE_HTML.
const _doneHtml = '''
<!doctype html><meta charset="utf-8"><title>Signed in</title>
<body style="font:15px system-ui;margin:3rem;text-align:center">
<h2>&#10003; Signed in to Hermes</h2>
<p>You can close this tab and return to the app.</p>
</body>
''';

/// Runs a full RFC 8252 (OAuth 2.0 for Native Apps) login against a Hermes
/// dashboard: opens the system browser at `/auth/native/authorize` with a
/// fresh PKCE challenge and a loopback `redirect_uri`, waits for the
/// authorization redirect on a local HTTP listener, then redeems the code at
/// `/auth/native/token`. Works identically for every registered provider —
/// OIDC providers redirect through their IdP, and the bundled
/// username/password provider instead renders Hermes's own `/login` form in
/// the system browser (so the OS password manager can autofill it), but
/// either way this app only ever sees the final bearer token set.
///
/// [baseUrl] is the dashboard's base URL (e.g. `http://192.168.1.20:9119`).
/// [provider] selects a specific registered provider by name; leave it null
/// to let the gateway auto-select when exactly one is eligible.
///
/// Completing [cancelled] abandons the flow with [NativeLoginCancelled] and
/// releases the listener. The browser sheet gives no signal when the user
/// dismisses it, so this is the only way out short of the timeout.
///
/// [httpClient], when given, must already point at [baseUrl]; the token
/// exchange uses relative paths so request telemetry can record the route.
///
/// [launchBrowser] and [closeBrowser] default to `url_launcher`; tests
/// override them to play the browser's part.
Future<HermesSession> runNativeLogin(
  String baseUrl, {
  String? provider,
  Dio? httpClient,
  BrowserLauncher launchBrowser = _defaultLaunchBrowser,
  BrowserCloser closeBrowser = _defaultCloseBrowser,
  Future<void>? cancelled,
}) async {
  final dio = httpClient ?? Dio(BaseOptions(baseUrl: baseUrl));
  final pkce = PkcePair.generate();
  final state = generatePkceState();

  HttpServer server;
  try {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  } on SocketException catch (e) {
    throw NativeLoginException(
      'Could not start local sign-in listener: $e',
      reason: NativeLoginFailure.listenerUnavailable,
    );
  }

  var wasCancelled = false;
  unawaited(
    cancelled?.then((_) {
      wasCancelled = true;
      return server.close(force: true);
    }),
  );

  try {
    final redirectUri = 'http://127.0.0.1:${server.port}/callback';
    final authorizeUrl = _buildAuthorizeUrl(
      baseUrl,
      challenge: pkce.challenge,
      redirectUri: redirectUri,
      state: state,
      provider: provider,
    );

    // Listen before the browser opens. On iOS the launch call only returns once
    // the sheet has finished loading, and when the IdP already has a session
    // that load is the redirect to this listener, so it cannot finish until
    // something answers it.
    final callback = _awaitCallback(server, expectedState: state);
    callback.ignore();

    final launched = await launchBrowser(Uri.parse(authorizeUrl));
    if (!launched) {
      throw NativeLoginException(
        'Could not open the system browser for sign-in.',
        reason: NativeLoginFailure.browserLaunch,
      );
    }

    final code = await callback.timeout(
      _loginTimeout,
      onTimeout: () {
        throw NativeLoginException(
          'Sign-in timed out. Please try again.',
          reason: NativeLoginFailure.timeout,
        );
      },
    );

    final tokenResponse = await dio.post<Map<String, dynamic>>(
      '/auth/native/token',
      data: {'code': code, 'code_verifier': pkce.verifier},
    );
    if (wasCancelled) throw const NativeLoginCancelled();
    final data = tokenResponse.data;
    if (data == null) {
      throw NativeLoginException(
        'Empty token response from server.',
        reason: NativeLoginFailure.exchange,
      );
    }
    return HermesSession.fromTokenResponse(data);
  } on NativeLoginException {
    if (wasCancelled) throw const NativeLoginCancelled();
    rethrow;
  } on DioException catch (e) {
    if (wasCancelled) throw const NativeLoginCancelled();
    throw NativeLoginException(
      _describeDioError(e),
      statusCode: e.response?.statusCode,
      reason: NativeLoginFailure.exchange,
    );
  } finally {
    unawaited(server.close(force: true));
    await _closeQuietly(closeBrowser);
  }
}

/// Rotates a stored session's tokens via `/auth/native/refresh`.
Future<HermesSession> refreshNativeSession(
  String baseUrl,
  HermesSession session, {
  Dio? httpClient,
}) async {
  final dio = httpClient ?? Dio(BaseOptions(baseUrl: baseUrl));
  try {
    final response = await dio.post<Map<String, dynamic>>(
      '/auth/native/refresh',
      data: {
        'refresh_token': session.refreshToken,
        'provider': session.provider,
      },
    );
    final data = response.data;
    if (data == null) {
      throw NativeLoginException(
        'Empty refresh response from server.',
        reason: NativeLoginFailure.refresh,
      );
    }
    return HermesSession.fromTokenResponse(data);
  } on DioException catch (e) {
    throw NativeLoginException(
      _describeDioError(e),
      statusCode: e.response?.statusCode,
      reason: NativeLoginFailure.refresh,
    );
  }
}

Future<String> _awaitCallback(
  HttpServer server, {
  required String expectedState,
}) async {
  await for (final request in server) {
    final params = request.uri.queryParameters;
    request.response
      ..statusCode = 200
      ..headers.contentType = ContentType.html
      ..write(_doneHtml);
    await request.response.close();

    // Ignore stray requests (favicon probes, etc.) that carry neither.
    if (!params.containsKey('code') && !params.containsKey('error')) {
      continue;
    }

    final error = params['error'];
    if (error != null) {
      final description = params['error_description'] ?? '';
      throw NativeLoginException(
        'Sign-in was rejected: $error${description.isEmpty ? '' : ' ($description)'}',
        reason: NativeLoginFailure.idpError,
      );
    }

    final code = params['code'];
    if (code == null || code.isEmpty) {
      throw NativeLoginException(
        'Sign-in callback missing authorization code.',
        reason: NativeLoginFailure.missingCode,
      );
    }

    final returnedState = params['state'];
    if (expectedState.isEmpty || returnedState != expectedState) {
      throw NativeLoginException(
        'Sign-in callback state mismatch (possible CSRF); please try again.',
        reason: NativeLoginFailure.stateMismatch,
      );
    }

    return code;
  }
  throw NativeLoginException(
    'Sign-in listener closed unexpectedly.',
    reason: NativeLoginFailure.listenerClosed,
  );
}

String _buildAuthorizeUrl(
  String baseUrl, {
  required String challenge,
  required String redirectUri,
  required String state,
  String? provider,
}) {
  final uri = Uri.parse(_joinUrl(baseUrl, '/auth/native/authorize'));
  final query = <String, String>{
    'code_challenge': challenge,
    'code_challenge_method': 'S256',
    'redirect_uri': redirectUri,
    'state': state,
    if (provider != null && provider.isNotEmpty) 'provider': provider,
  };
  return uri.replace(queryParameters: query).toString();
}

String _joinUrl(String baseUrl, String path) {
  final trimmedBase = baseUrl.replaceAll(RegExp(r'/+$'), '');
  final trimmedPath = path.startsWith('/') ? path : '/$path';
  return '$trimmedBase$trimmedPath';
}

String _describeDioError(DioException e) {
  final data = e.response?.data;
  if (data is Map && data['detail'] is String) {
    return data['detail'] as String;
  }
  return e.message ?? 'Network error during sign-in.';
}
