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

void main() {
  test('reasoning deltas add up and stay thinking', () {
    final reply = _placeholder();

    applyReplyEvent(reply, const ReasoningUpdated('Let me '));
    applyReplyEvent(reply, const ReasoningUpdated('think.'));

    expect(reply.reasoning, 'Let me think.');
    expect(reply.status, MessageStatus.thinking);
  });

  test('the full reasoning replaces what streamed', () {
    final reply = _placeholder();

    applyReplyEvent(reply, const ReasoningUpdated('Let me'));
    applyReplyEvent(
      reply,
      const ReasoningUpdated('Let me think.', replace: true),
    );

    expect(reply.reasoning, 'Let me think.');
  });

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

  test('a stopped reply with nothing streamed says it was stopped', () {
    final reply = _placeholder();

    applyReplyEvent(reply, const ReplyCompleted('', stopped: true));

    expect(reply.content, kReplyStoppedMessage);
    expect(reply.status, MessageStatus.sent);
  });

  test('a stopped reply keeps what had streamed', () {
    final reply = _placeholder();
    applyReplyEvent(reply, const ReplyDelta('Half an ans'));

    applyReplyEvent(reply, const ReplyCompleted('', stopped: true));

    expect(reply.content, 'Half an ans');
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

  test('a failed completion with no text shows the fallback message', () {
    final reply = _placeholder();

    applyReplyEvent(reply, const ReplyCompleted('', failed: true));

    expect(reply.content, kReplyFailedMessage);
    expect(reply.status, MessageStatus.error);
  });

  test('a failed completion with no text keeps what streamed', () {
    final reply = _placeholder();
    applyReplyEvent(reply, const ReplyDelta('Partial'));

    applyReplyEvent(reply, const ReplyCompleted('', failed: true));

    expect(reply.content, 'Partial');
    expect(reply.status, MessageStatus.error);
  });

  group('text written before a tool call', () {
    test('is sealed ahead of the tool call, not lost with it', () {
      final reply = _placeholder();

      applyReplyEvent(reply, const ReplyDelta('Hey! Let me check.'));
      applyReplyEvent(reply, const ToolStarted(name: 'terminal'));

      expect(reply.sealedProse.single.text, 'Hey! Let me check.');
      expect(reply.sealedProse.single.beforeToolCall, 0);
      expect(reply.content, '');
    });

    test('a second segment written between tool calls seals separately', () {
      final reply = _placeholder();

      applyReplyEvent(reply, const ReplyDelta('First,'));
      applyReplyEvent(reply, const ToolStarted(name: 'a'));
      applyReplyEvent(reply, const ToolFinished(name: 'a'));
      applyReplyEvent(reply, const ReplyDelta('then this.'));
      applyReplyEvent(reply, const ToolStarted(name: 'b'));

      expect(reply.sealedProse.map((p) => (p.text, p.beforeToolCall)), [
        ('First,', 0),
        ('then this.', 1),
      ]);
    });

    test('completion only replaces the text written since the last seal', () {
      final reply = _placeholder();
      applyReplyEvent(reply, const ReplyDelta('Hey!'));
      applyReplyEvent(reply, const ToolStarted(name: 'terminal'));

      applyReplyEvent(reply, const ReplyCompleted('All done.', failed: false));

      expect(reply.sealedProse.single.text, 'Hey!');
      expect(reply.content, 'All done.');
    });

    test('a turn that never writes more after its tool keeps the greeting', () {
      final reply = _placeholder();
      applyReplyEvent(reply, const ReplyDelta('Hey!'));
      applyReplyEvent(reply, const ToolStarted(name: 'terminal'));

      applyReplyEvent(reply, const ReplyCompleted('', failed: false));

      expect(reply.sealedProse.single.text, 'Hey!');
      expect(reply.content, isEmpty);
    });
  });

  group('ReplyCheckpoint', () {
    test(
      'already-streamed text is sealed and cleared from what streams next',
      () {
        final reply = _placeholder();
        applyReplyEvent(reply, const ReplyDelta('Hey there.'));

        applyReplyEvent(
          reply,
          const ReplyCheckpoint('Hey there.', alreadyStreamed: true),
        );

        expect(reply.sealedProse.single.text, 'Hey there.');
        expect(reply.content, isEmpty);
      },
    );

    test('text that never streamed is sealed from the checkpoint itself', () {
      final reply = _placeholder();

      applyReplyEvent(
        reply,
        const ReplyCheckpoint('A quick aside.', alreadyStreamed: false),
      );

      expect(reply.sealedProse.single.text, 'A quick aside.');
    });

    test('an empty checkpoint seals nothing', () {
      final reply = _placeholder();

      applyReplyEvent(reply, const ReplyCheckpoint('', alreadyStreamed: true));

      expect(reply.sealedProse, isEmpty);
    });
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

  test('a finished tool keeps what it returned', () {
    final reply = _placeholder();
    applyReplyEvent(reply, const ToolStarted(name: 'search'));

    applyReplyEvent(
      reply,
      const ToolFinished(name: 'search', result: '3 matches'),
    );

    expect(reply.toolCalls.single.result, '3 matches');
  });

  test('reasoning before a call stays with it, and new reasoning follows', () {
    final reply = _placeholder();

    applyReplyEvent(reply, const ReasoningUpdated('Check the logs.'));
    applyReplyEvent(reply, const ToolStarted(name: 'search'));
    applyReplyEvent(reply, const ReasoningUpdated('Found it.'));
    applyReplyEvent(reply, const ReasoningUpdated('Found it!', replace: true));

    expect(reply.toolCalls.single.reasoning, 'Check the logs.');
    expect(reply.reasoning, 'Found it!');
  });

  test('settling a call keeps its reasoning', () {
    final reply = _placeholder();
    applyReplyEvent(reply, const ReasoningUpdated('Check.'));
    applyReplyEvent(reply, const ToolStarted(name: 'search'));

    applyReplyEvent(reply, const ToolFinished(name: 'search', result: 'x'));

    expect(reply.toolCalls.single.reasoning, 'Check.');
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

  test('an approval request is added to the reply, pending', () {
    final reply = _placeholder();

    applyReplyEvent(reply, const ApprovalRequested(_approval));

    expect(reply.inputRequests.single, same(_approval));
    expect(reply.inputRequests.single.status, InputRequestStatus.pending);
    expect(reply.awaitingInput, isTrue);
  });

  test('requests stack in the order they arrive', () {
    final reply = _placeholder();

    applyReplyEvent(reply, const ApprovalRequested(_approval));
    applyReplyEvent(reply, const ClarifyRequested(_clarify));

    expect(reply.inputRequests.map((r) => r.requestId), ['r1', 'r2']);
  });

  test('an expire event ends only the matching pending request', () {
    final reply = _placeholder();
    applyReplyEvent(reply, const ApprovalRequested(_approval));
    applyReplyEvent(reply, const ClarifyRequested(_clarify));

    applyReplyEvent(reply, const InputRequestExpired('r1'));

    expect(reply.inputRequests[0].status, InputRequestStatus.expired);
    expect(reply.inputRequests[1].status, InputRequestStatus.pending);
  });

  test('completion expires a request nobody answered', () {
    final reply = _placeholder();
    applyReplyEvent(reply, const ApprovalRequested(_approval));

    applyReplyEvent(reply, const ReplyCompleted('Done'));

    expect(reply.inputRequests.single.status, InputRequestStatus.expired);
    expect(reply.awaitingInput, isFalse);
  });

  test('a broken stream expires a request nobody answered', () {
    final reply = _placeholder();
    applyReplyEvent(reply, const ClarifyRequested(_clarify));

    failReply(reply);

    expect(reply.inputRequests.single.status, InputRequestStatus.expired);
  });

  test('recording an approval settles it with the choice', () {
    final reply = _placeholder();
    applyReplyEvent(reply, const ApprovalRequested(_approval));

    recordApproval(reply, 'r1', 'once');

    final request = reply.inputRequests.single as ApprovalRequest;
    expect(request.status, InputRequestStatus.answered);
    expect(request.choice, 'once');
  });

  test('recording clarify answers settles it with the answers', () {
    final reply = _placeholder();
    applyReplyEvent(reply, const ClarifyRequested(_clarify));

    recordClarifyAnswers(reply, 'r2', {
      '': ['blue'],
    });

    final request = reply.inputRequests.single as ClarifyRequest;
    expect(request.status, InputRequestStatus.answered);
    expect(request.answers, {
      '': ['blue'],
    });
  });

  test('an unsupported request is added to the reply, pending', () {
    final reply = _placeholder();
    const request = UnsupportedRequest(
      requestId: 'r9',
      kind: UnsupportedKind.sudo,
    );

    applyReplyEvent(reply, const UnsupportedRequested(request));

    expect(reply.inputRequests.single, same(request));
    expect(reply.awaitingInput, isTrue);
  });

  test('an unsupported request expires with the turn', () {
    final reply = _placeholder();
    applyReplyEvent(
      reply,
      const UnsupportedRequested(
        UnsupportedRequest(requestId: 'r9', kind: UnsupportedKind.secret),
      ),
    );

    applyReplyEvent(reply, const ReplyCompleted('Done'));

    expect(reply.inputRequests.single.status, InputRequestStatus.expired);
  });

  test('an answered request is not expired later', () {
    final reply = _placeholder();
    applyReplyEvent(reply, const ApprovalRequested(_approval));
    recordApproval(reply, 'r1', 'deny');

    applyReplyEvent(reply, const ReplyCompleted('Done'));

    expect(reply.inputRequests.single.status, InputRequestStatus.answered);
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

    test('explains a profile that no longer exists', () {
      final reply = _placeholder();

      failReply(reply, const ProfileUnavailableException());

      expect(reply.content, kProfileUnavailableMessage);
      expect(
        reply.content,
        'That profile is no longer available. Pick another one.',
      );
      expect(reply.status, MessageStatus.error);
    });

    test('shows the fallback for any other error', () {
      final reply = _placeholder();

      failReply(reply, Exception('socket closed'));

      expect(reply.content, kReplyFailedMessage);
    });

    test('stops tools that were still running', () {
      final reply = _placeholder();
      applyReplyEvent(reply, const ToolStarted(name: 'search'));

      failReply(reply);

      expect(reply.toolCalls.single.status, ToolCallStatus.error);
    });
  });
}
