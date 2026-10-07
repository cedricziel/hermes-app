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

const _approval = ApprovalRequest(
  requestId: 'r1',
  command: 'rm -rf build',
  description: 'delete files',
  choices: ['once', 'session', 'deny'],
);

const _clarify = ClarifyRequest(
  requestId: 'r2',
  questions: [
    ClarifyQuestion(
      qid: '',
      question: 'Which colour?',
      choices: ['red', 'blue'],
    ),
  ],
);

InputRequest _request(ChatMessage reply, String id) =>
    reply.inputRequests.firstWhere((r) => r.requestId == id);

List<String> _sealedTexts(ChatMessage reply) =>
    reply.sealedProse.map((s) => s.text).toList();

void main() {
  group('completion flags (spec: Final already shown, Final rewritten)', () {
    test('previewed final equal to the last sealed text adds nothing', () {
      final reply = _placeholder();

      applyReplyEvent(reply, const ReplyCheckpoint('Done'));
      applyReplyEvent(reply, const ReplyCompleted('Done', previewed: true));

      expect(reply.content, '');
      expect(reply.status, MessageStatus.sent);
    });

    test('reused final equal to the streamed text leaves it unchanged', () {
      final reply = _placeholder();

      applyReplyEvent(reply, const ReplyDelta('Hello'));
      applyReplyEvent(reply, const ReplyCompleted('Hello', reused: true));

      expect(reply.content, 'Hello');
      expect(reply.status, MessageStatus.sent);
    });

    test('previewed final whose text appears nowhere is shown', () {
      final reply = _placeholder();

      applyReplyEvent(reply, const ReplyDelta('A'));
      applyReplyEvent(reply, const ReplyCompleted('Z', previewed: true));

      expect(reply.content, 'Z');
    });

    test('transformed final replaces the streamed text', () {
      final reply = _placeholder();

      applyReplyEvent(reply, const ReplyDelta('A'));
      applyReplyEvent(reply, const ReplyCompleted('B', transformed: true));

      expect(reply.content, 'B');
      expect(reply.status, MessageStatus.sent);
    });

    test('failed final with partial keeps its text and shows its error', () {
      final reply = _placeholder();

      applyReplyEvent(
        reply,
        const ReplyCompleted(
          'answer',
          failed: true,
          partial: true,
          error: 'boom',
        ),
      );

      expect(reply.content, 'answer');
      expect(reply.error, 'boom');
      expect(reply.status, MessageStatus.error);
    });

    test('failed final without partial shows its text as the error', () {
      final reply = _placeholder();

      applyReplyEvent(reply, const ReplyCompleted('oops', failed: true));

      expect(reply.error, 'oops');
      expect(reply.status, MessageStatus.error);
    });
  });

  group('interim message not already streamed (spec: Interim message)', () {
    test('is sealed after the text that streamed', () {
      final reply = _placeholder();

      applyReplyEvent(reply, const ReplyDelta('A'));
      applyReplyEvent(
        reply,
        const ReplyCheckpoint('X', alreadyStreamed: false),
      );

      expect(_sealedTexts(reply), ['A', 'X']);
      expect(reply.content, '');
    });

    test('already streamed takes the place of the streamed text', () {
      final reply = _placeholder();

      applyReplyEvent(reply, const ReplyDelta('A'));
      applyReplyEvent(reply, const ReplyCheckpoint('X'));

      expect(_sealedTexts(reply), ['X']);
      expect(reply.content, '');
    });
  });

  group('held errors and settling (spec: Settled without a completion)', () {
    test('an error event is held, not shown, until the turn settles', () {
      final reply = _placeholder();

      applyReplyEvent(reply, const ReplyDelta('Hi'));
      applyReplyEvent(reply, const ReplyErrored('bad'));

      expect(reply.pendingError, 'bad');
      expect(reply.errorEventSeen, isTrue);
      expect(reply.status, MessageStatus.streaming);
      expect(reply.error, isNull);
    });

    test('settling after a held error shows that error and keeps the text', () {
      final reply = _placeholder();

      applyReplyEvent(reply, const ReplyDelta('Hi'));
      applyReplyEvent(reply, const ReplyErrored('bad'));
      applyReplyEvent(reply, const SessionInfo(running: false));

      expect(reply.status, MessageStatus.error);
      expect(reply.error, 'bad');
      expect(reply.content, 'Hi');
    });

    test(
      'a failed completion after a held error shows only its own message',
      () {
        final reply = _placeholder();

        applyReplyEvent(reply, const ReplyErrored('bad'));
        applyReplyEvent(reply, const ReplyCompleted('real', failed: true));

        expect(reply.error, 'real');
        expect(reply.status, MessageStatus.error);
        expect(reply.pendingError, isNull);
        expect(reply.errorEventSeen, isFalse);
      },
    );

    test(
      'settling without a completion keeps the text and marks the reply sent',
      () {
        final reply = _placeholder();

        applyReplyEvent(reply, const ReplyDelta('Hi'));
        applyReplyEvent(reply, const SessionInfo(running: false));

        expect(reply.status, MessageStatus.sent);
        expect(reply.content, 'Hi');
        expect(reply.settledWithoutCompletion, isTrue);
      },
    );

    test('settling without a completion settles running tools and expires open requests', () {
      final reply = _placeholder();

      applyReplyEvent(reply, const ToolStarted(name: 'terminal', id: 't1'));
      applyReplyEvent(reply, const ApprovalRequested(_approval));
      applyReplyEvent(reply, const SessionInfo(running: false));

      expect(reply.toolCalls.single.status, ToolCallStatus.completed);
      expect(_request(reply, 'r1').status, InputRequestStatus.expired);
    });

    test('session info on a finished reply changes nothing', () {
      final reply = _placeholder();

      applyReplyEvent(reply, const ReplyCompleted('Done'));
      applyReplyEvent(reply, const SessionInfo(running: false));

      expect(reply.status, MessageStatus.sent);
      expect(reply.content, 'Done');
      expect(reply.settledWithoutCompletion, isFalse);
    });

    test('session info that is running or only re-keys changes nothing', () {
      final reply = _placeholder();

      applyReplyEvent(reply, const ReplyDelta('Hi'));
      applyReplyEvent(reply, const SessionInfo(running: true));
      applyReplyEvent(reply, const SessionInfo(storedSessionId: 'x'));

      expect(reply.status, MessageStatus.streaming);
      expect(reply.content, 'Hi');
      expect(reply.settledWithoutCompletion, isFalse);
    });

    test('a completion after a settle applies by the same rules and clears the flag', () {
      final reply = _placeholder();

      applyReplyEvent(reply, const ReplyDelta('stream'));
      applyReplyEvent(reply, const SessionInfo(running: false));
      expect(reply.settledWithoutCompletion, isTrue);

      applyReplyEvent(reply, const ReplyCompleted('final', transformed: true));

      expect(reply.content, 'final');
      expect(reply.settledWithoutCompletion, isFalse);
    });

    test('a previewed completion after a settle is not shown twice', () {
      final reply = _placeholder();

      applyReplyEvent(reply, const ReplyCheckpoint('A'));
      applyReplyEvent(reply, const SessionInfo(running: false));
      applyReplyEvent(reply, const ReplyCompleted('A', previewed: true));

      expect(reply.content, '');
      expect(_sealedTexts(reply), ['A']);
      expect(reply.settledWithoutCompletion, isFalse);
    });
  });

  group('status line (spec: Reply status line)', () {
    test('a status update names what the reply is doing', () {
      final reply = _placeholder();

      applyReplyEvent(reply, const ReplyStatus('Compacting the conversation…'));

      expect(reply.activity, 'Compacting the conversation…');
    });

    test('an empty status update clears the status line', () {
      final reply = _placeholder();

      applyReplyEvent(reply, const ReplyStatus('Compacting the conversation…'));
      applyReplyEvent(reply, const ReplyStatus(''));

      expect(reply.activity, isNull);
    });

    for (final event in <ChatEvent>[
      const ReplyDelta('x'),
      const ReasoningUpdated('x'),
      const ToolPreparing('terminal'),
      const ToolStarted(name: 'terminal'),
      const ToolFinished(name: 'terminal'),
      const ReplyCompleted('x'),
      const ReplyErrored('x'),
    ]) {
      test('${event.runtimeType} clears the status line', () {
        final reply = _placeholder();

        applyReplyEvent(reply, const ReplyStatus('Waiting on the model…'));
        applyReplyEvent(reply, event);

        expect(reply.activity, isNull);
      });
    }
  });

  group('rebuilt text and cancelled requests (spec: Replay truncated)', () {
    test(
      'a rebuilt reply replaces the streamed text and keeps the sealed prose',
      () {
        final reply = _placeholder();

        applyReplyEvent(reply, const ReplyCheckpoint('X'));
        applyReplyEvent(reply, const ReplyDelta('par'));
        applyReplyEvent(reply, const ReplyRebuilt('full'));

        expect(reply.content, 'full');
        expect(_sealedTexts(reply), ['X']);
      },
    );

    test('an interrupt cancelling one request expires only that request', () {
      final reply = _placeholder();

      applyReplyEvent(reply, const ApprovalRequested(_approval));
      applyReplyEvent(reply, const ClarifyRequested(_clarify));
      applyReplyEvent(reply, const InputRequestsCancelled(['r1']));

      expect(_request(reply, 'r1').status, InputRequestStatus.expired);
      expect(_request(reply, 'r2').status, InputRequestStatus.pending);
    });

    test('an interrupt cancelling no ids expires every open request', () {
      final reply = _placeholder();

      applyReplyEvent(reply, const ApprovalRequested(_approval));
      applyReplyEvent(reply, const ClarifyRequested(_clarify));
      applyReplyEvent(reply, const InputRequestsCancelled([]));

      expect(_request(reply, 'r1').status, InputRequestStatus.expired);
      expect(_request(reply, 'r2').status, InputRequestStatus.expired);
    });
  });
}
