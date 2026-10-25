import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/models/hermes_session.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/memory_token_store.dart';

const _storedSession = HermesSession(
  accessToken: 'access',
  refreshToken: 'refresh',
  expiresAt: 4102444800,
  provider: 'basic',
  userId: 'u1',
);

/// Answers `/api/status` and `/api/auth/me` with whatever [status] and [me]
/// currently hold. A [String] is sent as an HTML page.
class _Dashboard {
  _Dashboard._(this._server);

  static Future<_Dashboard> start({Object? status, Object? me}) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final dashboard = _Dashboard._(server)
      ..status =
          status ??
          {
            'auth_required': true,
            'auth_flows': ['native_pkce'],
          }
      ..me = me ?? {'user_id': 'u1'};
    server.listen(dashboard._handle);
    return dashboard;
  }

  final HttpServer _server;
  late Object status;
  late Object me;

  String get url => 'http://127.0.0.1:${_server.port}';

  Future<void> close() => _server.close(force: true);

  void _handle(HttpRequest request) {
    final body = switch (request.uri.path) {
      '/api/status' => status,
      '/api/auth/providers' => {'providers': []},
      '/api/auth/me' => me,
      _ => null,
    };
    final response = request.response;
    if (body == null) {
      response.statusCode = 404;
    } else if (body is String) {
      response
        ..headers.contentType = ContentType.html
        ..write(body);
    } else {
      response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(body));
    }
    response.close();
  }
}

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

  final malformedBodies = <String, Object>{
    'the body is a list': [1, 2],
    'the body is an HTML page': '<html>proxy error</html>',
    'a field has the wrong type': {'auth_required': 'yes', 'user_id': 5},
  };

  group('a malformed /api/status', () {
    late _Dashboard server;

    tearDown(() => server.close());

    for (final entry in malformedBodies.entries) {
      test('surfaces a connection error when ${entry.key}', () async {
        server = await _Dashboard.start(status: entry.value);
        final controller = AuthController(tokenStore: MemoryTokenStore());

        await controller
            .connect(server.url)
            .timeout(const Duration(seconds: 5));

        expect(controller.state, HermesConnectionState.connectionError);
        expect(controller.errorMessage, 'Unexpected response from the server');
      });
    }

    test('ends a restore on a connection error, not on initializing', () async {
      server = await _Dashboard.start(status: [1]);
      final controller = AuthController(
        tokenStore: MemoryTokenStore(),
        devServerUrl: server.url,
      );

      await controller.bootstrap().timeout(const Duration(seconds: 5));

      expect(controller.state, HermesConnectionState.connectionError);
      expect(controller.errorMessage, 'Unexpected response from the server');
    });

    test('a wrongly typed list field is a connection error', () async {
      server = await _Dashboard.start(
        status: {'auth_required': true, 'auth_flows': 'native_pkce'},
      );
      final controller = AuthController(tokenStore: MemoryTokenStore());

      await controller.connect(server.url).timeout(const Duration(seconds: 5));

      expect(controller.state, HermesConnectionState.connectionError);
    });
  });

  group('a malformed /api/auth/me for a stored session', () {
    late _Dashboard server;
    late MemoryTokenStore tokens;

    setUp(() => tokens = MemoryTokenStore(_storedSession));

    tearDown(() => server.close());

    for (final entry in malformedBodies.entries) {
      test('keeps the session and shows an error when ${entry.key}', () async {
        server = await _Dashboard.start(me: entry.value);
        final controller = AuthController(tokenStore: tokens);

        await controller
            .connect(server.url)
            .timeout(const Duration(seconds: 5));

        expect(controller.state, HermesConnectionState.connectionError);
        expect(controller.errorMessage, 'Unexpected response from the server');
        expect(tokens.session, _storedSession);
      });
    }

    test(
      'ends a restore on a connection error and lets the user retry',
      () async {
        server = await _Dashboard.start(me: [1]);
        final controller = AuthController(
          tokenStore: tokens,
          devServerUrl: server.url,
        );

        await controller.bootstrap().timeout(const Duration(seconds: 5));

        expect(controller.state, HermesConnectionState.connectionError);
        expect(tokens.session, _storedSession);

        server.me = {'user_id': 'u1', 'email': 'a@b.c'};
        await controller
            .connect(server.url)
            .timeout(const Duration(seconds: 5));

        expect(controller.state, HermesConnectionState.ready);
        expect(controller.identity?.email, 'a@b.c');
      },
    );
  });
}
