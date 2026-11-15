import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/auth/verified_session_owner.dart';
import 'package:hermes_app/src/watch/watch_bridge.dart';
import 'package:hermes_app/src/watch/watch_context.dart';
import 'package:hermes_app/src/watch/watch_request_handler.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// The bridge has no App Lock input: the watch has its own lock, so the
/// phone's App Lock cannot gate inline approvals and questions. These tests
/// check that a ready session alone makes requests wanted and answered.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const codec = StandardMethodCodec();
  const channel = MethodChannel(WatchBridge.channelName);

  {
    group('inline requests', () {
      late _ReadyAuth auth;
      late WatchBridge bridge;
      late List<Map<Object?, Object?>> sent;
      late List<bool> accessPublished;

      setUp(() {
        SharedPreferencesAsyncPlatform.instance =
            InMemorySharedPreferencesAsync.empty();
        auth = _ReadyAuth();
        sent = [];
        accessPublished = [];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              final args = call.arguments as Map;
              if (call.method == 'publishSessionState') {
                return {
                  'usable': args['usable'],
                  'revision': args['revision'],
                  'contextId': args['contextId'],
                };
              }
              if (call.method == 'publishRequestAccess') {
                accessPublished.add(args['allowed'] as bool);
                return {
                  'epoch': 1,
                  'allowed': args['allowed'],
                  'contextId': args['contextId'],
                  'revision': args['revision'],
                };
              }
              return null;
            });
        var id = 0;
        bridge = WatchBridge(
          auth: auth,
          requestsEnabled: true,
          contextStore: WatchContextStore(
            read: () async => null,
            write: (_) async {},
            randomId: () => 'ctx${id++}',
          ),
          handler: _Handler(sent),
        )..start();
      });

      tearDown(() {
        bridge.dispose();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      Future<Object?> fromNative(Map<String, Object?> request) async {
        final reply = Completer<ByteData?>();
        unawaited(
          TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
              .handlePlatformMessage(
                WatchBridge.channelName,
                codec.encodeMethodCall(MethodCall('request', request)),
                reply.complete,
              ),
        );
        final data = await reply.future;
        return codec.decodeEnvelope(data!);
      }

      test('wants inline requests and publishes access', () async {
        await fromNative({'op': 'session'});
        expect(bridge.requestsAvailable, isTrue);
        expect(accessPublished.last, isTrue);
      });

      for (final op in ['request_details', 'request_answer']) {
        test('answers $op without a locked error', () async {
          final reply = await fromNative({'op': op, 'requestId': 'r'}) as Map;
          expect(reply['ok'], isTrue);
          expect(reply['error'], isNull);
          expect(sent.single['op'], op);
        });
      }
    });
  }
}

class _ReadyAuth extends AuthController {
  @override
  HermesConnectionState get state => HermesConnectionState.ready;

  @override
  bool get protectedRequestsAllowed => true;

  @override
  int get ownerGeneration => 1;

  @override
  VerifiedSessionOwner? get verifiedOwner => const VerifiedSessionOwner(
    server: 'https://hermes.test',
    user: 'u',
    organization: '',
    provider: 'password',
  );
}

class _Handler extends WatchRequestHandler {
  _Handler(this.sent)
    : super(
        repository: () => null,
        transport: () => null,
        activeProfile: () async => null,
      );

  final List<Map<Object?, Object?>> sent;

  @override
  Future<Map<String, Object?>> handle(Map<Object?, Object?> request) async {
    sent.add(request);
    return {'ok': true};
  }
}
