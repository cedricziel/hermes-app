import 'package:flutter_chat_core/flutter_chat_core.dart'
    show CustomMessage, InMemoryChatController, TextMessage;
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/chat/chat_controller_sync.dart';
import 'package:hermes_app/src/chat/chat_message_kinds.dart';
import 'package:hermes_app/src/chat/chat_message_mapper.dart';
import 'package:hermes_app/src/chat/chat_models.dart';

ChatMessage _message(String id, ChatRole role, {String content = 'x'}) =>
    ChatMessage(
      id: id,
      role: role,
      content: content,
      createdAt: DateTime(2026),
    );

List<String> _ids(InMemoryChatController c) =>
    c.messages.map((m) => m.id).toList();

void main() {
  late ChatMessage first;
  late ChatMessage reply;
  late ChatMessage second;
  late InMemoryChatController controller;

  setUp(() {
    first = _message('t-0', ChatRole.user);
    reply = ChatMessage(
      id: 't-1',
      role: ChatRole.assistant,
      content: '',
      createdAt: DateTime(2026),
      status: MessageStatus.thinking,
    );
    second = _message('t-2', ChatRole.user);
    controller = InMemoryChatController(
      messages: [
        ...chatMessageToFlyer(first),
        ...chatMessageToFlyer(reply),
        ...chatMessageToFlyer(second),
      ],
    );
  });

  void change(void Function() mutate) {
    final before = chatMessageToFlyer(reply);
    mutate();
    syncMessage(controller, before, chatMessageToFlyer(reply));
  }

  test('the text takes the thinking indicator\'s place, mid-thread', () {
    change(() {
      reply.status = MessageStatus.streaming;
      reply.content = 'Hi';
    });

    expect(_ids(controller), ['t-0', 't-1', 't-2']);
    expect((controller.messages[1] as TextMessage).text, 'Hi');
  });

  test('a later change updates the text in place', () {
    change(() {
      reply.status = MessageStatus.streaming;
      reply.content = 'Hi';
    });
    change(() => reply.content = 'Hi there');

    expect(_ids(controller), ['t-0', 't-1', 't-2']);
    expect((controller.messages[1] as TextMessage).text, 'Hi there');
  });

  test('a group of tool cards appears before the text, keeping the reply\'s '
      'slot', () {
    change(
      () => reply.toolCalls = const [
        ToolCall(name: 'a', summary: '', status: ToolCallStatus.running),
        ToolCall(name: 'b', summary: '', status: ToolCallStatus.running),
      ],
    );
    expect(_ids(controller), ['t-0', 't-1-tool-0', 't-1-thinking', 't-2']);

    change(() {
      reply.status = MessageStatus.streaming;
      reply.content = 'Done';
    });
    expect(_ids(controller), ['t-0', 't-1-tool-0', 't-1', 't-2']);
  });

  test('a tool card changes status in place', () {
    change(
      () => reply.toolCalls = const [
        ToolCall(name: 'a', summary: '', status: ToolCallStatus.running),
      ],
    );
    change(
      () => reply.toolCalls = const [
        ToolCall(name: 'a', summary: '', status: ToolCallStatus.completed),
      ],
    );

    final card = controller.messages[1] as CustomMessage;
    expect(_ids(controller), ['t-0', 't-1-tool-0', 't-1-thinking', 't-2']);
    final calls = card.metadata?[kMetaToolCalls] as List<ToolCall>;
    expect(calls.single.status, ToolCallStatus.completed);
  });

  test('a reply that is not in the controller yet is appended', () {
    final other = InMemoryChatController();

    syncMessage(other, const [], chatMessageToFlyer(first));

    expect(_ids(other), ['t-0']);
  });
}
