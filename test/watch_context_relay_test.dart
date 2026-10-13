import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/watch/watch_context.dart';
import 'package:hermes_app/src/watch/watch_request_handler.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';

import 'support/fake_hermes_server.dart';
import 'support/fake_chat_transport.dart';

void main() {
  test('session handshake returns no content and legacy requests fail before access', () async {
    final server = FakeHermesServer();
    final handler = WatchRequestHandler(
      repository: () => HermesChatRepository(server.client().raw),
      transport: () => FakeChatTransport(),
      activeProfile: () async => null,
      context: () => const WatchContext('owner-a', 7),
    );
    expect(await handler.handle({'op': 'session'}), {
      'ok': true,
      'protocolVersion': 2,
      'contextId': 'owner-a',
      'revision': 7,
    });
    expect(await handler.handle({'op': 'threads'}), {
      'ok': false,
      'error': 'context_changed',
    });
    expect(
      await handler.handle({
        'op': 'messages',
        'threadId': 'default/s1',
        'contextId': 'owner-a',
        'revision': 7,
      }),
      {'ok': false, 'error': 'context_changed'},
    );
    expect(server.requests, isEmpty);
  });
  test('new chat and transcription reject prior owner before transport or recognizer', () async {
    final server = FakeHermesServer();
    final transport = FakeChatTransport();
    var recognized = false;
    final handler = WatchRequestHandler(
      repository: () => HermesChatRepository(server.client().raw),
      transport: () => transport,
      activeProfile: () async => null,
      context: () => const WatchContext('owner-b', 8),
      transcribeOnDevice: (_) async {
        recognized = true;
        return 'speech';
      },
    );
    expect(
      await handler.handle({
        'op': 'send',
        'text': 'Hi',
        'contextId': 'owner-a',
        'revision': 7,
      }),
      {'ok': false, 'error': 'context_changed'},
    );
    expect(
      await handler.handle({
        'op': 'transcribe',
        'audio': Uint8List.fromList([1]),
        'mimeType': 'audio/mp4',
        'contextId': 'owner-a',
        'revision': 7,
      }),
      {'ok': false, 'error': 'context_changed'},
    );
    expect(transport.sends, isEmpty);
    expect(recognized, isFalse);
  });
}
