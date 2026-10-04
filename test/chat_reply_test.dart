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

  test('a fallback does not replace reasoning that streamed', () {
    final reply = _placeholder();

    applyReplyEvent(reply, const ReasoningUpdated('Let me think.'));
    applyReplyEvent(
      reply,
      const ReasoningUpdated('Here is the answer', fallback: true),
    );

    expect(reply.reasoning, 'Let me think.');
  });

  test('a fallback does not repeat reply text that streamed', () {
    final reply = _placeholder();

    applyReplyEvent(reply, const ReplyDelta('Here is the answer'));
    applyReplyEvent(
      reply,
      const ReasoningUpdated('Here is the answer', fallback: true),
    );

    expect(reply.reasoning, isEmpty);
  });

  test('a fallback does not repeat reply text a checkpoint sealed', () {
    final reply = _placeholder();

    applyReplyEvent(reply, const ReplyDelta('Here is the answer'));
    applyReplyEvent(reply, const ReplyCheckpoint('Here is the answer'));
    applyReplyEvent(
      reply,
      const ReasoningUpdated('Here is the answer', fallback: true),
    );

    expect(reply.reasoning, isEmpty);
  });

  test('a fallback shows when nothing streamed', () {
    final reply = _placeholder();

    applyReplyEvent(
      reply,
      const ReasoningUpdated('Checking the logs', fallback: true),
    );

    expect(reply.reasoning, 'Checking the logs');
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

  test('a stopped reply with text is marked stopped', () {
    final reply = _placeholder();
    applyReplyEvent(reply, const ReplyDelta('Half an ans'));

    applyReplyEvent(reply, const ReplyCompleted('', stopped: true));

    expect(reply.stopped, isTrue);
  });

  test('a stopped reply with no text is not marked twice', () {
    final reply = _placeholder();

    applyReplyEvent(reply, const ReplyCompleted('', stopped: true));

    expect(reply.stopped, isFalse);
  });

  test('a completed reply is not marked stopped', () {
    final reply = _placeholder();
    applyReplyEvent(reply, const ReplyDelta('Done'));

    applyReplyEvent(reply, const ReplyCompleted(''));

    expect(reply.stopped, isFalse);
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

    expect(reply.content, 'Hel');
    expect(reply.error, 'Model unavailable');
    expect(reply.status, MessageStatus.error);
  });

  test('a failed completion with no text shows the fallback message', () {
    final reply = _placeholder();

    applyReplyEvent(reply, const ReplyCompleted('', failed: true));

    expect(reply.content, isEmpty);
    expect(reply.error, kReplyFailedMessage);
    expect(reply.status, MessageStatus.error);
  });

  test('a failed completion with no text keeps what streamed', () {
    final reply = _placeholder();
    applyReplyEvent(reply, const ReplyDelta('Partial'));

    applyReplyEvent(reply, const ReplyCompleted('', failed: true));

    expect(reply.content, 'Partial');
    expect(reply.error, kReplyFailedMessage);
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

        applyReplyEvent(reply, const ReplyCheckpoint('Hey there.'));

        expect(reply.sealedProse.single.text, 'Hey there.');
        expect(reply.content, isEmpty);
      },
    );

    test('text that never streamed is sealed from the checkpoint itself', () {
      final reply = _placeholder();

      applyReplyEvent(reply, const ReplyCheckpoint('A quick aside.'));

      expect(reply.sealedProse.single.text, 'A quick aside.');
    });

    test('a checkpoint longer than what streamed seals all of it', () {
      final reply = _placeholder();
      applyReplyEvent(reply, const ReplyDelta('Hey'));

      applyReplyEvent(reply, const ReplyCheckpoint('Hey there.'));

      expect(reply.sealedProse.single.text, 'Hey there.');
      expect(reply.content, isEmpty);
    });

    test('a checkpoint replaces streamed text it does not match', () {
      final reply = _placeholder();
      applyReplyEvent(reply, const ReplyDelta('<think>hm</think>Hey there.'));

      applyReplyEvent(reply, const ReplyCheckpoint('Hey there.'));

      expect(reply.sealedProse.single.text, 'Hey there.');
      expect(reply.content, isEmpty);
    });

    test('an empty checkpoint seals nothing', () {
      final reply = _placeholder();

      applyReplyEvent(reply, const ReplyCheckpoint(''));

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
    applyReplyEvent(reply, const ReasoningUpdated('Done', fallback: true));

    expect(reply.toolCalls.single.reasoning, 'Check the logs.');
    expect(reply.reasoning, 'Found it.');
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

  test('a finished tool closes the call with its id, not the first of its '
      'name', () {
    final reply = _placeholder();
    applyReplyEvent(reply, const ToolStarted(id: 'a', name: 'search'));
    applyReplyEvent(reply, const ToolStarted(id: 'b', name: 'search'));

    applyReplyEvent(
      reply,
      const ToolFinished(id: 'b', name: 'search', result: 'second'),
    );

    expect(reply.toolCalls.map((c) => c.status), [
      ToolCallStatus.running,
      ToolCallStatus.completed,
    ]);
    expect(reply.toolCalls.last.result, 'second');
  });

  test('a finished tool with an unknown id falls back to its name', () {
    final reply = _placeholder();
    applyReplyEvent(reply, const ToolStarted(name: 'search'));

    applyReplyEvent(reply, const ToolFinished(id: 'x', name: 'search'));

    expect(reply.toolCalls.single.status, ToolCallStatus.completed);
  });

  test('a started call keeps its id and arguments, and a finished one its '
      'result data, diff and duration', () {
    final reply = _placeholder();
    applyReplyEvent(
      reply,
      const ToolStarted(id: 'c1', name: 'patch', args: {'path': 'a.txt'}),
    );
    final started = reply.toolCalls.single;
    expect(started.id, 'c1');
    expect(started.args, {'path': 'a.txt'});
    expect(started.startedAt, isNotNull);

    applyReplyEvent(
      reply,
      const ToolFinished(
        id: 'c1',
        name: 'patch',
        resultData: {'success': true},
        diff: '+x',
        duration: Duration(milliseconds: 1500),
      ),
    );

    final done = reply.toolCalls.single;
    expect(done.resultData, {'success': true});
    expect(done.diff, '+x');
    expect(done.duration, const Duration(milliseconds: 1500));
    expect(done.args, {'path': 'a.txt'});
  });

  test('a finished call Hermes did not time is timed from its start', () {
    final reply = _placeholder();
    applyReplyEvent(reply, const ToolStarted(name: 'search'));

    applyReplyEvent(reply, const ToolFinished(name: 'search'));

    expect(reply.toolCalls.single.duration, isNotNull);
  });

  test('a call the model is still writing shows as preparing, and its start '
      'fills it in', () {
    final reply = _placeholder();
    applyReplyEvent(reply, const ReasoningUpdated('Look.'));

    applyReplyEvent(reply, const ToolPreparing('terminal'));
    expect(reply.toolCalls.single.preparing, isTrue);
    expect(reply.toolCalls.single.status, ToolCallStatus.running);
    expect(reply.toolCalls.single.reasoning, 'Look.');

    applyReplyEvent(
      reply,
      const ToolStarted(id: 't1', name: 'terminal', summary: 'ls'),
    );
    final call = reply.toolCalls.single;
    expect(call.preparing, isFalse);
    expect(call.id, 't1');
    expect(call.summary, 'ls');
    expect(call.reasoning, 'Look.');
    expect(call.startedAt, isNotNull);
  });

  test('a stopped reply cancels the calls still running', () {
    final reply = _placeholder();
    applyReplyEvent(reply, const ToolStarted(name: 'a'));
    applyReplyEvent(reply, const ToolFinished(name: 'a'));
    applyReplyEvent(reply, const ToolStarted(name: 'b'));

    applyReplyEvent(reply, const ReplyCompleted('', stopped: true));

    expect(reply.toolCalls.map((c) => c.status), [
      ToolCallStatus.completed,
      ToolCallStatus.cancelled,
    ]);
  });

  test('a call that never reported a start ran unreported when the reply '
      'ends normally', () {
    final reply = _placeholder();
    applyReplyEvent(reply, const ToolPreparing('memory'));

    applyReplyEvent(reply, const ReplyCompleted('Done'));

    expect(reply.toolCalls.single.status, ToolCallStatus.completed);
    expect(reply.toolCalls.single.preparing, isFalse);
  });

  test('a call that never started ends cancelled when the reply is '
      'stopped', () {
    final reply = _placeholder();
    applyReplyEvent(reply, const ToolPreparing('terminal'));

    applyReplyEvent(reply, const ReplyCompleted('', stopped: true));

    expect(reply.toolCalls.single.status, ToolCallStatus.cancelled);
  });

  test('a later call starting settles an earlier one that never reported', () {
    final reply = _placeholder();
    applyReplyEvent(reply, const ToolPreparing('memory'));
    applyReplyEvent(reply, const ToolPreparing('patch'));

    applyReplyEvent(reply, const ToolStarted(id: 'p', name: 'patch'));

    expect(reply.toolCalls.map((c) => (c.status, c.preparing)), [
      (ToolCallStatus.completed, false),
      (ToolCallStatus.running, false),
    ]);
  });

  test('a call starting that was never prepared settles earlier unreported '
      'ones too', () {
    final reply = _placeholder();
    applyReplyEvent(reply, const ToolPreparing('memory'));

    applyReplyEvent(reply, const ToolStarted(id: 't', name: 'terminal'));

    expect(reply.toolCalls.map((c) => (c.name, c.status, c.preparing)), [
      ('memory', ToolCallStatus.completed, false),
      ('terminal', ToolCallStatus.running, false),
    ]);
  });

  test('an interrupted call ends cancelled', () {
    final reply = _placeholder();
    applyReplyEvent(reply, const ToolStarted(id: 't', name: 'terminal'));

    applyReplyEvent(
      reply,
      const ToolFinished(id: 't', name: 'terminal', interrupted: true),
    );

    expect(reply.toolCalls.single.status, ToolCallStatus.cancelled);
  });

  group('text written before a tool call', () {
    test('is sealed once when Hermes checkpoints it after the call began', () {
      final reply = _placeholder();
      applyReplyEvent(reply, const ReplyDelta('Checking the box first. '));
      applyReplyEvent(reply, const ToolPreparing('terminal'));
      applyReplyEvent(reply, const ToolPreparing('terminal'));

      applyReplyEvent(reply, const ReplyCheckpoint('Checking the box first.'));

      expect(reply.sealedProse.map((p) => (p.text, p.beforeToolCall)), [
        ('Checking the box first.', 0),
      ]);
      expect(reply.content, isEmpty);
    });

    test('takes the checkpoint as its final form', () {
      final reply = _placeholder();
      applyReplyEvent(reply, const ReplyDelta('**Look** first'));
      applyReplyEvent(reply, const ToolPreparing('terminal'));

      applyReplyEvent(reply, const ReplyCheckpoint('Look first.'));

      expect(reply.sealedProse.single.text, 'Look first.');
    });

    test('keeps the fallback reasoning Hermes sends with it out', () {
      final reply = _placeholder();
      applyReplyEvent(reply, const ReplyDelta('Checking the box first.'));
      applyReplyEvent(reply, const ToolPreparing('terminal'));

      applyReplyEvent(
        reply,
        const ReasoningUpdated('Checking the box first.', fallback: true),
      );

      expect(reply.reasoning, isEmpty);
    });

    test('keeps the fallback reasoning out after its checkpoint too', () {
      final reply = _placeholder();
      applyReplyEvent(reply, const ReplyDelta('Checking.'));
      applyReplyEvent(reply, const ToolPreparing('terminal'));
      applyReplyEvent(reply, const ReplyCheckpoint('Checking.'));

      applyReplyEvent(
        reply,
        const ReasoningUpdated('Checking.', fallback: true),
      );
      applyReplyEvent(reply, const ToolStarted(name: 'terminal'));

      expect(reply.reasoning, isEmpty);
      expect(reply.toolCalls.single.reasoning, isEmpty);
      expect(reply.sealedProse.single.text, 'Checking.');
    });

    test('is not replaced by a checkpoint after a call ran', () {
      final reply = _placeholder();
      applyReplyEvent(reply, const ReplyDelta('First.'));
      applyReplyEvent(reply, const ToolPreparing('terminal'));
      applyReplyEvent(reply, const ToolStarted(name: 'terminal'));
      applyReplyEvent(reply, const ToolFinished(name: 'terminal'));

      applyReplyEvent(reply, const ReplyCheckpoint('Second.'));

      expect(reply.sealedProse.map((p) => p.text), ['First.', 'Second.']);
    });
  });

  group('an approval', () {
    test('goes on the running call of the tool it names', () {
      final reply = _placeholder();
      applyReplyEvent(reply, const ToolStarted(name: 'terminal'));
      applyReplyEvent(reply, const ToolStarted(name: 'browser'));

      applyReplyEvent(
        reply,
        const ApprovalRequested(
          ApprovalRequest(
            requestId: 'r1',
            command: 'x',
            description: '',
            choices: [],
            toolName: 'terminal',
          ),
        ),
      );

      final approval = reply.inputRequests.single as ApprovalRequest;
      expect(approval.toolCallIndex, 0);
    });

    test('that names no tool goes on the only call running', () {
      final reply = _placeholder();
      applyReplyEvent(reply, const ToolStarted(name: 'a'));
      applyReplyEvent(reply, const ToolFinished(name: 'a'));
      applyReplyEvent(reply, const ToolStarted(name: 'terminal'));

      applyReplyEvent(reply, const ApprovalRequested(_approval));

      final approval = reply.inputRequests.single as ApprovalRequest;
      expect(approval.toolCallIndex, 1);
    });

    test('stays on its own when it cannot be told which call asked', () {
      final reply = _placeholder();
      applyReplyEvent(reply, const ToolStarted(name: 'a'));
      applyReplyEvent(reply, const ToolStarted(name: 'b'));

      applyReplyEvent(reply, const ApprovalRequested(_approval));

      final approval = reply.inputRequests.single as ApprovalRequest;
      expect(approval.toolCallIndex, isNull);
    });

    test('keeps its call once answered', () {
      final reply = _placeholder();
      applyReplyEvent(reply, const ToolStarted(name: 'terminal'));
      applyReplyEvent(reply, const ApprovalRequested(_approval));

      recordApproval(reply, 'r1', 'once');

      final approval = reply.inputRequests.single as ApprovalRequest;
      expect(approval.choice, 'once');
      expect(approval.toolCallIndex, 0);
    });
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

  test('a vault request is added to the reply, pending', () {
    final reply = _placeholder();

    applyReplyEvent(
      reply,
      VaultRequested(
        const VaultRequest(
          requestId: 'srq-1',
          kind: VaultKind.saveLogin,
          origin: 'https://www.example.com',
          site: 'www.example.com',
        ),
      ),
    );

    expect(reply.inputRequests.single.status, InputRequestStatus.pending);
    expect(reply.awaitingInput, isTrue);
  });

  test('a vault answer is recorded, a decline is marked without values', () {
    final reply = _placeholder();
    applyReplyEvent(
      reply,
      VaultRequested(
        const VaultRequest(
          requestId: 'srq-1',
          kind: VaultKind.saveLogin,
          site: 'www.example.com',
        ),
      ),
    );

    recordVaultAnswered(reply, 'srq-1', identifier: 'ada@example.com');
    expect(reply.inputRequests.single.status, InputRequestStatus.answered);
    final answered = reply.inputRequests.single as VaultRequest;
    expect(answered.identifier, 'ada@example.com');
    expect(answered.provided, isTrue);
    // No secret is kept on the model: only the identifier travels with it.
    expect(answered.toString(), isNot(contains('pw')));

    final other = _placeholder();
    applyReplyEvent(
      other,
      VaultRequested(
        const VaultRequest(
          requestId: 'srq-1',
          kind: VaultKind.saveLogin,
          site: 'www.example.com',
        ),
      ),
    );
    recordVaultDeclined(other, 'srq-1');
    final declined = other.inputRequests.single as VaultRequest;
    expect(declined.status, InputRequestStatus.answered);
    expect(declined.identifier, isEmpty);
    expect(declined.provided, isFalse);
  });

  test('requests stack in the order they arrive', () {
    final reply = _placeholder();

    applyReplyEvent(reply, const ApprovalRequested(_approval));
    applyReplyEvent(reply, const ClarifyRequested(_clarify));

    expect(reply.inputRequests.map((r) => r.requestId), ['r1', 'r2']);
  });

  test('a request keeps its place among the tool calls', () {
    final reply = _placeholder();

    applyReplyEvent(reply, const ToolStarted(name: 'terminal'));
    applyReplyEvent(reply, const ApprovalRequested(_approval));
    applyReplyEvent(reply, const ToolFinished(name: 'terminal'));
    applyReplyEvent(reply, const ReasoningUpdated('It ran.'));
    applyReplyEvent(reply, const ToolStarted(name: 'clarify'));
    applyReplyEvent(reply, const ClarifyRequested(_clarify));

    expect(reply.inputRequestSlots, {
      'r1': (toolCalls: 1, sealed: 0),
      'r2': (toolCalls: 2, sealed: 0),
    });
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

      expect(reply.content, isEmpty);
      expect(reply.error, kReplyFailedMessage);
      expect(reply.status, MessageStatus.error);
    });

    test('keeps the text that had already streamed', () {
      final reply = _placeholder();
      applyReplyEvent(reply, const ReplyDelta('Half an ans'));

      failReply(reply);

      expect(reply.content, 'Half an ans');
      expect(reply.error, kReplyFailedMessage);
      expect(reply.status, MessageStatus.error);
    });

    test('explains a profile that no longer exists', () {
      final reply = _placeholder();

      failReply(reply, const ProfileUnavailableException());

      expect(reply.error, kProfileUnavailableMessage);
      expect(
        reply.error,
        'That profile is no longer available. Pick another one.',
      );
      expect(reply.status, MessageStatus.error);
    });

    test('shows the fallback for any other error', () {
      final reply = _placeholder();

      failReply(reply, Exception('socket closed'));

      expect(reply.error, kReplyFailedMessage);
    });

    test('stops tools that were still running', () {
      final reply = _placeholder();
      applyReplyEvent(reply, const ToolStarted(name: 'search'));

      failReply(reply);

      expect(reply.toolCalls.single.status, ToolCallStatus.error);
    });
  });
}
