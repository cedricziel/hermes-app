import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/watch/watch_bridge.dart';
import 'package:hermes_app/src/watch/watch_request_handler.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const codec = StandardMethodCodec();
  late FakeHermesServer server;
  late WatchBridge bridge;

  /// Calls the bridge the way the iOS runner does and decodes the reply.
  Future<Object?> fromNative(String method, Object? arguments) async {
    final reply = Completer<ByteData?>();
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          WatchBridge.channelName,
          codec.encodeMethodCall(MethodCall(method, arguments)),
          reply.complete,
        );
    final data = await reply.future;
    return data == null ? null : codec.decodeEnvelope(data);
  }

  setUp(() {
    server = FakeHermesServer();
    bridge = WatchBridge(
      handler: WatchRequestHandler(
        repository: () => HermesChatRepository(server.client().raw),
        transport: () => FakeChatTransport(),
        activeProfile: () async => null,
      ),
    )..start();
  });

  tearDown(() => bridge.dispose());

  test(
    'hands a relayed request to the handler and returns its reply',
    () async {
      server.on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 's1', title: 'Groceries')]),
      );

      final result = await fromNative('request', {'op': 'threads'}) as Map;

      expect(result['ok'], isTrue);
      expect((result['threads'] as List).single['id'], 's1');
    },
  );

  test('answers a malformed request instead of throwing', () async {
    final result = await fromNative('request', null) as Map;

    expect(result, {'ok': false, 'error': 'bad_request'});
  });

  test('ignores calls it does not know', () async {
    expect(await fromNative('nope', null), isNull);
  });
}
