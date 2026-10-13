import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';

import 'support/fake_hermes_server.dart';

void main() {
  late FakeHermesServer server;
  late HermesChatRepository repository;
  setUp(() {
    server = FakeHermesServer();
    repository = HermesChatRepository(server.client().raw);
  });

  test('existing transcript parser retains only canonical row identity and supplied metadata', () async {
    server.on(
      'GET',
      '/api/sessions/child/messages',
      messageListBody('child', [
        {
          ...messageRow(id: 1, role: 'user', content: 'Repeated'),
          'row_id': 21,
          'display_metadata': {
            'reactions': [
              {'emoji': '👍', 'author': 'agent'},
            ],
          },
        },
        {
          ...messageRow(id: 2, role: 'assistant', content: 'Repeated'),
          'row_id': 22,
          'display_metadata': jsonEncode({
            'reactions': [
              {'emoji': '🎉', 'author': 'user'},
            ],
          }),
        },
      ]),
    );
    final messages = await repository.loadMessages('child', profile: 'work');
    expect(messages.first.canonicalRow?.rowId, 21);
    expect(messages.first.canonicalRow?.role, 'user');
    expect(messages.first.canonicalRow?.reactions?.single.emoji, '👍');
    expect(messages.last.canonicalRow?.rowId, 22);
    expect(messages.last.canonicalRow?.role, 'assistant');
    expect(messages.last.canonicalRow?.reactions?.single.author, 'user');
    expect(messages.map((message) => message.content), [
      'Repeated',
      'Repeated',
    ]);
  });

  test(
    'history id and private row aliases never become canonical identity',
    () async {
      server.on(
        'GET',
        '/api/sessions/s/messages',
        messageListBody('s', [
          messageRow(id: 21, role: 'user', content: 'Alias id'),
          {
            ...messageRow(id: 22, role: 'assistant', content: 'Alias private'),
            '_row_id': 21,
          },
          {
            ...messageRow(id: 23, role: 'user', content: 'String id'),
            'row_id': '21',
          },
          {
            ...messageRow(id: 24, role: 'user', content: 'Invalid id'),
            'row_id': 0,
          },
        ]),
      );
      final messages = await repository.loadMessages('s');
      expect(messages.map((message) => message.canonicalRow), [
        null,
        null,
        null,
        null,
      ]);
      expect(messages, hasLength(4));
    },
  );

  test(
    'malformed optional reaction metadata preserves ordinary transcript prose',
    () async {
      server.on(
        'GET',
        '/api/sessions/s/messages',
        messageListBody('s', [
          {
            ...messageRow(id: 1, role: 'assistant', content: 'Kept'),
            'row_id': 21,
            'display_metadata': '{invalid',
          },
        ]),
      );
      final message = (await repository.loadMessages('s')).single;
      expect(message.content, 'Kept');
      expect(message.canonicalRow?.rowId, 21);
      expect(message.canonicalRow?.reactions, isNull);
    },
  );
}
