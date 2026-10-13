import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/watch/watch_bridge.dart';
import 'package:hermes_app/src/watch/watch_context.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/memory_token_store.dart';

WatchContextStore memoryContexts() {
  String? value;
  return WatchContextStore(
    read: () async => value,
    write: (v) async {
      value = v;
    },
    randomId: () => 'test-context',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  late HttpServer dashboard;
  late List<String> requestedPaths;
  var authRequired = true;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    requestedPaths = [];
    authRequired = true;
    dashboard = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    dashboard.listen((request) {
      requestedPaths.add(request.uri.path);
      final body = switch (request.uri.path) {
        '/api/status' => {
          'auth_required': authRequired,
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

  test(
    'retains ordered usable and departure publications across auth changes',
    () async {
      authRequired = false;
      final auth = AuthController(
        tokenStore: MemoryTokenStore(),
        devServerUrl: 'http://127.0.0.1:${dashboard.port}',
      );
      final published = <bool>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(WatchBridge.channelName),
            (call) async {
              if (call.method == 'publishSessionState') {
                published.add((call.arguments as Map)['usable'] as bool);
              }
              return call.arguments;
            },
          );
      final contexts = memoryContexts();
      final bridge = WatchBridge(
        contextStore: contexts,
        handler: WatchBridge.handlerFor(auth, contextStore: contexts),
        auth: auth,
      )..start();
      addTearDown(() {
        bridge.dispose();
        auth.dispose();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel(WatchBridge.channelName),
              null,
            );
      });
      await pumpEventQueue();
      expect(published, isEmpty);
      await auth.bootstrap();
      await pumpEventQueue();
      expect(published, [true]);

      await auth.changeServer();
      await pumpEventQueue();

      expect(published, [true, false]);
    },
  );

  test('answers signed_out while the dashboard still wants a login, without '
      'asking it anything', () async {
    final auth = AuthController(
      tokenStore: MemoryTokenStore(),
      devServerUrl: 'http://127.0.0.1:${dashboard.port}',
    );
    await auth.bootstrap();
    expect(auth.state, HermesConnectionState.needsLogin);
    requestedPaths.clear();
    final handler = WatchBridge.handlerFor(
      auth,
      contextStore: memoryContexts(),
    );

    final threads = await handler.handle({'op': 'threads'});
    final send = await handler.handle({'op': 'send', 'text': 'Hi'});

    expect(threads, {'ok': false, 'error': 'signed_out'});
    expect(send, {'ok': false, 'error': 'signed_out'});
    expect(requestedPaths, isEmpty);
  });

  test('answers once the session is restored, not before', () async {
    authRequired = false;
    final auth = AuthController(
      tokenStore: MemoryTokenStore(),
      devServerUrl: 'http://127.0.0.1:${dashboard.port}',
    );
    expect(auth.state, HermesConnectionState.initializing);
    final handler = WatchBridge.handlerFor(
      auth,
      contextStore: memoryContexts(),
    );

    final threads = handler.handle({'op': 'session'});
    await auth.bootstrap();

    expect(await threads, {
      'ok': true,
      'protocolVersion': 2,
      'contextId': 'test-context',
      'revision': 0,
    });
  });

  test(
    'answers unavailable when the session is not restored in time',
    () async {
      final auth = AuthController(
        tokenStore: MemoryTokenStore(),
        devServerUrl: 'http://127.0.0.1:${dashboard.port}',
      );
      final handler = WatchBridge.handlerFor(auth, readyTimeout: Duration.zero);

      final threads = await handler.handle({'op': 'threads'});

      expect(threads, {'ok': false, 'error': 'unavailable'});
    },
  );
}
