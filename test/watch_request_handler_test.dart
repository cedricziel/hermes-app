import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/watch/watch_request_handler.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';

void main() {
  late FakeHermesServer server;
  late FakeChatTransport transport;
  late WatchRequestHandler handler;
  var signedOut = false;
  String? profile;

  setUp(() {
    server = FakeHermesServer();
    transport = FakeChatTransport();
    signedOut = false;
    profile = null;
    handler = WatchRequestHandler(
      repository: () =>
          signedOut ? null : HermesChatRepository(server.client().raw),
      transport: () => signedOut ? null : transport,
      activeProfile: () async => profile,
    );
  });

  test('answers a signed-out phone with signed_out', () async {
    signedOut = true;

    final reply = await handler.handle({'op': 'threads'});

    expect(reply, {'ok': false, 'error': 'signed_out'});
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

      expect((tied['threads'] as List).single['id'], 'a%2Fb%20c/s1');
      expect((untied['threads'] as List).single['id'], '/s1');
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

  group('messages across a profile change', () {
    test('refuses a thread that was listed under another profile', () async {
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

      expect(reply, {'ok': false, 'error': 'bad_request'});
      expect(server.requests, isEmpty);
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
      expect(reply['threadId'], 'work/s1');
      expect(reply['text'], 'Done');
    });

    test('refuses to send into a thread from another profile', () async {
      profile = 'work';

      final reply = await handler.handle({
        'op': 'send',
        'threadId': 'home/s1',
        'text': 'More',
      });

      expect(reply, {'ok': false, 'error': 'bad_request'});
      expect(transport.sends, isEmpty);
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
}
