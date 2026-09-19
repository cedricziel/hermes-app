import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/auth/native_login_flow.dart';

class _TokenAdapter implements HttpClientAdapter {
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
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

Future<void> _hitCallback(Uri authorizeUrl, {String? state}) async {
  final redirect = Uri.parse(authorizeUrl.queryParameters['redirect_uri']!);
  final callback = redirect.replace(
    queryParameters: {
      'code': 'auth-code',
      'state': state ?? authorizeUrl.queryParameters['state']!,
    },
  );
  final client = HttpClient();
  final request = await client.getUrl(callback);
  final response = await request.close();
  await response.drain<void>();
  client.close();
}

void main() {
  test('redeems the loopback callback and closes the in-app browser', () async {
    final adapter = _TokenAdapter();
    Uri? launched;
    var closed = 0;

    final session = await runNativeLogin(
      'http://hermes.test:9119',
      provider: 'oidc',
      httpClient: Dio()..httpClientAdapter = adapter,
      launchBrowser: (url) async {
        launched = url;
        unawaited(_hitCallback(url));
        return true;
      },
      closeBrowser: () async => closed++,
    );

    expect(launched!.path, '/auth/native/authorize');
    expect(
      launched!.queryParameters['redirect_uri'],
      startsWith('http://127.0.0.1:'),
    );
    expect(
      adapter.lastRequest!.path,
      'http://hermes.test:9119/auth/native/token',
    );
    expect(adapter.lastRequest!.data['code'], 'auth-code');
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
          launchBrowser: (url) async {
            unawaited(_hitCallback(url, state: 'forged'));
            return true;
          },
          closeBrowser: () async => closed++,
        ),
        throwsA(isA<NativeLoginException>()),
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
          launchBrowser: (_) async => false,
          closeBrowser: () async {},
        ),
        throwsA(isA<NativeLoginException>()),
      );
    },
  );
}
