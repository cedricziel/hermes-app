import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:hermes_app/src/auth/auth_controller.dart';

const _savedUrlKey = 'hermes.server_base_url';

Future<HttpServer> _startFakeDashboard() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) {
    request.response
      ..headers.contentType = ContentType.json
      ..write(jsonEncode({'auth_required': false, 'version': 'test'}))
      ..close();
  });
  return server;
}

void main() {
  late HttpServer dashboard;
  late String dashboardUrl;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    dashboard = await _startFakeDashboard();
    dashboardUrl = 'http://127.0.0.1:${dashboard.port}';
  });

  tearDown(() => dashboard.close(force: true));

  test('dev server url connects without a saved address', () async {
    final controller = AuthController(devServerUrl: dashboardUrl);

    await controller.bootstrap();

    expect(controller.state, HermesConnectionState.ready);
    expect(controller.baseUrl, dashboardUrl);
  });

  test(
    'dev server url wins over the saved address and leaves it alone',
    () async {
      final prefs = SharedPreferencesAsync();
      await prefs.setString(_savedUrlKey, 'http://saved.example:9119');
      final controller = AuthController(devServerUrl: dashboardUrl);

      await controller.bootstrap();

      expect(controller.baseUrl, dashboardUrl);
      expect(await prefs.getString(_savedUrlKey), 'http://saved.example:9119');
    },
  );

  test('without a dev server url the first launch asks for one', () async {
    final controller = AuthController(devServerUrl: '');

    await controller.bootstrap();

    expect(controller.state, HermesConnectionState.needsServerUrl);
  });

  test('restoring the saved server never shows the setup screen', () async {
    await SharedPreferencesAsync().setString(_savedUrlKey, dashboardUrl);
    final controller = AuthController(devServerUrl: '');
    final seen = <HermesConnectionState>[];
    controller.addListener(() => seen.add(controller.state));

    await controller.bootstrap();

    expect(seen, [HermesConnectionState.ready]);
  });

  test('a failed restore lands on the setup screen with the error', () async {
    await SharedPreferencesAsync().setString(_savedUrlKey, dashboardUrl);
    await dashboard.close(force: true);
    final controller = AuthController(devServerUrl: '');

    await controller.bootstrap();

    expect(controller.state, HermesConnectionState.connectionError);
  });
}
