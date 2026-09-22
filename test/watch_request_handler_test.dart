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
      ApprovalRequested(
        const ApprovalRequest(
          requestId: 'r1',
          command: 'ls',
          description: 'list',
          choices: ['once'],
        ),
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
      profile = 'work';

      await handler.handle({'op': 'send', 'text': 'x', 'threadId': 'home/s1'});

      expect(announced, isEmpty);
    });
  });

  group('requests the watch cannot answer', () {
    const bodies = {
      'approval': kApprovalBody,
      'question': kQuestionBody,
      'secret': kNeedsYouBody,
      'sudo': kNeedsYouBody,
    };
    const requests = <String, ChatEvent>{
      'approval': ApprovalRequested(
        ApprovalRequest(
          requestId: 'r1',
          command: 'rm -rf build',
          description: 'delete files',
          choices: ['once', 'deny'],
        ),
      ),
      'question': ClarifyRequested(
        ClarifyRequest(
          requestId: 'r2',
          questions: [ClarifyQuestion(qid: '', question: 'Which branch?')],
        ),
      ),
      'secret': UnsupportedRequested(
        UnsupportedRequest(requestId: 'r3', kind: UnsupportedKind.secret),
      ),
      'sudo': UnsupportedRequested(
        UnsupportedRequest(requestId: 'r4', kind: UnsupportedKind.sudo),
      ),
    };

    for (final MapEntry(:key, :value) in requests.entries) {
      test('ends the send at once on $key', () async {
        final pending = handler.handle({'op': 'send', 'text': 'Hello'});
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
        expect(announced.map((n) => n.body), [bodies[key]]);
      });
    }

    test('does not leak what was asked for', () async {
      final pending = handler.handle({'op': 'send', 'text': 'Hello'});
      await pumpEventQueue();
      transport.sends.single
        ..emit(const ThreadBound('new-1'))
        ..emit(requests['approval']!);

      final text = (await pending)['text']! as String;

      expect(text, isNot(contains('rm -rf')));
      expect(text, isNot(contains('delete files')));
      expect(announced.single.body, isNot(contains('rm -rf')));
    });
  });
}
