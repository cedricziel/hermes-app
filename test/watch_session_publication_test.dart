import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/watch/watch_bridge.dart';
import 'package:hermes_app/src/watch/watch_context.dart';
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
    final previousHttpOverride = HttpOverrides.current;
    HttpOverrides.global = null;
    addTearDown(() => HttpOverrides.global = previousHttpOverride);
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
    expect(auth.state, HermesConnectionState.ready);
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
          return {
            ...call.arguments as Map,
            'revision': attempts.length,
            'usable': usable,
          };
        });
    handler = _SessionHandler(() => auth.protectedRequestsAllowed);
    String? storedContext;
    final contexts = WatchContextStore(
      read: () async => storedContext,
      write: (value) async {
        storedContext = value;
      },
      randomId: () => 'test-context',
    );
    bridge = WatchBridge(
      handler: handler,
      auth: auth,
      events: events.call,
      contextStore: contexts,
    );
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

  test(
    'failed logout must be published before relogin can enable content',
    () async {
      var nativeUsable = true;
      var nativeRevision = 1;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            final usable = (call.arguments as Map)['usable'] as bool;
            attempts.add(usable);
            if (!usable && publicationFails) {
              throw PlatformException(code: 'publication_failed');
            }
            if (nativeUsable != usable) {
              nativeRevision++;
              nativeUsable = usable;
            }
            return {...call.arguments as Map, 'revision': nativeRevision, 'usable': usable};
          });
      bridge.start();
      await pumpEventQueue();
      publicationFails = true;
      await auth.changeServer();
      await pumpEventQueue();
      await auth.connect('http://127.0.0.1:${server.port}');
      await pumpEventQueue();

      expect(await request(), {'ok': false, 'error': 'unavailable'});
      expect(handler.calls, 0);
      expect(attempts.where((usable) => usable), [true]);
      expect(nativeRevision, 1);
      publicationFails = false;

      expect(await request(), {'ok': true, 'threads': []});
      expect(attempts.sublist(attempts.length - 2), [false, true]);
      expect(nativeRevision, 3);
      expect(nativeUsable, isTrue);
    },
  );

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
