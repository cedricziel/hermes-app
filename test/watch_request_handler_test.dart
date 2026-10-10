import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/notifications/attention_policy.dart';
import 'package:hermes_app/src/watch/watch_request_handler.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';

void main() {
  late FakeHermesServer server;
  late FakeChatTransport transport;
  late WatchRequestHandler handler;
  late List<AttentionNotification> announced;
  var signedOut = false;
  var connecting = false;
  String? profile;

  setUp(() {
    server = FakeHermesServer();
    transport = FakeChatTransport();
    signedOut = false;
    connecting = false;
    profile = null;
    announced = [];
    handler = WatchRequestHandler(
      repository: () =>
          signedOut ? null : HermesChatRepository(server.client().raw),
      transport: () => signedOut ? null : transport,
      activeProfile: () async => profile,
      connecting: () => connecting,
      announce: announced.add,
    );
  });

  test('answers a signed-out phone with signed_out', () async {
    signedOut = true;

    final reply = await handler.handle({'op': 'threads'});

    expect(reply, {'ok': false, 'error': 'signed_out'});
  });

  test('answers a phone that is still connecting with unavailable', () async {
    signedOut = true;
    connecting = true;

    for (final request in [
      {'op': 'threads'},
      {'op': 'messages', 'threadId': '/s1'},
      {'op': 'send', 'text': 'Hi'},
    ]) {
      expect(await handler.handle(request), {
        'ok': false,
        'error': 'unavailable',
      });
    }
  });

  test('leaves threadId out of a reply that has no thread', () async {
    final pending = handler.handle({'op': 'send', 'text': 'Hello'});
    await pumpEventQueue();
    transport.sends.single.emit(
      const UnsupportedRequested(
        UnsupportedRequest(requestId: 'r1', kind: UnsupportedKind.sudo),
      ),
    );

    final reply = await pending;

    expect(reply['ok'], isTrue);
    expect(reply.containsKey('threadId'), isFalse);
    expect(announced, isEmpty);
  });

  test('rejects an unknown op and a malformed request', () async {
    expect(await handler.handle({'op': 'nope'}), {
      'ok': false,
      'error': 'bad_request',
    });
    expect(await handler.handle({'op': 'messages'}), {
      'ok': false,
      'error': 'bad_request',
    });
    expect(await handler.handle({'op': 'send', 'text': '  '}), {
      'ok': false,
      'error': 'bad_request',
    });
    expect(await handler.handle({}), {'ok': false, 'error': 'bad_request'});
  });

  test('rejects a thread id that carries no profile', () async {
    for (final threadId in ['s1', '', '/', 'work/', '%zz/s1']) {
      expect(await handler.handle({'op': 'messages', 'threadId': threadId}), {
        'ok': false,
        'error': 'bad_request',
      }, reason: 'messages with "$threadId"');
      expect(
        await handler.handle({
          'op': 'send',
          'threadId': threadId,
          'text': 'Hi',
        }),
        {'ok': false, 'error': 'bad_request'},
        reason: 'send with "$threadId"',
      );
    }
    expect(transport.sends, isEmpty);
    expect(server.requests, isEmpty);
  });

  group('threads', () {
    test('lists recent threads as plain values', () async {
      profile = 'work';
      server.on(
        'GET',
        '/api/sessions',
        sessionListBody([
          sessionRow(
            id: 's1',
            title: 'Groceries',
            lastActive: 1780000600,
            pinned: true,
          ),
          sessionRow(
            id: 's2',
            preview: 'Plan the trip',
            lastActive: 1780000100,
          ),
        ]),
      );

      final reply = await handler.handle({'op': 'threads'});

      expect(reply, {
        'ok': true,
        'threads': [
          {
            'id': 'work/s1',
            'title': 'Groceries',
            'updatedAt': 1780000600,
            'pinned': true,
          },
          {
            'id': 'work/s2',
            'title': 'Plan the trip',
            'updatedAt': 1780000100,
            'pinned': false,
          },
        ],
      });
    });

    test('asks for a small page in the active profile', () async {
      profile = 'work';
      server.on('GET', '/api/sessions', sessionListBody([]));

      await handler.handle({'op': 'threads'});

      final request = server.requestsTo('GET', '/api/sessions').single;
      expect(request.queryParameters['limit'], 20);
      expect(request.queryParameters['profile'], 'work');
    });

    test('never lists more than the limit, even when the server adds '
        'pinned threads', () async {
      server.on(
        'GET',
        '/api/sessions',
        sessionListBody([
          for (var i = 0; i < 25; i++) sessionRow(id: 's$i', title: 'T$i'),
        ]),
      );

      final reply = await handler.handle({'op': 'threads'});

      expect(reply['threads'], hasLength(WatchRequestHandler.threadLimit));
    });

    test('ties each thread to the profile it was listed in', () async {
      server.on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 's1', title: 'A')]),
      );

      profile = 'a/b c';
      final tied = await handler.handle({'op': 'threads'});
      profile = null;
      final untied = await handler.handle({'op': 'threads'});

      expect(
        ((tied['threads'] as List).single as Map<String, Object?>)['id'],
        'a%2Fb%20c/s1',
      );
      expect(
        ((untied['threads'] as List).single as Map<String, Object?>)['id'],
        '/s1',
      );
    });

    test('reports a failed request as failed', () async {
      server.on('GET', '/api/sessions', {'detail': 'boom'}, status: 500);

      expect(await handler.handle({'op': 'threads'}), {
        'ok': false,
        'error': 'failed',
      });
    });
  });

  group('messages', () {
    test('returns the latest messages with role and text', () async {
      profile = 'work';
      server.on(
        'GET',
        '/api/sessions/s1/messages',
        messageListBody('s1', [
          messageRow(id: 1, role: 'user', content: 'Hi', timestamp: 1780000001),
          messageRow(
            id: 2,
            role: 'assistant',
            content: 'Hello',
            timestamp: 1780000002,
          ),
        ]),
      );

      final reply = await handler.handle({
        'op': 'messages',
        'threadId': 'work/s1',
      });

      expect(reply, {
        'ok': true,
        'messages': [
          {'id': 's1-1', 'role': 'user', 'content': 'Hi', 'at': 1780000001},
          {
            'id': 's1-2',
            'role': 'assistant',
            'content': 'Hello',
            'at': 1780000002,
          },
        ],
      });
      final request = server
          .requestsTo('GET', '/api/sessions/s1/messages')
          .single;
      expect(request.queryParameters['profile'], 'work');
    });

    test('shows the text of a turn that used tools and skips rows without '
        'any', () async {
      server.on(
        'GET',
        '/api/sessions/s1/messages',
        messageListBody('s1', [
          messageRow(id: 1, role: 'user', content: 'What is here?'),
          messageRow(
            id: 2,
            role: 'assistant',
            content: 'Let me look.',
            toolCalls: [functionCall('terminal', '{"command":"ls"}')],
          ),
          messageRow(
            id: 3,
            role: 'tool',
            toolCallId: 'call_terminal',
            content: 'a.txt',
          ),
          messageRow(
            id: 4,
            role: 'assistant',
            content: '',
            toolCalls: [functionCall('read_file', '{"path":"a.txt"}')],
          ),
          messageRow(id: 5, role: 'assistant', content: 'One file, a.txt.'),
        ]),
      );

      final reply = await handler.handle({'op': 'messages', 'threadId': '/s1'});

      final messages = (reply['messages']! as List).cast<Map>();
      expect(
        [for (final m in messages) m['content']],
        ['What is here?', 'Let me look.', 'One file, a.txt.'],
      );
    });

    test('names the tools a reply used before it, once each', () async {
      server.on(
        'GET',
        '/api/sessions/s1/messages',
        messageListBody('s1', [
          messageRow(id: 1, role: 'user', content: 'What is here?'),
          messageRow(
            id: 2,
            role: 'assistant',
            content: 'Let me look.',
            toolCalls: [functionCall('terminal', '{"command":"ls"}')],
          ),
          messageRow(
            id: 3,
            role: 'assistant',
            content: '',
            toolCalls: [
              functionCall('read_file', '{"path":"a.txt"}'),
              functionCall('terminal', '{"command":"wc a.txt"}'),
            ],
          ),
          messageRow(id: 4, role: 'assistant', content: 'One file, a.txt.'),
          messageRow(id: 5, role: 'user', content: 'Thanks'),
          messageRow(id: 6, role: 'assistant', content: 'Any time.'),
        ]),
      );

      final reply = await handler.handle({'op': 'messages', 'threadId': '/s1'});

      final messages = (reply['messages']! as List).cast<Map>();
      expect(
        [for (final m in messages) m['tools']],
        [
          null,
          null,
          ['terminal', 'read_file'],
          null,
          null,
        ],
      );
    });

    test('keeps only the last messages and cuts very long ones', () async {
      server.on(
        'GET',
        '/api/sessions/s1/messages',
        messageListBody('s1', [
          for (var i = 1; i <= 30; i++)
            messageRow(
              id: i,
              role: 'assistant',
              content: i == 30 ? 'x' * 5000 : 'm$i',
            ),
        ]),
      );

      final reply = await handler.handle({'op': 'messages', 'threadId': '/s1'});

      final messages = (reply['messages']! as List).cast<Map>();
      expect(messages, hasLength(20));
      expect(messages.first['id'], 's1-11');
      expect((messages.last['content'] as String).length, lessThan(4100));
    });
  });

  group('messages after a profile switch', () {
    test('reads a thread in the profile it was listed under', () async {
      profile = 'work';
      server.on(
        'GET',
        '/api/sessions/s1/messages',
        messageListBody('s1', [messageRow(id: 1, role: 'user', content: 'Hi')]),
      );

      final reply = await handler.handle({
        'op': 'messages',
        'threadId': 'home/s1',
      });

      expect(reply['ok'], isTrue);
      final request = server
          .requestsTo('GET', '/api/sessions/s1/messages')
          .single;
      expect(request.queryParameters['profile'], 'home');
    });

    test('reads a thread listed without a profile unscoped', () async {
      profile = 'work';
      server.on(
        'GET',
        '/api/sessions/s1/messages',
        messageListBody('s1', [messageRow(id: 1, role: 'user', content: 'Hi')]),
      );

      await handler.handle({'op': 'messages', 'threadId': '/s1'});

      final request = server
          .requestsTo('GET', '/api/sessions/s1/messages')
          .single;
      expect(request.queryParameters, isNot(contains('profile')));
    });
  });

  group('transcribe', () {
    final audio = Uint8List.fromList([1, 2, 3]);

    test('returns what the dashboard heard in the recording', () async {
      profile = 'work';
      server.on('POST', '/api/audio/transcribe', {
        'ok': true,
        'transcript': 'Remind me to call Sam',
      });

      final reply = await handler.handle({
        'op': 'transcribe',
        'audio': audio,
        'mimeType': 'audio/mp4',
      });

      expect(reply, {
        'ok': true,
        'text': 'Remind me to call Sam',
        'engine': 'hermes',
      });
      final request = server.requestsTo('POST', '/api/audio/transcribe').single;
      expect(request.queryParameters['profile'], 'work');
      expect(jsonDecode(request.data as String), {
        'data_url': 'data:audio/mp4;base64,${base64Encode(audio)}',
        'mime_type': 'audio/mp4',
      });
    });

    test("waits as long for the server as the phone's dictation", () async {
      server.on('POST', '/api/audio/transcribe', {
        'ok': true,
        'transcript': 'Hi',
      });

      await handler.handle({
        'op': 'transcribe',
        'audio': audio,
        'mimeType': 'audio/mp4',
      });

      final request = server.requestsTo('POST', '/api/audio/transcribe').single;
      expect(
        request.extra.values.whereType<Duration>().single,
        HermesChatRepository.transcribeTimeout(audio.length),
      );
    });

    test('returns empty text when no speech was heard', () async {
      server.on('POST', '/api/audio/transcribe', {
        'ok': true,
        'transcript': '',
      });

      final reply = await handler.handle({
        'op': 'transcribe',
        'audio': audio,
        'mimeType': 'audio/mp4',
      });

      expect(reply, {'ok': true, 'text': '', 'engine': 'hermes'});
    });

    test('refuses a request without audio', () async {
      final reply = await handler.handle({'op': 'transcribe'});

      expect(reply, {'ok': false, 'error': 'bad_request'});
      expect(server.requests, isEmpty);
    });

    test('answers a signed-out phone with signed_out', () async {
      signedOut = true;

      final reply = await handler.handle({
        'op': 'transcribe',
        'audio': audio,
        'mimeType': 'audio/mp4',
      });

      expect(reply, {'ok': false, 'error': 'signed_out'});
    });

    test('reports a failed transcription', () async {
      server.on('POST', '/api/audio/transcribe', {
        'detail': 'No STT provider',
      }, status: 400);

      final reply = await handler.handle({
        'op': 'transcribe',
        'audio': audio,
        'mimeType': 'audio/mp4',
      });

      expect(reply, {'ok': false, 'error': 'failed'});
    });

    group('on the device', () {
      late List<Uint8List> heard;
      late Future<String?> Function() answer;

      setUp(() {
        heard = [];
        answer = () async => 'Remind me to call Sam';
        handler = WatchRequestHandler(
          repository: () =>
              signedOut ? null : HermesChatRepository(server.client().raw),
          transport: () => transport,
          activeProfile: () async => profile,
          transcribeOnDevice: (audio) {
            heard.add(audio);
            return answer();
          },
        );
      });

      Future<Map<String, Object?>> transcribe() => handler.handle({
        'op': 'transcribe',
        'audio': audio,
        'mimeType': 'audio/mp4',
      });

      test('returns what the phone heard without asking the server', () async {
        expect(await transcribe(), {
          'ok': true,
          'text': 'Remind me to call Sam',
          'engine': 'device',
        });
        expect(heard, [audio]);
        expect(server.requests, isEmpty);
      });

      test('returns empty text when the phone heard no speech', () async {
        answer = () async => '';

        expect(await transcribe(), {
          'ok': true,
          'text': '',
          'engine': 'device',
        });
        expect(server.requests, isEmpty);
      });

      for (final (name, fails) in [
        ('declines', () async => null),
        ('fails', () async => throw StateError('modelMissing')),
      ]) {
        test(
          'sends the recording to the server when the phone $name',
          () async {
            answer = fails;
            server.on('POST', '/api/audio/transcribe', {
              'ok': true,
              'transcript': 'Remind me to call Sam',
            });

            expect(await transcribe(), {
              'ok': true,
              'text': 'Remind me to call Sam',
              'engine': 'hermes',
            });
          },
        );
      }

      test('answers a signed-out phone with signed_out', () async {
        signedOut = true;

        expect(await transcribe(), {'ok': false, 'error': 'signed_out'});
        expect(heard, isEmpty);
      });
    });
  });

  group('send retried with the same id', () {
    test('joins the send still running instead of sending again', () async {
      final first = handler.handle({
        'op': 'send',
        'text': 'Hello',
        'sendId': 'a',
      });
      await pumpEventQueue();
      final retry = handler.handle({
        'op': 'send',
        'text': 'Hello',
        'sendId': 'a',
      });
      await pumpEventQueue();
      transport.sends.single
        ..emit(const ThreadBound('new-1'))
        ..emit(const ReplyCompleted('Hi there'))
        ..finish();

      final expected = {
        'ok': true,
        'threadId': '/new-1',
        'text': 'Hi there',
        'failed': false,
      };
      expect(await first, expected);
      expect(await retry, expected);
      expect(transport.sends, hasLength(1));
    });

    test('answers again with a reply the watch never got', () async {
      final first = handler.handle({
        'op': 'send',
        'text': 'Hello',
        'sendId': 'a',
      });
      await pumpEventQueue();
      transport.sends.single
        ..emit(const ThreadBound('new-1'))
        ..emit(const ReplyCompleted('Hi there'))
        ..finish();
      await first;

      final retry = await handler.handle({
        'op': 'send',
        'text': 'Hello',
        'sendId': 'a',
      });

      expect(retry['text'], 'Hi there');
      expect(transport.sends, hasLength(1));
    });

    test('reads the chat instead of sending again once Hermes had the '
        'prompt', () async {
      server.on(
        'GET',
        '/api/sessions/new-1/messages',
        messageListBody('new-1', [
          messageRow(id: 1, role: 'user', content: 'Hello'),
          messageRow(id: 2, role: 'assistant', content: 'Hi there'),
        ]),
      );
      final first = handler.handle({
        'op': 'send',
        'text': 'Hello',
        'sendId': 'a',
      });
      await pumpEventQueue();
      transport.sends.single
        ..emit(const ThreadBound('new-1'))
        ..fail();
      expect(await first, {'ok': false, 'error': 'failed'});

      final retry = await handler.handle({
        'op': 'send',
        'text': 'Hello',
        'sendId': 'a',
      });

      expect(retry, {
        'ok': true,
        'threadId': '/new-1',
        'text': 'Hi there',
        'failed': false,
      });
      expect(transport.sends, hasLength(1));
    });

    test('says Hermes is still replying when the chat has no answer '
        'yet', () async {
      server.on(
        'GET',
        '/api/sessions/new-1/messages',
        messageListBody('new-1', [
          messageRow(id: 1, role: 'user', content: 'Hello'),
        ]),
      );
      final first = handler.handle({
        'op': 'send',
        'text': 'Hello',
        'sendId': 'a',
      });
      await pumpEventQueue();
      transport.sends.single
        ..emit(const ThreadBound('new-1'))
        ..fail();
      await first;

      final retry = await handler.handle({
        'op': 'send',
        'text': 'Hello',
        'sendId': 'a',
      });

      expect(retry['text'], WatchRequestHandler.stillReplyingText);
      expect(retry['threadId'], '/new-1');
      expect(transport.sends, hasLength(1));
    });

    test('sends again when the first try never reached Hermes', () async {
      final first = handler.handle({
        'op': 'send',
        'text': 'Hello',
        'sendId': 'a',
      });
      await pumpEventQueue();
      transport.sends.single.fail();
      expect(await first, {'ok': false, 'error': 'failed'});

      final retry = handler.handle({
        'op': 'send',
        'text': 'Hello',
        'sendId': 'a',
      });
      await pumpEventQueue();

      expect(transport.sends, hasLength(2));
      transport.sends.last
        ..emit(const ThreadBound('new-1'))
        ..emit(const ReplyCompleted('Hi'))
        ..finish();
      expect((await retry)['text'], 'Hi');
    });

    test('sends a message with another id again', () async {
      for (final id in ['a', 'b']) {
        final pending = handler.handle({
          'op': 'send',
          'text': 'Hello',
          'sendId': id,
        });
        await pumpEventQueue();
        transport.sends.last
          ..emit(const ThreadBound('new-1'))
          ..emit(const ReplyCompleted('Hi'))
          ..finish();
        await pending;
      }

      expect(transport.sends, hasLength(2));
    });
  });

  group('send', () {
    test('starts a thread and returns the final reply', () async {
      final pending = handler.handle({'op': 'send', 'text': 'Hello'});
      await pumpEventQueue();
      final send = transport.sends.single;
      expect(send.threadId, isNull);
      expect(send.text, 'Hello');
      send
        ..emit(const ThreadBound('new-1'))
        ..emit(const ReplyStarted())
        ..emit(const ReplyDelta('Hi'))
        ..emit(const ReplyCompleted('Hi there'))
        ..finish();

      expect(await pending, {
        'ok': true,
        'threadId': '/new-1',
        'text': 'Hi there',
        'failed': false,
      });
      expect(transport.closed, isTrue);
    });

    test('names the tools the reply used', () async {
      final pending = handler.handle({'op': 'send', 'text': 'Hello'});
      await pumpEventQueue();
      transport.sends.single
        ..emit(const ThreadBound('new-1'))
        ..emit(const ToolStarted(name: 'terminal'))
        ..emit(const ToolStarted(name: 'read_file'))
        ..emit(const ToolStarted(name: 'terminal'))
        ..emit(const ReplyCompleted('Done'))
        ..finish();

      expect((await pending)['tools'], ['terminal', 'read_file']);
    });

    test('says so when a successful reply has no text', () async {
      final pending = handler.handle({'op': 'send', 'text': 'Hello'});
      await pumpEventQueue();
      transport.sends.single
        ..emit(const ThreadBound('new-1'))
        ..emit(const ReplyCompleted('  \n'))
        ..finish();

      expect(await pending, {
        'ok': true,
        'threadId': '/new-1',
        'text': WatchRequestHandler.emptyReplyText,
        'failed': false,
      });
    });

    test(
      'falls back to the streamed text when the final text is empty',
      () async {
        final pending = handler.handle({'op': 'send', 'text': 'Hello'});
        await pumpEventQueue();
        transport.sends.single
          ..emit(const ThreadBound('new-1'))
          ..emit(const ReplyDelta('Hi '))
          ..emit(const ReplyDelta('there'))
          ..emit(const ReplyCompleted(''))
          ..finish();

        expect((await pending)['text'], 'Hi there');
      },
    );

    test('starts a thread in the active profile', () async {
      profile = 'work';
      final pending = handler.handle({'op': 'send', 'text': 'Hello'});
      await pumpEventQueue();
      transport.sends.single
        ..emit(const ReplyCompleted('Hi'))
        ..finish();
      await pending;

      expect(transport.sends.single.profile, 'work');
    });

    test('replies into an existing thread', () async {
      profile = 'work';
      final pending = handler.handle({
        'op': 'send',
        'threadId': 'work/s1',
        'text': 'More',
      });
      await pumpEventQueue();
      transport.sends.single
        ..emit(const ReplyCompleted('Done'))
        ..finish();

      final reply = await pending;

      expect(transport.sends.single.threadId, 's1');
      expect(transport.sends.single.profile, 'work');
      expect(reply['threadId'], 'work/s1');
      expect(reply['text'], 'Done');
    });

    test('sends into a thread in the profile it was listed under', () async {
      profile = 'work';

      final pending = handler.handle({
        'op': 'send',
        'threadId': 'home/s1',
        'text': 'More',
      });
      await pumpEventQueue();
      transport.sends.single
        ..emit(const ReplyCompleted('Done'))
        ..finish();
      final reply = await pending;

      expect(transport.sends.single.profile, 'home');
      expect(reply['threadId'], 'home/s1');
    });

    test('gives up on a reply that never comes', () async {
      handler = WatchRequestHandler(
        repository: () => HermesChatRepository(server.client().raw),
        transport: () => transport,
        activeProfile: () async => profile,
        sendTimeout: const Duration(milliseconds: 20),
      );

      final reply = await handler.handle({'op': 'send', 'text': 'Hello'});

      expect(reply, {'ok': false, 'error': 'failed'});
      expect(transport.closed, isTrue);
    });

    test('passes a failed turn on with its message', () async {
      final pending = handler.handle({'op': 'send', 'text': 'Hello'});
      await pumpEventQueue();
      transport.sends.single
        ..emit(const ReplyCompleted('Model unavailable', failed: true))
        ..finish();

      expect((await pending)['failed'], isTrue);
      expect((await pending)['text'], 'Model unavailable');
    });

    test('reports a dropped connection as failed', () async {
      final pending = handler.handle({'op': 'send', 'text': 'Hello'});
      await pumpEventQueue();
      transport.sends.single.fail();

      expect(await pending, {'ok': false, 'error': 'failed'});
      expect(transport.closed, isTrue);
    });

    test('reports a stream that ends without a reply as failed', () async {
      final pending = handler.handle({'op': 'send', 'text': 'Hello'});
      await pumpEventQueue();
      transport.sends.single.finish();

      expect(await pending, {'ok': false, 'error': 'failed'});
    });
  });

  group('announcing a turn', () {
    Future<Map<String, Object?>> send(
      void Function(FakeSend send) play, {
      String? threadId,
    }) async {
      final pending = handler.handle({
        'op': 'send',
        'text': 'Hello',
        'threadId': ?threadId,
      });
      await pumpEventQueue();
      play(transport.sends.single);
      return pending;
    }

    test(
      'announces a completed reply with a preview and the profile',
      () async {
        profile = 'work';

        await send(
          (s) => s
            ..emit(const ThreadBound('new-1'))
            ..emit(const ReplyCompleted('Done.\n\nTwo files changed.'))
            ..finish(),
        );

        expect(announced, hasLength(1));
        expect(announced.single.threadId, 'new-1');
        expect(announced.single.profile, 'work');
        expect(announced.single.title, 'Hermes');
        expect(announced.single.body, 'Done. Two files changed.');
      },
    );

    test('titles the notification with the name the gateway gave', () async {
      await send(
        (s) => s
          ..emit(const ThreadBound('new-1'))
          ..emit(const ThreadTitled('Groceries'))
          ..emit(const ReplyCompleted('Done'))
          ..finish(),
      );

      expect(announced.single.title, 'Groceries');
    });

    test(
      'announces a reply into an existing thread by its session id',
      () async {
        profile = 'work';

        await send(
          (s) => s
            ..emit(const ReplyCompleted('Done'))
            ..finish(),
          threadId: 'work/s1',
        );

        expect(announced.single.threadId, 's1');
        expect(announced.single.profile, 'work');
      },
    );

    test('says a failed reply failed, without its error text', () async {
      await send(
        (s) => s
          ..emit(const ThreadBound('new-1'))
          ..emit(const ReplyCompleted('Traceback: secret detail', failed: true))
          ..finish(),
      );

      expect(announced.single.body, kReplyFailedBody);
    });

    test('announces a broken connection as a failed reply', () async {
      await send(
        (s) => s
          ..emit(const ThreadBound('new-1'))
          ..fail(),
      );

      expect(announced.single.body, kReplyFailedBody);
      expect(announced.single.threadId, 'new-1');
    });

    test('announces a stream that ends without a reply as failed', () async {
      await send(
        (s) => s
          ..emit(const ThreadBound('new-1'))
          ..finish(),
      );

      expect(announced.single.body, kReplyFailedBody);
    });

    test('announces a reply that never comes as failed', () async {
      handler = WatchRequestHandler(
        repository: () => HermesChatRepository(server.client().raw),
        transport: () => transport,
        activeProfile: () async => profile,
        sendTimeout: const Duration(milliseconds: 20),
        announce: announced.add,
      );

      final pending = handler.handle({
        'op': 'send',
        'text': 'Hello',
        'threadId': '/s1',
      });
      await pumpEventQueue();
      await pending;

      expect(announced.single.body, kReplyFailedBody);
      expect(announced.single.threadId, 's1');
    });

    test(
      'announces nothing when the turn breaks before a thread exists',
      () async {
        await send((s) => s.fail());

        expect(announced, isEmpty);
      },
    );

    test('announces nothing for a turn that was refused', () async {
      await handler.handle({'op': 'send', 'text': 'x', 'threadId': 'no-slash'});

      expect(announced, isEmpty);
    });
  });

  group('requests the watch cannot answer', () {
    const requests = <String, ChatEvent>{
      'secret': UnsupportedRequested(
        UnsupportedRequest(requestId: 'r3', kind: UnsupportedKind.secret),
      ),
      'sudo': UnsupportedRequested(
        UnsupportedRequest(requestId: 'r4', kind: UnsupportedKind.sudo),
      ),
      'vault': VaultRequested(
        VaultRequest(requestId: 'r5', kind: VaultKind.saveLogin),
      ),
    };

    for (final MapEntry(:key, :value) in requests.entries) {
      test('ends the send at once on $key', () async {
        final pending = handler.handle({
          'op': 'send',
          'text': 'Hello',
          'sendId': 'a',
        });
        await pumpEventQueue();
        transport.sends.single
          ..emit(const ThreadBound('new-1'))
          ..emit(const ReplyStarted())
          ..emit(value);

        final reply = await pending;

        expect(reply, {
          'ok': true,
          'threadId': '/new-1',
          'text':
              "Hermes asked for something the watch can't answer. "
              'Ask again on your iPhone.',
          'failed': false,
        });
        expect(transport.closed, isTrue);
        expect(announced.map((n) => n.body), [kNeedsYouBody]);
      });
    }
  });

  group('waiting on the user', () {
    const approval = ApprovalRequested(
      ApprovalRequest(
        requestId: 'r1',
        command: 'rm -rf build',
        description: 'delete files',
        choices: ['once', 'deny'],
      ),
    );
    const question = ClarifyRequested(
      ClarifyRequest(
        requestId: 'r2',
        batch: true,
        questions: [ClarifyQuestion(qid: 'q1', question: 'Which branch?')],
      ),
    );

    Future<Map<String, Object?>> send() =>
        handler.handle({'op': 'send', 'text': 'Hello', 'sendId': 'a'});

    void useHandler({
      Duration sendTimeout = const Duration(seconds: 60),
      Duration waitingTimeout = const Duration(minutes: 15),
      Duration hold = const Duration(seconds: 20),
    }) {
      handler = WatchRequestHandler(
        repository: () => HermesChatRepository(server.client().raw),
        transport: () => transport,
        activeProfile: () async => profile,
        announce: announced.add,
        sendTimeout: sendTimeout,
        waitingTimeout: waitingTimeout,
        waitingHold: hold,
      );
    }

    for (final (kind, event, body) in [
      ('approval', approval as ChatEvent, 'rm -rf build'),
      ('question', question as ChatEvent, 'Which branch?'),
    ]) {
      test('answers that the send waits on $kind, and keeps it', () async {
        final pending = send();
        await pumpEventQueue();
        transport.sends.single
          ..emit(const ThreadBound('new-1'))
          ..emit(const ReplyStarted())
          ..emit(event);

        expect(await pending, {
          'ok': true,
          'threadId': '/new-1',
          'waiting': kind,
        });
        expect(transport.closed, isFalse);
        expect(announced.single.body, body);
        expect(announced.single.category, isNotNull);
      });
    }

    test(
      'waits on a request of the turn Hermes ran ahead of the prompt',
      () async {
        final pending = send();
        await pumpEventQueue();
        transport.sends.single
          ..emit(const ThreadBound('new-1'))
          ..emit(const UnsolicitedEvent(ReplyStarted()))
          ..emit(const UnsolicitedEvent(approval));

        expect((await pending)['waiting'], 'approval');
      },
    );

    test('a retry gets the reply once the turn is over', () async {
      final first = send();
      await pumpEventQueue();
      final turn = transport.sends.single
        ..emit(const ThreadBound('new-1'))
        ..emit(approval);
      await first;

      final retry = send();
      await pumpEventQueue();
      turn.emit(const ReplyCompleted('Done.'));

      expect(await retry, {
        'ok': true,
        'threadId': '/new-1',
        'text': 'Done.',
        'failed': false,
      });
      expect(transport.sends, hasLength(1));
    });

    test('a retry answers again after the hold while it still waits', () async {
      useHandler(hold: const Duration(milliseconds: 20));
      final first = send();
      await pumpEventQueue();
      transport.sends.single
        ..emit(const ThreadBound('new-1'))
        ..emit(approval);
      await first;

      expect(await send(), {
        'ok': true,
        'threadId': '/new-1',
        'waiting': 'approval',
      });
    });

    test('a retry says Hermes is working once the turn went on', () async {
      useHandler(hold: const Duration(milliseconds: 20));
      final first = send();
      await pumpEventQueue();
      final turn = transport.sends.single
        ..emit(const ThreadBound('new-1'))
        ..emit(approval);
      await first;

      final retry = send();
      await pumpEventQueue();
      turn.emit(const ReplyDelta('Deleting…'));

      expect((await retry)['waiting'], 'working');
    });

    test('gives up later while it waits', () async {
      useHandler(
        sendTimeout: const Duration(milliseconds: 20),
        waitingTimeout: const Duration(seconds: 5),
      );
      final first = send();
      await pumpEventQueue();
      final turn = transport.sends.single
        ..emit(const ThreadBound('new-1'))
        ..emit(approval);
      await first;
      final retry = send();

      await Future<void>.delayed(const Duration(milliseconds: 60));
      turn.emit(const ReplyCompleted('Done.'));

      expect((await retry)['text'], 'Done.');
    });

    test(
      'a retry the phone has forgotten reads the chat instead of sending',
      () async {
        server.on(
          'GET',
          '/api/sessions/new-1/messages',
          messageListBody('new-1', [
            messageRow(id: 1, role: 'user', content: 'Clean up'),
            messageRow(id: 2, role: 'assistant', content: 'Done.'),
          ]),
        );

        final reply = await handler.handle({
          'op': 'send',
          'text': 'Clean up',
          'sendId': 'gone',
          'threadId': '/new-1',
          'retry': true,
        });

        expect(reply, {
          'ok': true,
          'threadId': '/new-1',
          'text': 'Done.',
          'failed': false,
        });
        expect(transport.sends, isEmpty);
      },
    );

    test('a forgotten retry without a chat is not sent again', () async {
      final reply = await handler.handle({
        'op': 'send',
        'text': 'Clean up',
        'sendId': 'gone',
        'retry': true,
      });

      expect(reply, {'ok': false, 'error': 'failed'});
      expect(transport.sends, isEmpty);
    });

    test('does not pass on what was asked for', () async {
      final pending = send();
      await pumpEventQueue();
      transport.sends.single
        ..emit(const ThreadBound('new-1'))
        ..emit(approval);

      final reply = await pending;

      expect(reply.values.join(), isNot(contains('rm -rf')));
      expect(reply.values.join(), isNot(contains('delete files')));
    });
  });
}
