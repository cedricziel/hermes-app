import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/auth/native_login_flow.dart';

import 'support/memory_token_store.dart';
import 'support/recorded_events.dart';

/// A gated dashboard offering one provider, with nobody signed in.
Future<HttpServer> _startDashboard() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) {
    final body = switch (request.uri.path) {
      '/api/status' => {
        'auth_required': true,
        'auth_flows': ['native_pkce'],
      },
      '/api/auth/providers' => {
        'providers': [
          {'name': 'oidc', 'display_name': 'Company SSO'},
        ],
      },
      _ => null,
    };
    request.response
      ..statusCode = body == null ? 404 : 200
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body ?? {}))
      ..close();
  });
  return server;
}

void main() {
  late HttpServer dashboard;
  late RecordedEvents events;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    events = RecordedEvents();
  });

  tearDown(() => dashboard.close(force: true));

  Future<AuthController> controllerWith(NativeLogin login) async {
    dashboard = await _startDashboard();
    final controller = AuthController(
      tokenStore: MemoryTokenStore(),
      devServerUrl: 'http://127.0.0.1:${dashboard.port}',
      login: login,
      events: events.call,
    );
    await controller.bootstrap();
    expect(controller.state, HermesConnectionState.needsLogin);
    return controller;
  }

  test('cancelling returns to the login screen and is recorded', () async {
    final controller = await controllerWith((
      url, {
      provider,
      httpClient,
      cancelled,
    }) async {
      await cancelled;
      throw const NativeLoginCancelled();
    });

    final signIn = controller.signInWithProvider(controller.providers.single);
    expect(controller.state, HermesConnectionState.signingIn);
    controller.cancelSignIn();
    await signIn;

    expect(controller.state, HermesConnectionState.needsLogin);
    expect(events.namesStartingWith('auth.sign_in.'), [
      'auth.sign_in.started',
      'auth.sign_in.cancelled',
    ]);
  });

  test(
    'a flow failure shows its message and records only the reason',
    () async {
      final controller = await controllerWith(
        (url, {provider, httpClient, cancelled}) async =>
            throw NativeLoginException(
              'Sign-in timed out. Please try again.',
              reason: NativeLoginFailure.timeout,
            ),
      );

      await controller.signInWithProvider(controller.providers.single);

      expect(controller.state, HermesConnectionState.needsLogin);
      expect(controller.errorMessage, 'Sign-in timed out. Please try again.');
      final failed = events.named('auth.sign_in.failed').single;
      expect(failed['reason'], 'timeout');
      expect(failed.keys, isNot(contains('message')));
    },
  );

  test('an unexpected error cannot leave the spinner running', () async {
    final controller = await controllerWith(
      (url, {provider, httpClient, cancelled}) async =>
          throw PlatformException(code: 'closed'),
    );

    await controller.signInWithProvider(controller.providers.single);

    expect(controller.state, HermesConnectionState.needsLogin);
    final failed = events.named('auth.sign_in.failed').single;
    expect(failed['reason'], 'unexpected');
    expect(failed['exception.type'], 'PlatformException');
  });
}
