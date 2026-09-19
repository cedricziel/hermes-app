import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';

import 'support/fake_hermes_server.dart';

void main() {
  late FakeHermesServer server;
  late HermesChatRepository repository;

  setUp(() {
    server = FakeHermesServer();
    repository = HermesChatRepository(server.client().raw);
  });

  group('loadThreads', () {
    test('asks the dashboard for the most recently active sessions', () async {
      server.on('GET', '/api/sessions', sessionListBody([]));

      await repository.loadThreads();

      final request = server.requestsTo('GET', '/api/sessions').single;
      expect(request.queryParameters['order'], 'recent');
    });

    test('lists the sessions of the profile it was asked for', () async {
      server.on('GET', '/api/sessions', sessionListBody([]));

      await repository.loadThreads(profile: 'work');

      final request = server.requestsTo('GET', '/api/sessions').single;
      expect(request.queryParameters['profile'], 'work');
    });

    test('leaves the profile to the dashboard when none is given', () async {
      server.on('GET', '/api/sessions', sessionListBody([]));

      await repository.loadThreads();

      final request = server.requestsTo('GET', '/api/sessions').single;
      expect(request.queryParameters.containsKey('profile'), isFalse);
    });

    test(
      'maps each session row to a thread, keeping the server order',
      () async {
        server.on(
          'GET',
          '/api/sessions',
          sessionListBody([
            sessionRow(id: 's-new', title: 'Newest', lastActive: 1780000600),
            sessionRow(id: 's-old', title: 'Oldest', lastActive: 1780000100),
          ]),
        );

        final threads = await repository.loadThreads();

        expect(threads.map((t) => t.id), ['s-new', 's-old']);
        expect(threads.map((t) => t.title), ['Newest', 'Oldest']);
        expect(
          threads.first.updatedAt,
          DateTime.fromMillisecondsSinceEpoch(1780000600 * 1000),
        );
      },
    );

    test('falls back to the preview when a session has no title', () async {
      server.on(
        'GET',
        '/api/sessions',
        sessionListBody([
          sessionRow(id: 's1', preview: 'What broke at 02:14?'),
        ]),
      );

      final threads = await repository.loadThreads();

      expect(threads.single.title, 'What broke at 02:14?');
    });

    test(
      'titles a session with neither title nor preview "Untitled chat"',
      () async {
        server.on(
          'GET',
          '/api/sessions',
          sessionListBody([sessionRow(id: 's1')]),
        );

        final threads = await repository.loadThreads();

        expect(threads.single.title, 'Untitled chat');
      },
    );

    test('returns threads without messages; those load on demand', () async {
      server.on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 's1', title: 'A')]),
      );

      final threads = await repository.loadThreads();

      expect(threads.single.messages, isEmpty);
      expect(
        server.requests.where((r) => r.path.endsWith('/messages')),
        isEmpty,
      );
    });

    test('surfaces a server error as a DioException', () async {
      server.on('GET', '/api/sessions', {'detail': 'boom'}, status: 500);

      expect(repository.loadThreads(), throwsA(isA<DioException>()));
    });
  });

  group('loadThreadPage', () {
    test('asks for the first page without archived sessions', () async {
      server.on('GET', '/api/sessions', sessionListBody([]));

      await repository.loadThreadPage();

      final query = server
          .requestsTo('GET', '/api/sessions')
          .single
          .queryParameters;
      expect(query['limit'], 50);
      expect(query['offset'], 0);
      expect(query['archived'], 'exclude');
    });

    test('reports whether more sessions follow and where they start', () async {
      server.on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 's1')], total: 120, limit: 1),
      );

      final page = await repository.loadThreadPage(limit: 1);

      expect(page.hasMore, isTrue);
      expect(page.nextOffset, 1);
    });

    test('has no more sessions once the page reaches the total', () async {
      server.on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 's2')], total: 2, limit: 1, offset: 1),
      );

      final page = await repository.loadThreadPage(limit: 1, offset: 1);

      expect(server.requests.single.queryParameters['offset'], 1);
      expect(page.hasMore, isFalse);
    });

    test('marks pinned sessions and every thread as server-backed', () async {
      server.on(
        'GET',
        '/api/sessions',
        sessionListBody([
          sessionRow(id: 's1', pinned: true),
          sessionRow(id: 's2'),
        ]),
      );

      final page = await repository.loadThreadPage();

      expect(page.threads.map((t) => t.pinned), [true, false]);
      expect(page.threads.every((t) => t.remote), isTrue);
    });

    test('guesses from the row count when the total is missing', () async {
      server.on('GET', '/api/sessions', {
        'sessions': [sessionRow(id: 's1'), sessionRow(id: 's2')],
      });

      final page = await repository.loadThreadPage(limit: 2);

      expect(page.hasMore, isTrue);
    });
  });

  group('renameThread', () {
    test('patches the title and returns the stored one', () async {
      server.on(
        'PATCH',
        '/api/sessions/s1',
        sessionPatchBody(title: 'Release notes'),
      );

      final stored = await repository.renameThread('s1', 'Release notes');

      expect(stored, 'Release notes');
      final request = server.requestsTo('PATCH', '/api/sessions/s1').single;
      expect(jsonBody(request), {'title': 'Release notes'});
    });

    test('surfaces a rejected title as a DioException', () async {
      server.on('PATCH', '/api/sessions/s1', {
        'detail': 'Title already in use',
      }, status: 400);

      expect(
        repository.renameThread('s1', 'Taken'),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('setPinned', () {
    for (final pinned in [true, false]) {
      test('patches only the pinned flag to $pinned', () async {
        server.on(
          'PATCH',
          '/api/sessions/s1',
          sessionPatchBody(flags: {'pinned': pinned}),
        );

        await repository.setPinned('s1', pinned);

        final request = server.requestsTo('PATCH', '/api/sessions/s1').single;
        expect(jsonBody(request), {'pinned': pinned});
      });
    }
  });

  group('archiveThread', () {
    test('patches only the archived flag', () async {
      server.on(
        'PATCH',
        '/api/sessions/s1',
        sessionPatchBody(flags: {'archived': true}),
      );

      await repository.archiveThread('s1');

      final request = server.requestsTo('PATCH', '/api/sessions/s1').single;
      expect(jsonBody(request), {'archived': true});
    });

    test('surfaces a missing session as a DioException', () async {
      server.on('PATCH', '/api/sessions/s1', {
        'detail': 'Session not found',
      }, status: 404);

      expect(repository.archiveThread('s1'), throwsA(isA<DioException>()));
    });
  });

  group('deleteThread', () {
    test('deletes the session', () async {
      server.on('DELETE', '/api/sessions/s1', {'ok': true});

      await repository.deleteThread('s1');

      expect(server.requestsTo('DELETE', '/api/sessions/s1'), hasLength(1));
    });

    test('surfaces a server error as a DioException', () async {
      server.on('DELETE', '/api/sessions/s1', {'detail': 'boom'}, status: 500);

      expect(repository.deleteThread('s1'), throwsA(isA<DioException>()));
    });
  });

  group('loadMessages', () {
    Future<List<ChatMessage>> load(List<Map<String, Object?>> rows) {
      server.on(
        'GET',
        '/api/sessions/s1/messages',
        messageListBody('s1', rows),
      );
      return repository.loadMessages('s1');
    }

    test('maps user and assistant rows to chat messages in order', () async {
      final messages = await load([
        messageRow(id: 1, role: 'user', content: 'Why did it fail?'),
        messageRow(id: 2, role: 'assistant', content: 'A reset connection.'),
      ]);

      expect(messages.map((m) => m.role), [ChatRole.user, ChatRole.assistant]);
      expect(messages.map((m) => m.content), [
        'Why did it fail?',
        'A reset connection.',
      ]);
      expect(messages.every((m) => m.status == MessageStatus.sent), isTrue);
    });

    test('gives each message a distinct id derived from its row id', () async {
      final messages = await load([
        messageRow(id: 11, role: 'user', content: 'a'),
        messageRow(id: 12, role: 'assistant', content: 'b'),
      ]);

      expect(messages.map((m) => m.id), ['s1-11', 's1-12']);
    });

    test('reads timestamps as epoch seconds', () async {
      final messages = await load([
        messageRow(id: 1, role: 'user', content: 'a', timestamp: 1780000123.5),
      ]);

      expect(
        messages.single.createdAt,
        DateTime.fromMillisecondsSinceEpoch(1780000123500),
      );
    });

    test('requests the messages of the session it was asked for', () async {
      await load([]);

      expect(
        server.requestsTo('GET', '/api/sessions/s1/messages'),
        hasLength(1),
      );
    });

    test('reads the session from the profile it was asked for', () async {
      server.on('GET', '/api/sessions/s1/messages', messageListBody('s1', []));

      await repository.loadMessages('s1', profile: 'work');

      final request = server
          .requestsTo('GET', '/api/sessions/s1/messages')
          .single;
      expect(request.queryParameters['profile'], 'work');
    });

    test('leaves the profile to the dashboard when none is given', () async {
      await load([]);

      final request = server
          .requestsTo('GET', '/api/sessions/s1/messages')
          .single;
      expect(request.queryParameters.containsKey('profile'), isFalse);
    });

    test('omits system rows from the transcript', () async {
      final messages = await load([
        messageRow(id: 1, role: 'system', content: 'You are Hermes.'),
        messageRow(id: 2, role: 'user', content: 'hi'),
      ]);

      expect(messages.map((m) => m.content), ['hi']);
    });

    test('attaches an assistant turn\'s tool calls to that message', () async {
      final messages = await load([
        messageRow(id: 1, role: 'user', content: 'check the logs'),
        messageRow(
          id: 2,
          role: 'assistant',
          content: 'Looking.',
          toolCalls: [functionCall('search_logs', '{"query":"02:14"}')],
        ),
      ]);

      final call = messages.last.toolCalls.single;
      expect(call.name, 'search_logs');
      expect(call.summary, '{"query":"02:14"}');
      expect(call.status, ToolCallStatus.completed);
    });

    test(
      'folds tool result rows into the call instead of showing them',
      () async {
        final messages = await load([
          messageRow(
            id: 1,
            role: 'assistant',
            toolCalls: [functionCall('search_logs', '{}')],
          ),
          messageRow(
            id: 2,
            role: 'tool',
            toolName: 'search_logs',
            content: '3 matches',
          ),
          messageRow(id: 3, role: 'assistant', content: 'Found 3.'),
        ]);

        expect(messages.map((m) => m.content), ['', 'Found 3.']);
      },
    );

    test(
      'treats a tool-calling turn with null content as empty text',
      () async {
        final messages = await load([
          messageRow(
            id: 1,
            role: 'assistant',
            content: null,
            toolCalls: [functionCall('run_shell', '{"cmd":"ls"}')],
          ),
        ]);

        expect(messages.single.content, isEmpty);
        expect(messages.single.toolCalls.single.name, 'run_shell');
      },
    );

    test('surfaces a missing session as a DioException', () async {
      server.on('GET', '/api/sessions/gone/messages', {
        'detail': 'Session not found',
      }, status: 404);

      expect(repository.loadMessages('gone'), throwsA(isA<DioException>()));
    });
  });
}
