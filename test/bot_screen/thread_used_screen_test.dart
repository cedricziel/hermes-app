import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_screen/widgets/bound_bot_screen_card.dart';
import 'package:hermes_app/src/chat/chat_models.dart';

/// A message list that counts how often its elements are read.
class _CountingList extends ListBase<ChatMessage> {
  final _items = <ChatMessage>[];
  var reads = 0;

  @override
  int get length => _items.length;

  @override
  set length(int value) => throw UnsupportedError('fixed by add');

  @override
  void add(ChatMessage element) => _items.add(element);

  @override
  ChatMessage operator [](int index) {
    reads++;
    return _items[index];
  }

  @override
  void operator []=(int index, ChatMessage value) => _items[index] = value;
}

ChatMessage _message(String id, {List<ToolCall> toolCalls = const []}) =>
    ChatMessage(
      id: id,
      role: ChatRole.assistant,
      content: '',
      createdAt: DateTime(2030),
      toolCalls: toolCalls,
    );

const _screen = ToolCall(name: 'computer_use', summary: 'screenshot');
const _other = ToolCall(name: 'terminal', summary: 'ls');

ChatThread _thread(List<ChatMessage> messages) => ChatThread(
  id: 't',
  title: 'Chat',
  updatedAt: DateTime(2030),
  messages: messages,
);

void main() {
  test('finds a computer_use call and ignores other tools', () {
    expect(
      threadUsedScreen(
        _thread([
          _message('1', toolCalls: [_other]),
        ]),
      ),
      isFalse,
    );
    expect(
      threadUsedScreen(
        _thread([
          _message('1', toolCalls: [_other, _screen]),
        ]),
      ),
      isTrue,
    );
  });

  test('sees a message added later', () {
    final thread = _thread([_message('1')]);
    expect(threadUsedScreen(thread), isFalse);

    thread.messages.add(_message('2', toolCalls: [_screen]));

    expect(threadUsedScreen(thread), isTrue);
  });

  test('sees a call that arrives in the last message while it streams', () {
    final last = _message('2');
    final thread = _thread([_message('1'), last]);
    expect(threadUsedScreen(thread), isFalse);

    last.toolCalls = [_other, _screen];

    expect(threadUsedScreen(thread), isTrue);
  });

  test('does not read the messages again while nothing changed', () {
    final messages = _CountingList()
      ..addAll([for (var i = 0; i < 50; i++) _message('$i')]);
    final thread = _thread(messages);
    expect(threadUsedScreen(thread), isFalse);
    final reads = messages.reads;

    for (var i = 0; i < 10; i++) {
      threadUsedScreen(thread);
    }

    // Only the newest message is looked at, to see whether it changed.
    expect(messages.reads - reads, lessThanOrEqualTo(10));
  });
}
