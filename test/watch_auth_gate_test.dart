import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/watch/watch_bridge.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/memory_token_store.dart';

void main() {
  late HttpServer dashboard;
  late List<String> requestedPaths;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    requestedPaths = [];
    dashboard = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    dashboard.listen((request) {
      requestedPaths.add(request.uri.path);
      final body = switch (request.uri.path) {
        '/api/status' => {
          'auth_required': true,
          'auth_flows': ['native_pkce'],
        },
        '/api/auth/providers' => {'providers': []},
        _ => {'sessions': [], 'total': 0},
      };
      request.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(body))
        ..close();
    });
  });

  tearDown(() => dashboard.close(force: true));

  test('answers signed_out while the dashboard still wants a login, without '
      'asking it anything', () async {
    final auth = AuthController(
      tokenStore: MemoryTokenStore(),
      devServerUrl: 'http://127.0.0.1:${dashboard.port}',
    );
    await auth.bootstrap();
    expect(auth.state, HermesConnectionState.needsLogin);
    requestedPaths.clear();
    final handler = WatchBridge.handlerFor(auth);

    final threads = await handler.handle({'op': 'threads'});
    final send = await handler.handle({'op': 'send', 'text': 'Hi'});

    expect(threads, {'ok': false, 'error': 'signed_out'});
    expect(send, {'ok': false, 'error': 'signed_out'});
    expect(requestedPaths, isEmpty);
  });
}
