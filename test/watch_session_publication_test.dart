import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/watch/watch_bridge.dart';
import 'package:hermes_app/src/watch/watch_request_handler.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/memory_token_store.dart';
import 'support/recorded_events.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(WatchBridge.channelName);
  const codec = StandardMethodCodec();
  late HttpServer server;
  late AuthController auth;
  late WatchBridge bridge;
  late _SessionHandler handler;
  late RecordedEvents events;
  late List<bool> attempts;
  var publicationFails = false;

  Future<Map> request() async {
    final response = Completer<ByteData?>();
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          WatchBridge.channelName,
          codec.encodeMethodCall(
            const MethodCall('request', {'op': 'threads'}),
          ),
          response.complete,
        );
    return codec.decodeEnvelope((await response.future)!) as Map;
  }

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) {
      request.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'auth_required': false}))
        ..close();
    });
    auth = AuthController(
      tokenStore: MemoryTokenStore(),
      devServerUrl: 'http://127.0.0.1:${server.port}',
    );
    await auth.bootstrap();
    attempts = [];
    publicationFails = false;
    events = RecordedEvents();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final usable = (call.arguments as Map)['usable'] as bool;
          attempts.add(usable);
          if (publicationFails) {
            throw PlatformException(code: 'publication_failed');
          }
          return {'revision': attempts.length, 'usable': usable};
        });
    handler = _SessionHandler(() => auth.protectedRequestsAllowed);
    bridge = WatchBridge(handler: handler, auth: auth, events: events.call);
  });

  tearDown(() async {
    bridge.dispose();
    auth.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await server.close(force: true);
  });

  test('failed usable publication cannot serve content and retries on the next request', () async {
    publicationFails = true;
    bridge.start();
    await pumpEventQueue();

    expect(await request(), {'ok': false, 'error': 'unavailable'});
    expect(handler.calls, 0);
    publicationFails = false;

    expect(await request(), {'ok': true, 'threads': []});
    expect(handler.calls, 1);
    expect(attempts.length, greaterThan(1));
  });

  test('failed departure publication is retained and retried without leaking content', () async {
    bridge.start();
    await pumpEventQueue();
    publicationFails = true;
    await auth.changeServer();
    await pumpEventQueue();

    expect(await request(), {'ok': false, 'error': 'signed_out'});
    expect(events.named('watch.session.invalidated').last, {
      'reason': 'signed_out',
      'result': false,
    });
    publicationFails = false;

    expect(await request(), {'ok': false, 'error': 'signed_out'});
    expect(attempts.last, isFalse);
    expect(events.named('watch.session.invalidated').last, {
      'reason': 'signed_out',
      'result': true,
    });
  });
}

class _SessionHandler extends WatchRequestHandler {
  _SessionHandler(this.usable)
    : super(
        repository: () => null,
        transport: () => null,
        activeProfile: () async => null,
      );
  final bool Function() usable;
  int calls = 0;

  @override
  Future<Map<String, Object?>> handle(Map<Object?, Object?> request) async {
    calls++;
    return usable()
        ? {'ok': true, 'threads': []}
        : {'ok': false, 'error': 'signed_out'};
  }
}
