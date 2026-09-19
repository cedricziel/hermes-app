import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_reply.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';

ChatMessage _placeholder() => ChatMessage(
  id: 't-1',
  role: ChatRole.assistant,
  content: '',
  createdAt: DateTime(2026),
  status: MessageStatus.thinking,
);

void main() {
  test('stays thinking until the first text arrives', () {
    final reply = _placeholder();

    applyReplyEvent(reply, const ReplyStarted());

    expect(reply.status, MessageStatus.thinking);
  });

  test('deltas append and move the reply to streaming', () {
    final reply = _placeholder();

    applyReplyEvent(reply, const ReplyDelta('Hel'));
    applyReplyEvent(reply, const ReplyDelta('lo'));

    expect(reply.content, 'Hello');
    expect(reply.status, MessageStatus.streaming);
  });

  test('completion sets the final text and finishes the reply', () {
    final reply = _placeholder();
    applyReplyEvent(reply, const ReplyDelta('Hel'));

    applyReplyEvent(reply, const ReplyCompleted('Hello there'));

    expect(reply.content, 'Hello there');
    expect(reply.status, MessageStatus.sent);
  });

  test('completion without text keeps what streamed', () {
    final reply = _placeholder();
    applyReplyEvent(reply, const ReplyDelta('Hello'));

    applyReplyEvent(reply, const ReplyCompleted(''));

    expect(reply.content, 'Hello');
    expect(reply.status, MessageStatus.sent);
  });

  test('a failed completion shows its message as an error', () {
    final reply = _placeholder();
    applyReplyEvent(reply, const ReplyDelta('Hel'));

    applyReplyEvent(
      reply,
      const ReplyCompleted('Model unavailable', failed: true),
    );

    expect(reply.content, 'Model unavailable');
    expect(reply.status, MessageStatus.error);
  });

  test('a tool runs, then completes', () {
    final reply = _placeholder();

    applyReplyEvent(reply, const ToolStarted(name: 'search', summary: 'logs'));
    expect(reply.toolCalls.single.name, 'search');
    expect(reply.toolCalls.single.summary, 'logs');
    expect(reply.toolCalls.single.status, ToolCallStatus.running);

    applyReplyEvent(reply, const ToolFinished(name: 'search'));
    expect(reply.toolCalls.single.status, ToolCallStatus.completed);
    expect(reply.toolCalls.single.summary, 'logs');
  });

  test('a failed tool ends in error', () {
    final reply = _placeholder();
    applyReplyEvent(reply, const ToolStarted(name: 'search'));

    applyReplyEvent(reply, const ToolFinished(name: 'search', failed: true));

    expect(reply.toolCalls.single.status, ToolCallStatus.error);
  });

  test('a finished tool closes the running call of that name only', () {
    final reply = _placeholder();
    applyReplyEvent(reply, const ToolStarted(name: 'search'));
    applyReplyEvent(reply, const ToolStarted(name: 'fetch'));
    applyReplyEvent(reply, const ToolStarted(name: 'search'));

    applyReplyEvent(reply, const ToolFinished(name: 'search'));

    expect(reply.toolCalls.map((c) => c.status), [
      ToolCallStatus.completed,
      ToolCallStatus.running,
      ToolCallStatus.running,
    ]);
  });

  test('a finished tool nobody started changes nothing', () {
    final reply = _placeholder();

    applyReplyEvent(reply, const ToolFinished(name: 'search'));

    expect(reply.toolCalls, isEmpty);
  });

  test('completion closes tools that never reported back', () {
    final reply = _placeholder();
    applyReplyEvent(reply, const ToolStarted(name: 'search'));

    applyReplyEvent(reply, const ReplyCompleted('Done'));

    expect(reply.toolCalls.single.status, ToolCallStatus.completed);
  });

  test('thread events do not touch the reply', () {
    final reply = _placeholder();

    applyReplyEvent(reply, const ThreadBound('s1'));
    applyReplyEvent(reply, const ThreadTitled('Title'));

    expect(reply.content, isEmpty);
    expect(reply.status, MessageStatus.thinking);
  });

  group('failReply', () {
    test('without any text shows the fallback message', () {
      final reply = _placeholder();

      failReply(reply);

      expect(reply.content, kReplyFailedMessage);
      expect(reply.status, MessageStatus.error);
    });

    test('keeps the text that had already streamed', () {
      final reply = _placeholder();
      applyReplyEvent(reply, const ReplyDelta('Half an ans'));

      failReply(reply);

      expect(reply.content, 'Half an ans');
      expect(reply.status, MessageStatus.error);
    });

    test('stops tools that were still running', () {
      final reply = _placeholder();
      applyReplyEvent(reply, const ToolStarted(name: 'search'));

      failReply(reply);

      expect(reply.toolCalls.single.status, ToolCallStatus.error);
    });
  });
}
