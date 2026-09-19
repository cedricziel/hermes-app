import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:hermes_app/src/auth/auth_controller.dart';

/// A dashboard without the auth gate, as `hermes dashboard` serves on
/// loopback: `/api/status` is public, every other route wants the session
/// token the page embeds, sent as `X-Hermes-Session-Token`.
class _LoopbackDashboard {
  _LoopbackDashboard._(this._server);

  static Future<_LoopbackDashboard> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final dashboard = _LoopbackDashboard._(server);
    server.listen(dashboard._handle);
    return dashboard;
  }

  final HttpServer _server;
  String token = 'token-1';
  int pageFetches = 0;
  final List<String?> sessionTokens = [];

  String get url => 'http://127.0.0.1:${_server.port}';

  Future<void> close() => _server.close(force: true);

  void _handle(HttpRequest request) {
    final response = request.response;
    switch (request.uri.path) {
      case '/':
        pageFetches++;
        response
          ..headers.contentType = ContentType.html
          ..write('<script>window.__HERMES_SESSION_TOKEN__="$token";</script>');
      case '/api/status':
        _json(response, 200, {'auth_required': false, 'version': 'test'});
        return;
      case '/api/sessions':
        final sent = request.headers.value('X-Hermes-Session-Token');
        sessionTokens.add(sent);
        if (sent != token) {
          _json(response, 401, {'detail': 'Unauthorized'});
          return;
        }
        _json(response, 200, {'sessions': [], 'total': 0});
        return;
      default:
        response.statusCode = 404;
    }
    response.close();
  }

  void _json(HttpResponse response, int status, Object body) {
    response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body))
      ..close();
  }
}

void main() {
  late _LoopbackDashboard dashboard;
  late AuthController controller;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    dashboard = await _LoopbackDashboard.start();
    controller = AuthController(devServerUrl: dashboard.url);
    await controller.bootstrap();
  });

  tearDown(() => dashboard.close());

  test('an ungated dashboard is connected and ready', () {
    expect(controller.state, HermesConnectionState.ready);
  });

  test('requests to an ungated dashboard carry its session token', () async {
    final response = await controller.api!.raw.getSessionsApiSessionsGet();

    expect(response.statusCode, 200);
    expect(dashboard.sessionTokens, ['token-1']);
  });

  test('the session token is fetched once and reused', () async {
    await controller.api!.raw.getSessionsApiSessionsGet();
    await controller.api!.raw.getSessionsApiSessionsGet();

    expect(dashboard.pageFetches, 1);
  });

  test('a restarted dashboard\'s new token is picked up once', () async {
    await controller.api!.raw.getSessionsApiSessionsGet();
    dashboard.token = 'token-2';

    final response = await controller.api!.raw.getSessionsApiSessionsGet();

    expect(response.statusCode, 200);
    expect(dashboard.sessionTokens, ['token-1', 'token-1', 'token-2']);
  });

  test('a token the dashboard keeps rejecting fails with 401', () async {
    final rejecting = _RejectingPage();
    await rejecting.start();
    addTearDown(rejecting.close);
    final other = AuthController(devServerUrl: rejecting.url);
    await other.bootstrap();

    expect(
      other.api!.raw.getSessionsApiSessionsGet(),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'status',
          401,
        ),
      ),
    );
  });
}

/// A dashboard whose page token never matches what its API accepts.
class _RejectingPage {
  late final HttpServer _server;

  String get url => 'http://127.0.0.1:${_server.port}';

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen((request) {
      final response = request.response;
      if (request.uri.path == '/') {
        response
          ..headers.contentType = ContentType.html
          ..write('<script>window.__HERMES_SESSION_TOKEN__="never";</script>');
      } else if (request.uri.path == '/api/status') {
        response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'auth_required': false}));
      } else {
        response.statusCode = 401;
      }
      response.close();
    });
  }

  Future<void> close() => _server.close(force: true);
}
