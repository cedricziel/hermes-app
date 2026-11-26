import 'dart:convert';

import 'package:flutter_chat_core/flutter_chat_core.dart' show TextMessage;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_message_kinds.dart';
import 'package:hermes_app/src/chat/chat_message_mapper.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/sources/turn_sources.dart';

import 'support/fake_hermes_server.dart';
import 'support/sources_fixtures.dart';

Map<String, Object?> _calls(
  String id,
  String name,
  Map<String, Object?> args,
) => messageRow(
  id: 0,
  role: 'assistant',
  content: '',
  toolCalls: [
    {
      'id': id,
      'function': {'name': name, 'arguments': jsonEncode(args)},
    },
  ],
);

/// The rows Hermes stores for one tool call: the assistant row that makes it
/// and the `tool` row that answers it.
List<Map<String, Object?>> _step(
  int firstId,
  String id,
  String name,
  Map<String, Object?> args,
  Object result,
) => [
  {..._calls(id, name, args), 'id': firstId},
  messageRow(
    id: firstId + 1,
    role: 'tool',
    toolCallId: id,
    content: jsonEncode(result),
  ),
];

List<Map<String, Object?>> _storedTurn() => [
  messageRow(id: 1, role: 'user', content: 'What changed?'),
  ..._step(
    2,
    'c1',
    'web_search',
    const {'query': 'changes'},
    {
      'success': true,
      'data': {
        'web': [
          searchHit('https://news.example/a', title: 'Hit A'),
          searchHit('https://news.example/b', title: 'Hit B'),
        ],
      },
    },
  ),
  ..._step(
    4,
    'c2',
    'web_extract',
    const {
      'urls': ['https://news.example/b'],
    },
    {
      'results': [
        {'url': 'https://news.example/b', 'title': 'Hit B', 'content': 'text'},
      ],
    },
  ),
  ..._step(
    6,
    'c3',
    'browser_navigate',
    const {'url': 'https://docs.example/start'},
    {'success': true, 'url': 'https://docs.example/start', 'title': 'Start'},
  ),
  messageRow(id: 8, role: 'assistant', content: 'Here is what changed.'),
];

/// What the chat of [kind] shows under each of its texts.
Future<Map<String, Object?>> _sourcesOf(List<ChatMessage> messages) async => {
  for (final flyer in chatMessagesToFlyer(messages))
    if (flyer is TextMessage) flyer.text: flyer.metadata?[kMetaSources],
};

void main() {
  group('a stored turn of three assistant rows', () {
    late List<ChatMessage> history;

    setUp(() async {
      final server = FakeHermesServer()
        ..on(
          'GET',
          '/api/sessions/s1/messages',
          messageListBody('s1', _storedTurn()),
        );
      history = await HermesChatRepository(server.client().raw)
          .loadMessages('s1');
    });

    test(
      'shows one row, under the reply, with the sources of all of them',
      () async {
        expect(
          history.where(
            (m) => m.role == ChatRole.assistant && m.toolCalls.isNotEmpty,
          ),
          hasLength(3),
        );

        final sources = await _sourcesOf(history);

        expect(sources['Here is what changed.'], [
          for (final (address, title) in [
            ('https://news.example/b', 'Hit B'),
            ('https://docs.example/start', 'Start'),
            ('https://news.example/a', 'Hit A'),
          ])
            isA<TurnSource>()
                .having((s) => s.address, 'address', address)
                .having((s) => s.title, 'title', title),
        ]);
        expect(sources.length, 2, reason: 'the prompt and the reply');
        expect(sources['What changed?'], isNull);
      },
    );

    test('is what the live turn shows', () async {
      final live = ChatMessage(
        id: 'live',
        role: ChatRole.assistant,
        content: 'Here is what changed.',
        createdAt: DateTime(2026),
        toolCalls: [for (final m in history) ...m.toolCalls],
      );

      final reloaded = (await _sourcesOf(history))['Here is what changed.'];
      final shown = (chatMessageToFlyer(
        live,
      ).whereType<TextMessage>().single).metadata?[kMetaSources];

      expect(reloaded, isNotNull);
      expect(shown, reloaded);
    });

    test('a later turn without browsing has none', () async {
      final rows = [
        ..._storedTurn(),
        messageRow(id: 9, role: 'user', content: 'Thanks'),
        messageRow(id: 10, role: 'assistant', content: 'You are welcome.'),
      ];
      final server = FakeHermesServer()
        ..on('GET', '/api/sessions/s1/messages', messageListBody('s1', rows));
      final more = await HermesChatRepository(server.client().raw)
          .loadMessages('s1');

      final sources = await _sourcesOf(more);

      expect(sources['Here is what changed.'], hasLength(3));
      expect(sources['You are welcome.'], isNull);
    });
  });

  group('a reply that is not finished', () {
    ChatMessage reply(MessageStatus status) => ChatMessage(
      id: 'r',
      role: ChatRole.assistant,
      content: 'Partial',
      createdAt: DateTime(2026),
      status: status,
      toolCalls: [
        searchCall([searchHit('https://news.example/a')]),
      ],
    );

    Object? shown(ChatMessage m) =>
        chatMessageToFlyer(m)
            .whereType<TextMessage>()
            .single
            .metadata?[kMetaSources];

    test('streaming has no sources yet', () {
      expect(shown(reply(MessageStatus.streaming)), isNull);
    });

    test('finished, stopped and failed replies have them', () {
      expect(shown(reply(MessageStatus.sent)), hasLength(1));
      expect(shown(reply(MessageStatus.sent)..stopped = true), hasLength(1));
      expect(shown(reply(MessageStatus.error)), hasLength(1));
    });

    test('a reply that browsed nothing has none', () {
      final plain = ChatMessage(
        id: 'p',
        role: ChatRole.assistant,
        content: 'Hi',
        createdAt: DateTime(2026),
      );
      expect(chatMessageToFlyer(plain).single.metadata, isNull);
    });
  });

  group('the calls a settled reply is mapped with again', () {
    ChatMessage message(
      ChatRole role,
      String id, [
      List<ToolCall> calls = const [],
    ]) => ChatMessage(
      id: id,
      role: role,
      content: id,
      createdAt: DateTime(2026),
      toolCalls: calls,
    );

    test('are those of its whole turn only for the message that ends it', () {
      final a = searchCall([searchHit('https://a.test/')]);
      final b = searchCall([searchHit('https://b.test/')]);
      final prompt = message(ChatRole.user, 'prompt');
      final first = message(ChatRole.assistant, 'first', [a]);
      final last = message(ChatRole.assistant, 'last', [b]);
      final next = message(ChatRole.user, 'next');
      final later = message(ChatRole.assistant, 'later');
      final all = [prompt, first, last, next, later];

      expect(turnCallsEndedBy(all, first), isEmpty);
      expect(turnCallsEndedBy(all, last), [a, b]);
      expect(turnCallsEndedBy(all, later), isEmpty);
      expect(turnCallsEndedBy(all, message(ChatRole.assistant, 'new')), isNull);
    });
  });
}
