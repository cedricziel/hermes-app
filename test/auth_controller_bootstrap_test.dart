import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:hermes_app/src/auth/auth_controller.dart';

import 'support/memory_token_store.dart';

Future<HttpServer> _startDashboard(Object providersBody) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) {
    final body = switch (request.uri.path) {
      '/api/status' => {
        'auth_required': true,
        'auth_flows': ['native_pkce'],
      },
      '/api/auth/providers' => providersBody,
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

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  tearDown(() => dashboard.close(force: true));

  final malformed = {
    'providers is not a list': {'providers': 'oidc'},
    'a provider row is not an object': {
      'providers': ['oidc'],
    },
    'the body is a list': [
      {'name': 'oidc'},
    ],
  };

  for (final entry in malformed.entries) {
    test('a malformed providers list surfaces a connection error when '
        '${entry.key}', () async {
      dashboard = await _startDashboard(entry.value);
      final controller = AuthController(
        tokenStore: MemoryTokenStore(),
        devServerUrl: 'http://127.0.0.1:${dashboard.port}',
      );

      await controller.bootstrap().timeout(const Duration(seconds: 5));

      expect(controller.state, HermesConnectionState.connectionError);
      expect(controller.errorMessage, 'Could not load sign-in options');
    });
  }
}
