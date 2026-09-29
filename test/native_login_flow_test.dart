import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/auth/native_login_flow.dart';
import 'package:hermes_app/src/auth/sign_in_browser.dart';

class _TokenAdapter implements HttpClientAdapter {
  /// When set, the token response waits for it; [requested] fires first.
  Completer<void>? gate;
  final requested = Completer<void>();
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    if (!requested.isCompleted) requested.complete();
    await gate?.future;
    return ResponseBody.fromString(
      jsonEncode({
        'access_token': 'at',
        'refresh_token': 'rt',
        'expires_at': 1,
        'provider': 'oidc',
        'user_id': 'u1',
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Plays the browser's part: [onOpen] stands in for showing the page.
class _FakeBrowser implements SignInBrowser {
  _FakeBrowser({
    required this.onOpen,
    required this.onClose,
    this.finishedRedirect,
  });

  final Future<bool> Function(Uri url) onOpen;
  final Future<void> Function() onClose;

  /// What the flow asked to be told when the user closes the browser.
  void Function()? dismiss;

  @override
  final Uri? finishedRedirect;

  @override
  Future<bool> open(Uri url, {required void Function() onDismissed}) {
    dismiss = onDismissed;
    return onOpen(url);
  }

  @override
  Future<void> close() => onClose();
}

Future<HttpClientResponse> _hitCallback(
  Uri authorizeUrl, {
  String? state,
}) async {
  final redirect = Uri.parse(authorizeUrl.queryParameters['redirect_uri']!);
  final callback = redirect.replace(
    queryParameters: {
      'code': 'auth-code',
      'state': state ?? authorizeUrl.queryParameters['state']!,
    },
  );
  final client = HttpClient();
  final request = await client.getUrl(callback);
  request.followRedirects = false;
  final response = await request.close();
  await response.drain<void>();
  client.close();
  return response;
}

void main() {
  test('redeems the loopback callback and closes the in-app browser', () async {
    final adapter = _TokenAdapter();
    Uri? launched;
    var closed = 0;

    final session = await runNativeLogin(
      'http://hermes.test:9119',
      provider: 'oidc',
      httpClient: Dio(BaseOptions(baseUrl: 'http://hermes.test:9119'))
        ..httpClientAdapter = adapter,
      browser: _FakeBrowser(
        onOpen: (url) async {
          launched = url;
          unawaited(_hitCallback(url));
          return true;
        },
        onClose: () async => closed++,
      ),
    );

    expect(launched!.path, '/auth/native/authorize');
    expect(
      launched!.queryParameters['redirect_uri'],
      startsWith('http://127.0.0.1:'),
    );
    expect(adapter.lastRequest!.path, '/auth/native/token');
    expect(
      adapter.lastRequest!.uri.toString(),
      'http://hermes.test:9119/auth/native/token',
    );
    expect(
      (adapter.lastRequest!.data as Map<String, dynamic>)['code'],
      'auth-code',
    );
    expect(session.accessToken, 'at');
    expect(closed, 1);
  });

  test(
    'rejects a callback with a mismatched state and still closes the browser',
    () async {
      var closed = 0;

      await expectLater(
        runNativeLogin(
          'http://hermes.test:9119',
          httpClient: Dio()..httpClientAdapter = _TokenAdapter(),
          browser: _FakeBrowser(
            onOpen: (url) async {
              unawaited(_hitCallback(url, state: 'forged'));
              return true;
            },
            onClose: () async => closed++,
          ),
        ),
        throwsA(
          isA<NativeLoginException>().having(
            (e) => e.reason,
            'reason',
            NativeLoginFailure.stateMismatch,
          ),
        ),
      );
      expect(closed, 1);
    },
  );

  test(
    'fails with a readable message when the browser cannot be opened',
    () async {
      await expectLater(
        runNativeLogin(
          'http://hermes.test:9119',
          browser: _FakeBrowser(
            onOpen: (_) async => false,
            onClose: () async {},
          ),
        ),
        throwsA(
          isA<NativeLoginException>().having(
            (e) => e.reason,
            'reason',
            NativeLoginFailure.browserLaunch,
          ),
        ),
      );
    },
  );

  test('stops waiting and closes the browser when cancelled', () async {
    var closed = 0;
    final cancel = Completer<void>();

    final login = runNativeLogin(
      'http://hermes.test:9119',
      browser: _FakeBrowser(
        onOpen: (_) async {
          scheduleMicrotask(cancel.complete);
          return true;
        },
        onClose: () async => closed++,
      ),
      cancelled: cancel.future,
    );

    await expectLater(login, throwsA(isA<NativeLoginCancelled>()));
    expect(closed, 1);
  });

  test(
    'reports the flow\'s own failure when closing the browser throws',
    () async {
      await expectLater(
        runNativeLogin(
          'http://hermes.test:9119',
          httpClient: Dio()..httpClientAdapter = _TokenAdapter(),
          browser: _FakeBrowser(
            onOpen: (url) async {
              unawaited(_hitCallback(url, state: 'forged'));
              return true;
            },
            onClose: () async => throw StateError('no web view is open'),
          ),
        ),
        throwsA(isA<NativeLoginException>()),
      );
    },
  );

  test('a cancel during the token exchange discards the session', () async {
    final adapter = _TokenAdapter()..gate = Completer<void>();
    final cancel = Completer<void>();

    final login = runNativeLogin(
      'http://hermes.test:9119',
      httpClient: Dio(BaseOptions(baseUrl: 'http://hermes.test:9119'))
        ..httpClientAdapter = adapter,
      browser: _FakeBrowser(
        onOpen: (url) async {
          unawaited(_hitCallback(url));
          return true;
        },
        onClose: () async {},
      ),
      cancelled: cancel.future,
    );
    await adapter.requested.future;
    cancel.complete();
    adapter.gate!.complete();

    await expectLater(login, throwsA(isA<NativeLoginCancelled>()));
  });

  test(
    'answers the redirect while the browser launch is still pending',
    () async {
      // iOS reports the launch as done only after the sheet finished loading,
      // and with an IdP session that load is the redirect to the listener.
      final session = await runNativeLogin(
        'http://hermes.test:9119',
        httpClient: Dio(BaseOptions(baseUrl: 'http://hermes.test:9119'))
          ..httpClientAdapter = _TokenAdapter(),
        browser: _FakeBrowser(
          onOpen: (url) async {
            await _hitCallback(url);
            return true;
          },
          onClose: () async {},
        ),
      ).timeout(const Duration(seconds: 5));

      expect(session.accessToken, 'at');
    },
  );

  test(
    'redirects the browser to the finished address once it has the code',
    () async {
      HttpClientResponse? answer;
      final session = await runNativeLogin(
        'http://hermes.test:9119',
        httpClient: Dio(BaseOptions(baseUrl: 'http://hermes.test:9119'))
          ..httpClientAdapter = _TokenAdapter(),
        browser: _FakeBrowser(
          onOpen: (url) async {
            unawaited(_hitCallback(url).then((r) => answer = r));
            return true;
          },
          onClose: () async {},
          finishedRedirect: Uri.parse('hermes-app-signin://signed-in'),
        ),
      );

      expect(session.accessToken, 'at');
      expect(answer!.statusCode, HttpStatus.found);
      expect(
        answer!.headers.value(HttpHeaders.locationHeader),
        'hermes-app-signin://signed-in',
      );
    },
  );

  test('stops waiting when the user closes the browser', () async {
    var closed = 0;
    late _FakeBrowser browser;
    browser = _FakeBrowser(
      onOpen: (_) async {
        scheduleMicrotask(() => browser.dismiss!());
        return true;
      },
      onClose: () async => closed++,
    );

    await expectLater(
      runNativeLogin('http://hermes.test:9119', browser: browser),
      throwsA(isA<NativeLoginCancelled>()),
    );
    expect(closed, 1);
  });

  test('a browser closing after the redirect keeps the sign-in', () async {
    final adapter = _TokenAdapter()..gate = Completer<void>();
    late _FakeBrowser browser;
    browser = _FakeBrowser(
      onOpen: (url) async {
        unawaited(_hitCallback(url));
        return true;
      },
      onClose: () async {},
    );

    final login = runNativeLogin(
      'http://hermes.test:9119',
      httpClient: Dio(BaseOptions(baseUrl: 'http://hermes.test:9119'))
        ..httpClientAdapter = adapter,
      browser: browser,
    );
    await adapter.requested.future;
    browser.dismiss!();
    adapter.gate!.complete();

    expect((await login).accessToken, 'at');
  });
}
