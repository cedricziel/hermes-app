# Agent Input Requests Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user answer the agent's approval and clarify requests from inline cards in the chat, instead of the turn hanging until the backend times out.

**Architecture:** The Hermes gateway sends `approval.request` and `clarify.request` events on the `/api/ws` socket the chat already reads. They become new `ChatEvent`s, are folded into the assistant `ChatMessage` as a list of `InputRequest`s (like tool calls), mapped to a custom flyer message, and rendered as cards. Answers go back through two new `ChatTransport` methods that call `approval.respond` and `clarify.respond`.

**Tech Stack:** Flutter, Dart 3, `flutter_chat_ui` / `flutter_chat_core`, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-09-19-agent-input-requests-design.md`

## Global Constraints

- Run every command from the worktree root. Never `cd` elsewhere.
- Before each commit: `dart format lib test` and `flutter analyze` must be clean. CI also runs `dart format --output=none --set-exit-if-changed .`.
- Semantic commit messages, one concern per commit (`feat(chat): ...`, `test(chat): ...`). No "and" in a subject.
- No code comments unless they explain something the code cannot. Match the surrounding doc-comment style (`///` on public types).
- New behavior needs a test written first. Follow the patterns in `test/chat_reply_test.dart`, `test/hermes_gateway_transport_test.dart`, `test/chat_builders_test.dart` and `test/chat_streaming_test.dart`.
- `secret.request` and `sudo.request` stay ignored. Do not add them.
- Do not touch `packages/hermes_api` (generated client, never hand-edited).
- Answer wire formats: `approval.respond {session_id, request_id, choice}`; `clarify.respond {request_id, answer, question_id?}` with no session id; a multi-select answer is a JSON array encoded as a string. Verified against the Hermes source in `~/.hermes/hermes-agent/tui_gateway/`.

---

## File Structure

| File                                                                                                                                         | Change | Responsibility                                                                                                            |
| -------------------------------------------------------------------------------------------------------------------------------------------- | ------ | ------------------------------------------------------------------------------------------------------------------------- |
| `lib/src/chat/chat_models.dart`                                                                                                              | modify | `InputRequestStatus`, `InputRequest`, `ApprovalRequest`, `ClarifyQuestion`, `ClarifyRequest`; `ChatMessage.inputRequests` |
| `lib/src/chat/chat_transport.dart`                                                                                                           | modify | Three new events; two new interface methods                                                                               |
| `lib/src/chat/chat_reply.dart`                                                                                                               | modify | Fold requests into a reply; record answers; expire                                                                        |
| `lib/src/chat/chat_message_kinds.dart`                                                                                                       | modify | `kKindInputRequest`, `kMetaInputRequest`                                                                                  |
| `lib/src/chat/chat_message_mapper.dart`                                                                                                      | modify | One flyer message per request; hide thinking while waiting                                                                |
| `lib/src/chat/gateway/hermes_gateway_transport.dart`                                                                                         | modify | Map gateway events; `answerApproval`, `answerClarify`                                                                     |
| `lib/src/chat/widgets/input_card_frame.dart`                                                                                                 | create | Shared card surface and status note                                                                                       |
| `lib/src/chat/widgets/approval_card.dart`                                                                                                    | create | Approval card                                                                                                             |
| `lib/src/chat/widgets/clarify_card.dart`                                                                                                     | create | Clarify card (single and batch)                                                                                           |
| `lib/src/chat/widgets/chat_builders.dart`                                                                                                    | modify | Route `kKindInputRequest` to the cards                                                                                    |
| `lib/src/chat/chat_screen.dart`                                                                                                              | modify | Handle new events; send answers; record outcome                                                                           |
| `test/support/fake_chat_transport.dart`                                                                                                      | modify | Record answers                                                                                                            |
| `test/chat_reply_test.dart`, `test/chat_message_mapper_test.dart`, `test/hermes_gateway_transport_test.dart`, `test/chat_builders_test.dart` | modify | Tests per task                                                                                                            |
| `test/approval_card_test.dart`, `test/clarify_card_test.dart`, `test/chat_input_request_test.dart`                                           | create | Card and screen tests                                                                                                     |

---

### Task 1: Request model, events and reply folding

**Files:**

- Modify: `lib/src/chat/chat_models.dart`
- Modify: `lib/src/chat/chat_transport.dart`
- Modify: `lib/src/chat/chat_reply.dart`
- Modify: `lib/src/chat/chat_screen.dart:411`
- Test: `test/chat_reply_test.dart`

**Interfaces:**

- Produces (used by every later task):
  - `enum InputRequestStatus { pending, answered, expired }`
  - `sealed class InputRequest { String requestId; InputRequestStatus status; InputRequest withStatus(InputRequestStatus) }`
  - `final class ApprovalRequest extends InputRequest` with `String command`, `String description`, `List<String> choices`, `String? choice`, `ApprovalRequest answered(String choice)`
  - `class ClarifyQuestion { String qid; String question; List<String> choices; bool multiSelect }`
  - `final class ClarifyRequest extends InputRequest` with `List<ClarifyQuestion> questions`, `bool batch`, `Map<String, List<String>> answers`, `ClarifyRequest answeredWith(Map<String, List<String>> answers)`
  - `ChatMessage.inputRequests` (`List<InputRequest>`, default `const []`) and `bool get awaitingInput`
  - Events `ApprovalRequested(ApprovalRequest request)`, `ClarifyRequested(ClarifyRequest request)`, `InputRequestExpired(String requestId)`
  - In `chat_reply.dart`: `recordApproval(ChatMessage, String requestId, String choice)`, `recordClarifyAnswers(ChatMessage, String requestId, Map<String, List<String>> answers)`, `expireInputRequests(ChatMessage, {String? requestId})`

- [ ] **Step 1: Write the failing tests**

Add these imports if missing and tests to `test/chat_reply_test.dart` (inside `main()`, using the existing `_placeholder()` helper):

```dart
const _approval = ApprovalRequest(
  requestId: 'r1',
  command: 'rm -rf build',
  description: 'delete files',
  choices: ['once', 'session', 'deny'],
);

const _clarify = ClarifyRequest(
  requestId: 'r2',
  questions: [
    ClarifyQuestion(qid: '', question: 'Which colour?', choices: ['red', 'blue']),
  ],
);

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

  test('an answered request is not expired later', () {
    final reply = _placeholder();
    applyReplyEvent(reply, const ApprovalRequested(_approval));
    recordApproval(reply, 'r1', 'deny');

    applyReplyEvent(reply, const ReplyCompleted('Done'));

    expect(reply.inputRequests.single.status, InputRequestStatus.answered);
  });
```

Put the two `const` declarations at top level, above `main()`, next to `_placeholder()`. The tests go inside `main()`.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/chat_reply_test.dart`
Expected: compile error, `ApprovalRequest` / `ApprovalRequested` / `inputRequests` not defined.

- [ ] **Step 3: Add the model to `lib/src/chat/chat_models.dart`**

Add after `ToolCallStatus`/`ToolCall` (before `ChatMessage`):

```dart
enum InputRequestStatus { pending, answered, expired }

/// Something the agent asked the user mid-turn and is waiting on.
sealed class InputRequest {
  const InputRequest({
    required this.requestId,
    this.status = InputRequestStatus.pending,
  });

  final String requestId;
  final InputRequestStatus status;

  InputRequest withStatus(InputRequestStatus status);
}

/// The agent wants to run something that needs the user's consent.
final class ApprovalRequest extends InputRequest {
  const ApprovalRequest({
    required super.requestId,
    required this.command,
    required this.description,
    required this.choices,
    super.status,
    this.choice,
  });

  final String command;
  final String description;

  /// What the agent lets the user pick: some of `once`, `session`, `always`,
  /// and `deny`.
  final List<String> choices;

  /// What the user picked, once answered.
  final String? choice;

  ApprovalRequest answered(String choice) => ApprovalRequest(
    requestId: requestId,
    command: command,
    description: description,
    choices: choices,
    status: InputRequestStatus.answered,
    choice: choice,
  );

  @override
  ApprovalRequest withStatus(InputRequestStatus status) => ApprovalRequest(
    requestId: requestId,
    command: command,
    description: description,
    choices: choices,
    status: status,
    choice: choice,
  );
}

class ClarifyQuestion {
  const ClarifyQuestion({
    required this.qid,
    required this.question,
    this.choices = const [],
    this.multiSelect = false,
  });

  /// Empty for the single-question form, which has no ids.
  final String qid;
  final String question;

  /// Empty means the question is open-ended.
  final List<String> choices;
  final bool multiSelect;
}

/// The agent asks one question, or a batch of them, and waits for answers.
final class ClarifyRequest extends InputRequest {
  const ClarifyRequest({
    required super.requestId,
    required this.questions,
    this.batch = false,
    super.status,
    this.answers = const {},
  });

  final List<ClarifyQuestion> questions;

  /// Whether the gateway wants one answer per `qid` instead of a single one.
  final bool batch;

  /// The values given per `qid`, once answered. Empty when the user skipped.
  final Map<String, List<String>> answers;

  ClarifyRequest answeredWith(Map<String, List<String>> answers) =>
      ClarifyRequest(
        requestId: requestId,
        questions: questions,
        batch: batch,
        status: InputRequestStatus.answered,
        answers: answers,
      );

  @override
  ClarifyRequest withStatus(InputRequestStatus status) => ClarifyRequest(
    requestId: requestId,
    questions: questions,
    batch: batch,
    status: status,
    answers: answers,
  );
}
```

In `ChatMessage`, add the constructor parameter `this.inputRequests = const [],`, the field, and the getter:

```dart
  List<InputRequest> inputRequests;

  bool get awaitingInput =>
      inputRequests.any((r) => r.status == InputRequestStatus.pending);
```

- [ ] **Step 4: Add the events to `lib/src/chat/chat_transport.dart`**

Add `import 'chat_models.dart';` directly after `library;` (blank line between), then, after `ThreadTitled`:

```dart
/// The agent is waiting for the user's consent to run something.
final class ApprovalRequested extends ChatEvent {
  const ApprovalRequested(this.request);

  final ApprovalRequest request;
}

/// The agent is waiting for the user to answer one or more questions.
final class ClarifyRequested extends ChatEvent {
  const ClarifyRequested(this.request);

  final ClarifyRequest request;
}

/// The gateway gave up waiting on request [requestId].
final class InputRequestExpired extends ChatEvent {
  const InputRequestExpired(this.requestId);

  final String requestId;
}
```

- [ ] **Step 5: Fold the requests in `lib/src/chat/chat_reply.dart`**

In `applyReplyEvent`, add these cases before the final `ReplyStarted() || ...` case, and call `expireInputRequests(reply);` at the end of the `ReplyCompleted` case:

```dart
    case ApprovalRequested(:final request):
      reply.inputRequests = [...reply.inputRequests, request];
    case ClarifyRequested(:final request):
      reply.inputRequests = [...reply.inputRequests, request];
    case InputRequestExpired(:final requestId):
      expireInputRequests(reply, requestId: requestId);
```

In `failReply`, add `expireInputRequests(reply);` after `_settleRunningTools(...)`.

Add below `failReply`:

```dart
void recordApproval(ChatMessage reply, String requestId, String choice) =>
    _editPending(
      reply,
      requestId,
      (r) => r is ApprovalRequest ? r.answered(choice) : r,
    );

void recordClarifyAnswers(
  ChatMessage reply,
  String requestId,
  Map<String, List<String>> answers,
) => _editPending(
  reply,
  requestId,
  (r) => r is ClarifyRequest ? r.answeredWith(answers) : r,
);

/// Ends the pending requests of [reply], or only [requestId] when given.
void expireInputRequests(ChatMessage reply, {String? requestId}) =>
    _editPending(
      reply,
      requestId,
      (r) => r.withStatus(InputRequestStatus.expired),
    );

void _editPending(
  ChatMessage reply,
  String? requestId,
  InputRequest Function(InputRequest) edit,
) {
  reply.inputRequests = [
    for (final r in reply.inputRequests)
      r.status == InputRequestStatus.pending &&
              (requestId == null || r.requestId == requestId)
          ? edit(r)
          : r,
  ];
}
```

- [ ] **Step 6: Keep the screen compiling**

In `lib/src/chat/chat_screen.dart`, `_onReplyEvent`, extend the case that calls `_updateReply`:

```dart
      case ReplyDelta() ||
          ToolStarted() ||
          ToolFinished() ||
          ReplyCompleted() ||
          ApprovalRequested() ||
          ClarifyRequested() ||
          InputRequestExpired():
        _updateReply(thread, reply, () => applyReplyEvent(reply, event));
```

- [ ] **Step 7: Run tests and analysis**

Run: `dart format lib test && flutter analyze && flutter test test/chat_reply_test.dart`
Expected: analyze clean; all `chat_reply_test.dart` tests PASS.

- [ ] **Step 8: Commit**

```bash
git add lib test
git commit -m "feat(chat): track agent input requests on the reply"
```

---

### Task 2: Map requests to transcript messages

**Files:**

- Modify: `lib/src/chat/chat_message_kinds.dart`
- Modify: `lib/src/chat/chat_message_mapper.dart`
- Test: `test/chat_message_mapper_test.dart`

**Interfaces:**

- Consumes: `ChatMessage.inputRequests`, `ChatMessage.awaitingInput`, `ApprovalRequest` (Task 1).
- Produces: `const String kKindInputRequest = 'input_request'`, `const String kMetaInputRequest = 'request'`. Each request maps to a `CustomMessage` with id `<message id>-input-<n>` and metadata `{kMetaKind: kKindInputRequest, kMetaInputRequest: <the InputRequest object>}`. Order: tool calls, requests, text, thinking. The thinking message is omitted while a request is pending.

- [ ] **Step 1: Write the failing tests**

In `test/chat_message_mapper_test.dart`, extend the local `message(...)` helper with `List<InputRequest> inputRequests = const [],` (pass it as `inputRequests: inputRequests`), then add inside `group('chatMessageToFlyer', ...)`:

```dart
    const approval = ApprovalRequest(
      requestId: 'r1',
      command: 'rm -rf build',
      description: 'delete files',
      choices: ['once', 'deny'],
    );

    test('emits a custom message per input request, after tool calls', () {
      final out = chatMessageToFlyer(
        message(
          content: '',
          toolCalls: const [ToolCall(name: 'shell', summary: 'ls')],
          inputRequests: const [approval],
        ),
      );

      expect(out.map((m) => m.id), ['m1-tool-0', 'm1-input-0']);
      final card = out.last as CustomMessage;
      expect(card.metadata, {
        kMetaKind: kKindInputRequest,
        kMetaInputRequest: approval,
      });
    });

    test('hides the thinking indicator while a request is pending', () {
      final out = chatMessageToFlyer(
        message(
          content: '',
          status: MessageStatus.thinking,
          inputRequests: const [approval],
        ),
      );

      expect(out.map((m) => m.id), ['m1-input-0']);
    });

    test('shows the thinking indicator again once the request is answered', () {
      final out = chatMessageToFlyer(
        message(
          content: '',
          status: MessageStatus.thinking,
          inputRequests: [approval.answered('once')],
        ),
      );

      expect(out.map((m) => m.id), ['m1-input-0', 'm1-thinking']);
    });
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/chat_message_mapper_test.dart`
Expected: compile error, `kKindInputRequest` not defined.

- [ ] **Step 3: Add the constants**

In `lib/src/chat/chat_message_kinds.dart`, after `kKindThinking`:

```dart
const String kKindInputRequest = 'input_request';
```

and after `kMetaToolStatus`, extend the doc sentence and add the key. Replace the trailing doc block with:

```dart
/// Metadata keys. A `kKindToolCall` message carries `name` (String),
/// `summary` (String) and `status` (`ToolCallStatus.name`). A
/// `kKindInputRequest` message carries `request` (the `InputRequest`).
const String kMetaKind = 'kind';
const String kMetaToolName = 'name';
const String kMetaToolSummary = 'summary';
const String kMetaToolStatus = 'status';
const String kMetaInputRequest = 'request';
```

- [ ] **Step 4: Update the mapper**

In `lib/src/chat/chat_message_mapper.dart`, change the first line of the doc comment to `/// Tool calls come first, then input requests, the text, and the thinking` with the second line `/// indicator.` (keep the rest). The text keeps its existing rule (a thinking message shows no text), so add a second flag next to `thinking` for the indicator only:

```dart
  final thinking = m.status == MessageStatus.thinking;
  final showThinking = thinking && !m.awaitingInput;
```

Use `showThinking` in place of `thinking` on the `if (...) CustomMessage(id: '${m.id}-thinking', ...)` entry. Then insert this between the tool-call loop and the text entry:

```dart
    for (final (i, request) in m.inputRequests.indexed)
      CustomMessage(
        id: '${m.id}-input-$i',
        authorId: authorId,
        createdAt: createdAt,
        metadata: {kMetaKind: kKindInputRequest, kMetaInputRequest: request},
      ),
```

- [ ] **Step 5: Run tests and analysis**

Run: `dart format lib test && flutter analyze && flutter test test/chat_message_mapper_test.dart test/chat_controller_sync_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib test
git commit -m "feat(chat): map input requests to transcript messages"
```

---

### Task 3: Gateway events and answer calls

**Files:**

- Modify: `lib/src/chat/chat_transport.dart` (interface)
- Modify: `lib/src/chat/gateway/hermes_gateway_transport.dart`
- Modify: `test/support/fake_chat_transport.dart`
- Test: `test/hermes_gateway_transport_test.dart`

**Interfaces:**

- Consumes: events and model from Task 1.
- Produces, on `ChatTransport` (and both implementations):
  - `Future<bool> answerApproval(String requestId, String choice)`
  - `Future<bool> answerClarify(String requestId, List<String> values, {String? questionId, bool multiSelect = false})`
  - Both return `false` when the request is no longer pending, and throw when the call fails.
  - `FakeChatTransport` records `approvalAnswers` (`List<(String, String)>`) and `clarifyAnswers` (`List<({String requestId, List<String> values, String? questionId, bool multiSelect})>`), and has `bool accepts = true` and `Object? answerError`.

- [ ] **Step 1: Extend the fake gateway in the test**

In `test/hermes_gateway_transport_test.dart`, `FakeGateway`: add fields

```dart
  /// How many approvals `approval.respond` reports resolved.
  int approvalsResolved = 1;

  /// The `status` `clarify.respond` reports.
  String clarifyStatus = 'ok';
```

and cases in `_onFrame`'s `switch (request['method'])`, before the `'prompt.submit'` cases:

```dart
      case 'approval.respond':
        _send({
          'id': id,
          'result': {'resolved': approvalsResolved},
        });
      case 'clarify.respond':
        _send({
          'id': id,
          'result': {'status': clarifyStatus},
        });
```

- [ ] **Step 2: Write the failing tests**

Add to `main()` (payloads copied from `tui_gateway/server.py`):

```dart
  group('agent input requests', () {
    const approvalPayload = {
      'request_id': 'r1',
      'command': 'rm -rf build',
      'description': 'delete files',
      'choices': ['once', 'session', 'deny'],
    };

    test('an approval request becomes an event', () async {
      gateway.turn = (g, sid) {
        g.event('approval.request', sid, approvalPayload);
        g.event('message.complete', sid, {'text': 'ok', 'status': 'complete'});
      };

      final events = await reply();

      final request = events.whereType<ApprovalRequested>().single.request;
      expect(request.requestId, 'r1');
      expect(request.command, 'rm -rf build');
      expect(request.description, 'delete files');
      expect(request.choices, ['once', 'session', 'deny']);
    });

    test('a single clarify question becomes a one-question request', () async {
      gateway.turn = (g, sid) {
        g.event('clarify.request', sid, {
          'request_id': 'r2',
          'question': 'Which colour?',
          'choices': ['red', 'blue'],
        });
        g.event('message.complete', sid, {'text': 'ok', 'status': 'complete'});
      };

      final events = await reply();

      final request = events.whereType<ClarifyRequested>().single.request;
      expect(request.batch, isFalse);
      expect(request.questions.single.qid, '');
      expect(request.questions.single.question, 'Which colour?');
      expect(request.questions.single.choices, ['red', 'blue']);
      expect(request.questions.single.multiSelect, isFalse);
    });

    test('an open-ended multi-select batch keeps each question', () async {
      gateway.turn = (g, sid) {
        g.event('clarify.request', sid, {
          'request_id': 'r3',
          'questions': [
            {'qid': 'a', 'question': 'Name?', 'choices': null, 'multi_select': false},
            {
              'qid': 'b',
              'question': 'Toppings?',
              'choices': ['ham', 'olives'],
              'multi_select': true,
            },
          ],
        });
        g.event('message.complete', sid, {'text': 'ok', 'status': 'complete'});
      };

      final events = await reply();

      final request = events.whereType<ClarifyRequested>().single.request;
      expect(request.batch, isTrue);
      expect(request.questions.map((q) => q.qid), ['a', 'b']);
      expect(request.questions[0].choices, isEmpty);
      expect(request.questions[1].multiSelect, isTrue);
    });

    test('an expire event becomes InputRequestExpired', () async {
      gateway.turn = (g, sid) {
        g.event('clarify.expire', sid, {'request_id': 'r2'});
        g.event('message.complete', sid, {'text': 'ok', 'status': 'complete'});
      };

      final events = await reply();

      expect(events.whereType<InputRequestExpired>().single.requestId, 'r2');
    });

    /// Runs a turn that raises [payload] as [event], calls [answer] on the
    /// transport while the turn waits, then completes the turn.
    Future<T> answerWhileWaiting<T>(
      String event,
      Map<String, Object?> payload,
      Future<T> Function() answer,
    ) async {
      gateway.turn = (g, sid) => g.event(event, sid, payload);
      final done = Completer<void>();
      late T result;
      transport.send(text: 'hi').listen((e) async {
        if (e is ApprovalRequested || e is ClarifyRequested) {
          result = await answer();
          gateway.event('message.complete', 'rt-1', {
            'text': 'ok',
            'status': 'complete',
          });
        }
      }, onDone: done.complete);
      await done.future;
      return result;
    }

    test('an approval is answered on the runtime session', () async {
      final accepted = await answerWhileWaiting(
        'approval.request',
        approvalPayload,
        () => transport.answerApproval('r1', 'once'),
      );

      expect(accepted, isTrue);
      expect(gateway.requestOf('approval.respond')['params'], {
        'session_id': 'rt-1',
        'request_id': 'r1',
        'choice': 'once',
      });
    });

    test('an approval nothing is waiting on reports not accepted', () async {
      gateway.approvalsResolved = 0;

      final accepted = await answerWhileWaiting(
        'approval.request',
        approvalPayload,
        () => transport.answerApproval('r1', 'once'),
      );

      expect(accepted, isFalse);
    });

    test('an approval for an unknown request sends nothing', () async {
      expect(await transport.answerApproval('nope', 'once'), isFalse);
      expect(gateway.requests, isEmpty);
    });

    test('a clarify answer carries the request id and no session', () async {
      final accepted = await answerWhileWaiting(
        'clarify.request',
        {'request_id': 'r2', 'question': 'Which colour?'},
        () => transport.answerClarify('r2', ['blue']),
      );

      expect(accepted, isTrue);
      expect(gateway.requestOf('clarify.respond')['params'], {
        'request_id': 'r2',
        'answer': 'blue',
      });
    });

    test('a batch answer names its question', () async {
      await answerWhileWaiting(
        'clarify.request',
        {'request_id': 'r3', 'questions': <Object?>[]},
        () => transport.answerClarify('r3', ['ham'], questionId: 'b'),
      );

      expect(
        (gateway.requestOf('clarify.respond')['params']
            as Map)['question_id'],
        'b',
      );
    });

    test('a multi-select answer is a JSON array in a string', () async {
      await answerWhileWaiting(
        'clarify.request',
        {'request_id': 'r2', 'question': 'Toppings?', 'multi_select': true},
        () => transport.answerClarify('r2', ['ham', 'olives'], multiSelect: true),
      );

      expect(
        (gateway.requestOf('clarify.respond')['params'] as Map)['answer'],
        '["ham","olives"]',
      );
    });

    test('skipping sends an empty answer', () async {
      await answerWhileWaiting(
        'clarify.request',
        {'request_id': 'r2', 'question': 'Which colour?'},
        () => transport.answerClarify('r2', const []),
      );

      expect(
        (gateway.requestOf('clarify.respond')['params'] as Map)['answer'],
        '',
      );
    });

    test('an expired clarify request reports not accepted', () async {
      gateway.clarifyStatus = 'expired';

      final accepted = await answerWhileWaiting(
        'clarify.request',
        {'request_id': 'r2', 'question': 'Which colour?'},
        () => transport.answerClarify('r2', ['blue']),
      );

      expect(accepted, isFalse);
    });
  });
```

- [ ] **Step 3: Run to verify it fails**

Run: `flutter test test/hermes_gateway_transport_test.dart`
Expected: compile error, `answerApproval` not defined on `HermesGatewayTransport`.

- [ ] **Step 4: Add the interface methods**

In `lib/src/chat/chat_transport.dart`, inside `ChatTransport`, before `close()`:

```dart
  /// Answers an approval the agent is waiting on with one of its choices.
  /// Returns false when the request is no longer pending, and throws when the
  /// call itself fails.
  Future<bool> answerApproval(String requestId, String choice);

  /// Answers a clarify request, or one question of a batch when [questionId]
  /// is given. An empty [values] skips: without a [questionId] that cancels the
  /// whole request. Returns false when the request is no longer pending, and
  /// throws when the call itself fails.
  Future<bool> answerClarify(
    String requestId,
    List<String> values, {
    String? questionId,
    bool multiSelect = false,
  });
```

- [ ] **Step 5: Implement them in the gateway transport**

In `lib/src/chat/gateway/hermes_gateway_transport.dart`:

Add `import 'dart:convert';` and `import '../chat_models.dart';` (alphabetical, with the other imports). Add a field:

```dart
  final _requestSessions = <String, String>{};
```

In `send`, right after `if (mapped == null) continue;` add:

```dart
        if (mapped is ApprovalRequested) {
          _requestSessions[mapped.request.requestId] = runtimeId;
        }
```

and in the `finally` block add `_requestSessions.removeWhere((_, sid) => sid == runtimeId);` before the `await subscription.cancel();` line.

Add the two methods before `close()`:

```dart
  @override
  Future<bool> answerApproval(String requestId, String choice) async {
    final sessionId = _requestSessions[requestId];
    if (sessionId == null) return false;
    final client = await _client();
    final result = await client.request('approval.respond', {
      'session_id': sessionId,
      'request_id': requestId,
      'choice': choice,
    });
    return ((result['resolved'] as num?) ?? 0) > 0;
  }

  @override
  Future<bool> answerClarify(
    String requestId,
    List<String> values, {
    String? questionId,
    bool multiSelect = false,
  }) async {
    final client = await _client();
    final result = await client.request('clarify.respond', {
      'request_id': requestId,
      'answer': multiSelect
          ? jsonEncode(values)
          : (values.isEmpty ? '' : values.first),
      'question_id': ?questionId,
    });
    return result['status'] != 'expired';
  }
```

(`'question_id': ?questionId` is Dart's null-aware map entry; it needs SDK 3.8+, this repo is on ^3.13.)

In `_toChatEvent`, add before `_ => null`:

```dart
      'approval.request' => ApprovalRequested(
        ApprovalRequest(
          requestId: text('request_id'),
          command: text('command'),
          description: text('description'),
          choices: _strings(payload['choices']),
        ),
      ),
      'clarify.request' => ClarifyRequested(_toClarify(payload)),
      'approval.expire' ||
      'clarify.expire' => InputRequestExpired(text('request_id')),
```

and add these helpers at the end of the class:

```dart
  ClarifyRequest _toClarify(Map<String, Object?> payload) {
    final requestId = payload['request_id'] as String? ?? '';
    final batch = payload['questions'];
    if (batch is List) {
      return ClarifyRequest(
        requestId: requestId,
        batch: true,
        questions: [
          for (final q in batch.whereType<Map<String, Object?>>())
            _toQuestion(q),
        ],
      );
    }
    return ClarifyRequest(requestId: requestId, questions: [_toQuestion(payload)]);
  }

  ClarifyQuestion _toQuestion(Map<String, Object?> q) => ClarifyQuestion(
    qid: q['qid'] as String? ?? '',
    question: q['question'] as String? ?? '',
    choices: _strings(q['choices']),
    multiSelect: q['multi_select'] == true,
  );

  List<String> _strings(Object? value) => value is List
      ? [
          for (final item in value)
            if (item is String) item,
        ]
      : const [];
```

If the event payload's nested maps decode as `Map<String, dynamic>`, `whereType<Map<String, Object?>>()` still matches (dynamic is compatible). If a test shows an empty question list, switch to `whereType<Map>()` and `.cast<String, Object?>()`.

- [ ] **Step 6: Update the fake transport**

In `test/support/fake_chat_transport.dart`, add to `FakeChatTransport`:

```dart
  final approvalAnswers = <(String, String)>[];
  final clarifyAnswers =
      <({String requestId, List<String> values, String? questionId, bool multiSelect})>[];

  /// What the answer calls report; false means the request is gone.
  bool accepts = true;

  /// When set, the answer calls throw it.
  Object? answerError;

  @override
  Future<bool> answerApproval(String requestId, String choice) async {
    if (answerError case final error?) throw error;
    approvalAnswers.add((requestId, choice));
    return accepts;
  }

  @override
  Future<bool> answerClarify(
    String requestId,
    List<String> values, {
    String? questionId,
    bool multiSelect = false,
  }) async {
    if (answerError case final error?) throw error;
    clarifyAnswers.add((
      requestId: requestId,
      values: values,
      questionId: questionId,
      multiSelect: multiSelect,
    ));
    return accepts;
  }
```

- [ ] **Step 7: Run tests and analysis**

Run: `dart format lib test && flutter analyze && flutter test test/hermes_gateway_transport_test.dart test/chat_streaming_test.dart`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib test
git commit -m "feat(chat): receive and answer input requests over the gateway"
```

---

### Task 4: Approval and clarify cards

**Files:**

- Create: `lib/src/chat/widgets/input_card_frame.dart`
- Create: `lib/src/chat/widgets/approval_card.dart`
- Create: `lib/src/chat/widgets/clarify_card.dart`
- Modify: `lib/src/chat/widgets/chat_builders.dart`
- Test: `test/approval_card_test.dart`, `test/clarify_card_test.dart`, `test/chat_builders_test.dart`

**Interfaces:**

- Consumes: `ApprovalRequest`, `ClarifyRequest`, `ClarifyQuestion`, `InputRequestStatus` (Task 1); `kKindInputRequest`, `kMetaInputRequest` (Task 2).
- Produces:
  - `ApprovalCard({required ApprovalRequest request, Future<void> Function(String choice)? onAnswer})`
  - `ClarifyCard({required ClarifyRequest request, Future<void> Function(Map<String, List<String>> answers)? onAnswer})`. An empty map means skip.
  - `buildChatBuilders({..., Future<void> Function(String requestId, String choice)? onAnswerApproval, Future<void> Function(String requestId, Map<String, List<String>> answers)? onAnswerClarify})`
  - Cards keep no answer state of their own beyond drafts: an answered or expired request is rendered from `request.status`.
  - `onAnswer` throwing means the call failed: the card re-enables and shows "Could not send your answer. Try again."

- [ ] **Step 1: Write the failing approval card tests**

Create `test/approval_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/widgets/approval_card.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

const _request = ApprovalRequest(
  requestId: 'r1',
  command: 'rm -rf build',
  description: 'delete the build folder',
  choices: ['once', 'session', 'always', 'deny'],
);

Future<void> _pump(
  WidgetTester tester,
  ApprovalRequest request, {
  Future<void> Function(String)? onAnswer,
}) => tester.pumpWidget(
  MaterialApp(
    theme: buildHermesLightTheme(),
    home: Scaffold(body: ApprovalCard(request: request, onAnswer: onAnswer)),
  ),
);

void main() {
  testWidgets('shows the description, the command and one button per choice', (
    tester,
  ) async {
    await _pump(tester, _request, onAnswer: (_) async {});

    expect(find.text('delete the build folder'), findsOneWidget);
    expect(find.text('rm -rf build'), findsOneWidget);
    for (final label in [
      'Allow once',
      'Allow for session',
      'Always allow',
      'Deny',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('offers only the choices the agent allows', (tester) async {
    const limited = ApprovalRequest(
      requestId: 'r1',
      command: 'x',
      description: 'y',
      choices: ['once', 'deny'],
    );

    await _pump(tester, limited, onAnswer: (_) async {});

    expect(find.text('Always allow'), findsNothing);
    expect(find.text('Allow for session'), findsNothing);
  });

  testWidgets('a tap sends the choice', (tester) async {
    final sent = <String>[];
    await _pump(tester, _request, onAnswer: (c) async => sent.add(c));

    await tester.tap(find.text('Allow once'));
    await tester.pump();

    expect(sent, ['once']);
  });

  testWidgets('always allow asks first and sends nothing on cancel', (
    tester,
  ) async {
    final sent = <String>[];
    await _pump(tester, _request, onAnswer: (c) async => sent.add(c));

    await tester.tap(find.text('Always allow'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(sent, isEmpty);
  });

  testWidgets('always allow sends once confirmed', (tester) async {
    final sent = <String>[];
    await _pump(tester, _request, onAnswer: (c) async => sent.add(c));

    await tester.tap(find.text('Always allow'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes, always allow'));
    await tester.pumpAndSettle();

    expect(sent, ['always']);
  });

  testWidgets('buttons are disabled while the answer is in flight', (
    tester,
  ) async {
    var calls = 0;
    await _pump(
      tester,
      _request,
      onAnswer: (_) {
        calls++;
        return Future<void>.delayed(const Duration(seconds: 1));
      },
    );

    await tester.tap(find.text('Allow once'));
    await tester.pump();
    await tester.tap(find.text('Allow once'), warnIfMissed: false);
    await tester.pump();

    expect(calls, 1);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a failed answer shows an error and can be retried', (
    tester,
  ) async {
    var calls = 0;
    await _pump(
      tester,
      _request,
      onAnswer: (_) async {
        calls++;
        if (calls == 1) throw Exception('socket closed');
      },
    );

    await tester.tap(find.text('Allow once'));
    await tester.pump();

    expect(find.text('Could not send your answer. Try again.'), findsOneWidget);

    await tester.tap(find.text('Allow once'));
    await tester.pump();

    expect(calls, 2);
    expect(find.text('Could not send your answer. Try again.'), findsNothing);
  });

  testWidgets('an answered request shows the outcome and no buttons', (
    tester,
  ) async {
    await _pump(tester, _request.answered('deny'), onAnswer: (_) async {});

    expect(find.text('Denied'), findsOneWidget);
    expect(find.text('Allow once'), findsNothing);
  });

  testWidgets('an expired request says so and has no buttons', (tester) async {
    await _pump(
      tester,
      _request.withStatus(InputRequestStatus.expired),
      onAnswer: (_) async {},
    );

    expect(find.text('This request timed out'), findsOneWidget);
    expect(find.text('Allow once'), findsNothing);
  });

  testWidgets('without a handler the buttons are disabled', (tester) async {
    await _pump(tester, _request);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Allow once'),
    );
    expect(button.onPressed, isNull);
  });
}
```

Note: `FilledButton.tonal` builds a `FilledButton`, so `find.widgetWithText(FilledButton, ...)` finds it.

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/approval_card_test.dart`
Expected: compile error, `approval_card.dart` not found.

- [ ] **Step 3: Create the shared frame**

`lib/src/chat/widgets/input_card_frame.dart`:

```dart
import 'package:flutter/material.dart';

import '../../theme/hermes_theme.dart';

/// The bordered surface the approval and clarify cards share, styled like the
/// tool call card.
class InputCardFrame extends StatelessWidget {
  const InputCardFrame({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// A one-line status under a card's content: the outcome, a timeout or an
/// error.
class InputCardNote extends StatelessWidget {
  const InputCardNote(this.text, {super.key, this.error = false});

  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          color: error ? scheme.error : context.hermesColors.subtleText,
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Create the approval card**

`lib/src/chat/widgets/approval_card.dart`:

```dart
import 'package:flutter/material.dart';

import '../chat_models.dart';
import 'input_card_frame.dart';

const _labels = {
  'once': 'Allow once',
  'session': 'Allow for session',
  'always': 'Always allow',
  'deny': 'Deny',
};

const _outcomes = {
  'once': 'Allowed once',
  'session': 'Allowed for this session',
  'always': 'Always allowed',
  'deny': 'Denied',
};

const kAnswerFailedMessage = 'Could not send your answer. Try again.';

/// The agent wants to run something and waits for the user to allow or deny
/// it. Once answered or expired the buttons give way to the outcome.
class ApprovalCard extends StatefulWidget {
  const ApprovalCard({super.key, required this.request, this.onAnswer});

  final ApprovalRequest request;

  /// Sends the choice. Throwing means it did not go through. Without one the
  /// buttons are disabled.
  final Future<void> Function(String choice)? onAnswer;

  @override
  State<ApprovalCard> createState() => _ApprovalCardState();
}

class _ApprovalCardState extends State<ApprovalCard> {
  var _busy = false;
  String? _error;

  Future<void> _choose(String choice) async {
    if (_busy) return;
    if (choice == 'always' && !await _confirmAlways()) return;
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onAnswer!(choice);
    } catch (_) {
      if (mounted) setState(() => _error = kAnswerFailedMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmAlways() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Always allow this?'),
        content: const Text(
          'Hermes will run matching commands without asking again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, always allow'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Widget _button(String choice) {
    final onPressed = _busy || widget.onAnswer == null
        ? null
        : () => _choose(choice);
    final label = Text(_labels[choice] ?? choice);
    return switch (choice) {
      'once' => FilledButton.tonal(onPressed: onPressed, child: label),
      'deny' => TextButton(onPressed: onPressed, child: label),
      _ => OutlinedButton(onPressed: onPressed, child: label),
    };
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final scheme = Theme.of(context).colorScheme;
    return InputCardFrame(
      icon: Icons.shield_outlined,
      title: 'Approval needed',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (request.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(request.description),
            ),
          if (request.command.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: scheme.outline),
              ),
              child: SelectableText(
                request.command,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
              ),
            ),
          const SizedBox(height: 10),
          switch (request.status) {
            InputRequestStatus.pending => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final choice in request.choices) _button(choice)],
            ),
            InputRequestStatus.answered => InputCardNote(
              _outcomes[request.choice] ?? 'Answered',
            ),
            InputRequestStatus.expired => const InputCardNote(
              'This request timed out',
            ),
          },
          if (_error != null) InputCardNote(_error!, error: true),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Run the approval tests**

Run: `flutter test test/approval_card_test.dart`
Expected: PASS. If `pumpAndSettle` times out on the dialog, replace it with `pump()` plus `pump(const Duration(milliseconds: 300))`.

- [ ] **Step 6: Write the failing clarify card tests**

Create `test/clarify_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/widgets/clarify_card.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

const _single = ClarifyRequest(
  requestId: 'r1',
  questions: [
    ClarifyQuestion(qid: '', question: 'Which colour?', choices: ['red', 'blue']),
  ],
);

const _batch = ClarifyRequest(
  requestId: 'r2',
  batch: true,
  questions: [
    ClarifyQuestion(qid: 'a', question: 'Your name?'),
    ClarifyQuestion(
      qid: 'b',
      question: 'Toppings?',
      choices: ['ham', 'olives', 'onion'],
      multiSelect: true,
    ),
  ],
);

Future<void> _pump(
  WidgetTester tester,
  ClarifyRequest request, {
  Future<void> Function(Map<String, List<String>>)? onAnswer,
}) => tester.pumpWidget(
  MaterialApp(
    theme: buildHermesLightTheme(),
    home: Scaffold(
      body: SingleChildScrollView(
        child: ClarifyCard(request: request, onAnswer: onAnswer),
      ),
    ),
  ),
);

Finder _send() => find.widgetWithText(FilledButton, 'Send');

Finder _confirm() => find.widgetWithText(FilledButton, 'Confirm');

void main() {
  testWidgets('a single question shows its choices; Send needs a pick', (
    tester,
  ) async {
    await _pump(tester, _single, onAnswer: (_) async {});

    expect(find.text('Which colour?'), findsOneWidget);
    expect(find.text('red'), findsOneWidget);
    expect(tester.widget<FilledButton>(_send()).onPressed, isNull);

    await tester.tap(find.text('blue'));
    await tester.pump();

    expect(tester.widget<FilledButton>(_send()).onPressed, isNotNull);
  });

  testWidgets('a single choice replaces the earlier pick', (tester) async {
    final sent = <Map<String, List<String>>>[];
    await _pump(tester, _single, onAnswer: (a) async => sent.add(a));

    await tester.tap(find.text('red'));
    await tester.tap(find.text('blue'));
    await tester.pump();
    await tester.tap(_send());
    await tester.pump();

    expect(sent.single, {
      '': ['blue'],
    });
  });

  testWidgets('an open-ended question sends the typed text', (tester) async {
    const open = ClarifyRequest(
      requestId: 'r1',
      questions: [ClarifyQuestion(qid: '', question: 'Your name?')],
    );
    final sent = <Map<String, List<String>>>[];
    await _pump(tester, open, onAnswer: (a) async => sent.add(a));

    await tester.enterText(find.byType(TextField), '  Ada ');
    await tester.pump();
    await tester.tap(_send());
    await tester.pump();

    expect(sent.single, {
      '': ['Ada'],
    });
  });

  testWidgets('Confirm waits until every batch question has an answer', (
    tester,
  ) async {
    final sent = <Map<String, List<String>>>[];
    await _pump(tester, _batch, onAnswer: (a) async => sent.add(a));
    expect(tester.widget<FilledButton>(_confirm()).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Ada');
    await tester.pump();
    expect(tester.widget<FilledButton>(_confirm()).onPressed, isNull);

    await tester.tap(find.text('ham'));
    await tester.tap(find.text('onion'));
    await tester.pump();
    expect(tester.widget<FilledButton>(_confirm()).onPressed, isNotNull);

    await tester.tap(_confirm());
    await tester.pump();

    expect(sent.single, {
      'a': ['Ada'],
      'b': ['ham', 'onion'],
    });
  });

  testWidgets('tapping a picked multi-select choice again drops it', (
    tester,
  ) async {
    final sent = <Map<String, List<String>>>[];
    await _pump(tester, _batch, onAnswer: (a) async => sent.add(a));

    await tester.enterText(find.byType(TextField), 'Ada');
    await tester.tap(find.text('ham'));
    await tester.tap(find.text('olives'));
    await tester.tap(find.text('ham'));
    await tester.pump();
    await tester.tap(_confirm());
    await tester.pump();

    expect(sent.single['b'], ['olives']);
  });

  testWidgets('Skip sends an empty answer set', (tester) async {
    final sent = <Map<String, List<String>>>[];
    await _pump(tester, _batch, onAnswer: (a) async => sent.add(a));

    await tester.tap(find.text('Skip'));
    await tester.pump();

    expect(sent.single, isEmpty);
  });

  testWidgets('a failed answer shows an error and can be retried', (
    tester,
  ) async {
    var calls = 0;
    await _pump(
      tester,
      _single,
      onAnswer: (_) async {
        calls++;
        if (calls == 1) throw Exception('socket closed');
      },
    );
    await tester.tap(find.text('red'));
    await tester.pump();

    await tester.tap(_send());
    await tester.pump();
    expect(find.text('Could not send your answer. Try again.'), findsOneWidget);

    await tester.tap(_send());
    await tester.pump();
    expect(calls, 2);
    expect(find.text('Could not send your answer. Try again.'), findsNothing);
  });

  testWidgets('an answered request lists the answers and no controls', (
    tester,
  ) async {
    await _pump(
      tester,
      _batch.answeredWith({
        'a': ['Ada'],
        'b': ['ham', 'onion'],
      }),
      onAnswer: (_) async {},
    );

    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('ham, onion'), findsOneWidget);
    expect(find.text('Confirm'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('a skipped request says so', (tester) async {
    await _pump(tester, _single.answeredWith(const {}), onAnswer: (_) async {});

    expect(find.text('Skipped'), findsOneWidget);
  });

  testWidgets('an expired request says so and has no controls', (tester) async {
    await _pump(
      tester,
      _single.withStatus(InputRequestStatus.expired),
      onAnswer: (_) async {},
    );

    expect(find.text('This request timed out'), findsOneWidget);
    expect(find.text('red'), findsNothing);
  });
}
```

- [ ] **Step 7: Run to verify it fails**

Run: `flutter test test/clarify_card_test.dart`
Expected: compile error, `clarify_card.dart` not found.

- [ ] **Step 8: Create the clarify card**

`lib/src/chat/widgets/clarify_card.dart`:

```dart
import 'package:flutter/material.dart';

import '../chat_models.dart';
import 'approval_card.dart' show kAnswerFailedMessage;
import 'input_card_frame.dart';

/// The agent asks one question, or a batch, and waits. Answers stay on the card
/// until Send or Confirm, so a batch goes out together.
class ClarifyCard extends StatefulWidget {
  const ClarifyCard({super.key, required this.request, this.onAnswer});

  final ClarifyRequest request;

  /// Sends the values picked or typed per `qid`; an empty map skips the
  /// request. Throwing means it did not go through. Without one the controls
  /// are disabled.
  final Future<void> Function(Map<String, List<String>> answers)? onAnswer;

  @override
  State<ClarifyCard> createState() => _ClarifyCardState();
}

class _ClarifyCardState extends State<ClarifyCard> {
  final _picked = <String, List<String>>{};
  final _texts = <String, TextEditingController>{};
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in _texts.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _textFor(String qid) => _texts.putIfAbsent(
    qid,
    () => TextEditingController()..addListener(() => setState(() {})),
  );

  List<String> _answerFor(ClarifyQuestion q) {
    if (q.choices.isEmpty) {
      final text = _textFor(q.qid).text.trim();
      return text.isEmpty ? const [] : [text];
    }
    return _picked[q.qid] ?? const [];
  }

  bool get _ready =>
      widget.request.questions.every((q) => _answerFor(q).isNotEmpty);

  void _toggle(ClarifyQuestion q, String choice) {
    setState(() {
      final now = [...?_picked[q.qid]];
      if (!q.multiSelect) {
        _picked[q.qid] = [choice];
      } else {
        now.contains(choice) ? now.remove(choice) : now.add(choice);
        _picked[q.qid] = now;
      }
    });
  }

  Future<void> _submit(Map<String, List<String>> answers) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onAnswer!(answers);
    } catch (_) {
      if (mounted) setState(() => _error = kAnswerFailedMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _input(ClarifyQuestion q) {
    if (q.choices.isEmpty) {
      return TextField(
        controller: _textFor(q.qid),
        enabled: !_busy,
        decoration: const InputDecoration(
          isDense: true,
          hintText: 'Type your answer',
        ),
      );
    }
    final picked = _picked[q.qid] ?? const [];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final choice in q.choices)
          FilterChip(
            label: Text(choice),
            selected: picked.contains(choice),
            onSelected: _busy ? null : (_) => _toggle(q, choice),
          ),
      ],
    );
  }

  Widget _pending(ClarifyRequest request) {
    final enabled = !_busy && widget.onAnswer != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final q in request.questions) ...[
          Text(q.question),
          const SizedBox(height: 8),
          _input(q),
          const SizedBox(height: 12),
        ],
        Wrap(
          spacing: 8,
          children: [
            FilledButton(
              onPressed: enabled && _ready
                  ? () => _submit({
                      for (final q in request.questions) q.qid: _answerFor(q),
                    })
                  : null,
              child: Text(request.batch ? 'Confirm' : 'Send'),
            ),
            TextButton(
              onPressed: enabled ? () => _submit(const {}) : null,
              child: const Text('Skip'),
            ),
          ],
        ),
        if (_error != null) InputCardNote(_error!, error: true),
      ],
    );
  }

  Widget _answered(ClarifyRequest request) {
    if (request.answers.isEmpty) return const InputCardNote('Skipped');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final q in request.questions) ...[
          Text(q.question),
          InputCardNote(request.answers[q.qid]?.join(', ') ?? ''),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    return InputCardFrame(
      icon: Icons.help_outline,
      title: 'Hermes has a question',
      child: switch (request.status) {
        InputRequestStatus.pending => _pending(request),
        InputRequestStatus.answered => _answered(request),
        InputRequestStatus.expired => const InputCardNote(
          'This request timed out',
        ),
      },
    );
  }
}
```

- [ ] **Step 9: Run the clarify tests**

Run: `flutter test test/clarify_card_test.dart`
Expected: PASS. A `FilterChip` label tap needs the chip on screen; the `SingleChildScrollView` in `_pump` keeps it reachable.

- [ ] **Step 10: Write the failing builder tests**

In `test/chat_builders_test.dart`, add imports for `approval_card.dart`, `clarify_card.dart` and `chat_models.dart` (it already imports `ToolCallStatus` with `show`; extend that `show` list with `ApprovalRequest`, `ClarifyQuestion`, `ClarifyRequest`), then in the same style as the existing custom-message tests:

```dart
  testWidgets('an approval request renders as an ApprovalCard', (tester) async {
    const request = ApprovalRequest(
      requestId: 'r1',
      command: 'rm -rf build',
      description: 'delete files',
      choices: ['once', 'deny'],
    );
    await _pumpChat(
      tester,
      messages: [
        _custom({kMetaKind: kKindInputRequest, kMetaInputRequest: request}),
      ],
    );

    final card = tester.widget<ApprovalCard>(find.byType(ApprovalCard));
    expect(card.request, same(request));
  });

  testWidgets('a clarify request renders as a ClarifyCard', (tester) async {
    const request = ClarifyRequest(
      requestId: 'r2',
      questions: [ClarifyQuestion(qid: '', question: 'Which?', choices: ['a'])],
    );
    await _pumpChat(
      tester,
      messages: [
        _custom({kMetaKind: kKindInputRequest, kMetaInputRequest: request}),
      ],
    );

    expect(find.byType(ClarifyCard), findsOneWidget);
  });

  testWidgets('a card answer reaches the screen callback with its request id', (
    tester,
  ) async {
    const request = ApprovalRequest(
      requestId: 'r1',
      command: 'ls',
      description: 'list',
      choices: ['once', 'deny'],
    );
    final answers = <(String, String)>[];
    await _pumpChat(
      tester,
      messages: [
        _custom({kMetaKind: kKindInputRequest, kMetaInputRequest: request}),
      ],
      onAnswerApproval: (id, choice) async => answers.add((id, choice)),
    );

    await tester.tap(find.text('Allow once'));
    await tester.pump();

    expect(answers, [('r1', 'once')]);
  });
```

Extend `_pumpChat` in that file with two optional parameters and pass them to `buildChatBuilders`:

```dart
  Future<void> Function(String requestId, String choice)? onAnswerApproval,
  Future<void> Function(String requestId, Map<String, List<String>> answers)?
  onAnswerClarify,
```

```dart
          builders: buildChatBuilders(
            onPickPrompt: onPickPrompt ?? (_) {},
            greetingName: greetingName,
            onAnswerApproval: onAnswerApproval,
            onAnswerClarify: onAnswerClarify,
          ).copyWith(composerBuilder: (_) => const SizedBox.shrink()),
```

- [ ] **Step 11: Run to verify it fails**

Run: `flutter test test/chat_builders_test.dart`
Expected: compile error, `onAnswerApproval` is not a parameter of `buildChatBuilders`.

- [ ] **Step 12: Route the cards in `chat_builders.dart`**

Add imports `../chat_models.dart` (extend the existing `show` to `ApprovalRequest, ClarifyRequest, ToolCall, ToolCallStatus`), `approval_card.dart`, `clarify_card.dart`. Change `buildChatBuilders`:

```dart
Builders buildChatBuilders({
  required void Function(String prompt) onPickPrompt,
  String? greetingName,
  Future<void> Function(String requestId, String choice)? onAnswerApproval,
  Future<void> Function(String requestId, Map<String, List<String>> answers)?
  onAnswerClarify,
}) {
  return Builders(
    textMessageBuilder: _buildText,
    customMessageBuilder:
        (
          context,
          message,
          index, {
          required isSentByMe,
          groupStatus,
        }) => _buildCustom(
          context,
          message,
          index,
          isSentByMe: isSentByMe,
          groupStatus: groupStatus,
          onAnswerApproval: onAnswerApproval,
          onAnswerClarify: onAnswerClarify,
        ),
    emptyChatListBuilder: (_) =>
        WelcomeView(greetingName: greetingName, onPick: onPickPrompt),
  );
}
```

`_buildCustom` gets the two named parameters (same types, optional) and a new case before `default`:

```dart
    case kKindInputRequest:
      return switch (metadata![kMetaInputRequest]) {
        ApprovalRequest request => ApprovalCard(
          request: request,
          onAnswer: onAnswerApproval == null
              ? null
              : (choice) => onAnswerApproval(request.requestId, choice),
        ),
        ClarifyRequest request => ClarifyCard(
          request: request,
          onAnswer: onAnswerClarify == null
              ? null
              : (answers) => onAnswerClarify(request.requestId, answers),
        ),
        _ => const SizedBox.shrink(),
      };
```

- [ ] **Step 13: Run tests and analysis**

Run: `dart format lib test && flutter analyze && flutter test test/approval_card_test.dart test/clarify_card_test.dart test/chat_builders_test.dart`
Expected: PASS.

- [ ] **Step 14: Commit**

```bash
git add lib test
git commit -m "feat(chat): approval and clarify cards"
```

---

### Task 5: Wire the cards to the chat screen

**Files:**

- Modify: `lib/src/chat/chat_screen.dart`
- Test: `test/chat_input_request_test.dart`

**Interfaces:**

- Consumes: transport answer methods (Task 3), `buildChatBuilders` callbacks (Task 4), `recordApproval`, `recordClarifyAnswers`, `expireInputRequests` (Task 1), `FakeChatTransport` recorders (Task 3).
- Produces: nothing new for later tasks. Behaviour: tapping an answer calls the transport; on `true` the request becomes `answered`, on `false` it becomes `expired`, on a throw the card shows its error and the request stays `pending`. A batch is sent one `question_id` at a time; a skip on a batch is one call with no `question_id`.

- [ ] **Step 1: Write the failing screen tests**

Create `test/chat_input_request_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/widgets/approval_card.dart';
import 'package:hermes_app/src/chat/widgets/clarify_card.dart';
import 'package:hermes_app/src/chat/widgets/thinking_indicator.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';
import 'support/pump_chat.dart';

const _approval = ApprovalRequest(
  requestId: 'r1',
  command: 'rm -rf build',
  description: 'delete files',
  choices: ['once', 'deny'],
);

const _single = ClarifyRequest(
  requestId: 'r2',
  questions: [
    ClarifyQuestion(qid: '', question: 'Which colour?', choices: ['red', 'blue']),
  ],
);

const _batch = ClarifyRequest(
  requestId: 'r3',
  batch: true,
  questions: [
    ClarifyQuestion(qid: 'a', question: 'Your name?'),
    ClarifyQuestion(qid: 'b', question: 'Pick', choices: ['x', 'y']),
  ],
);

void main() {
  late FakeHermesServer server;
  late FakeChatTransport transport;

  setUp(() {
    server = FakeHermesServer()
      ..on('GET', '/api/sessions', sessionListBody(const []));
    transport = FakeChatTransport();
  });

  /// Sends a prompt and has the agent raise [request] mid-turn.
  Future<FakeSend> raise(WidgetTester tester, ChatEvent request) async {
    await pumpChatScreen(tester, server: server, transport: transport);
    await tester.enterText(find.byType(EditableText), 'clean up');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
    final turn = transport.sends.single;
    turn.emit(request);
    await tester.pump();
    return turn;
  }

  Future<void> settle(WidgetTester tester) =>
      tester.pump(const Duration(seconds: 1));

  /// Finds [matching] inside the clarify card, not the composer beside it.
  Finder inCard(Finder matching) =>
      find.descendant(of: find.byType(ClarifyCard), matching: matching);

  testWidgets('an approval shows a card, and no thinking indicator', (
    tester,
  ) async {
    await raise(tester, const ApprovalRequested(_approval));

    expect(find.byType(ApprovalCard), findsOneWidget);
    expect(find.text('rm -rf build'), findsOneWidget);
    expect(find.byType(ThinkingIndicator), findsNothing);
    await settle(tester);
  });

  testWidgets('allowing an approval sends it and locks the card', (
    tester,
  ) async {
    await raise(tester, const ApprovalRequested(_approval));

    await tester.tap(find.text('Allow once'));
    await tester.pump();

    expect(transport.approvalAnswers, [('r1', 'once')]);
    expect(find.text('Allowed once'), findsOneWidget);
    expect(find.text('Allow once'), findsNothing);
    await settle(tester);
  });

  testWidgets('an approval the backend no longer holds locks as expired', (
    tester,
  ) async {
    transport.accepts = false;
    await raise(tester, const ApprovalRequested(_approval));

    await tester.tap(find.text('Deny'));
    await tester.pump();

    expect(find.text('This request timed out'), findsOneWidget);
    await settle(tester);
  });

  testWidgets('a failed answer keeps the card open with an error', (
    tester,
  ) async {
    transport.answerError = Exception('socket closed');
    await raise(tester, const ApprovalRequested(_approval));

    await tester.tap(find.text('Allow once'));
    await tester.pump();

    expect(find.text('Could not send your answer. Try again.'), findsOneWidget);
    expect(find.text('Allow once'), findsOneWidget);
    await settle(tester);
  });

  testWidgets('an expire event locks a pending card', (tester) async {
    final turn = await raise(tester, const ApprovalRequested(_approval));

    turn.emit(const InputRequestExpired('r1'));
    await tester.pump();

    expect(find.text('This request timed out'), findsOneWidget);
    await settle(tester);
  });

  testWidgets('a single clarify answer goes out without a question id', (
    tester,
  ) async {
    await raise(tester, const ClarifyRequested(_single));

    await tester.tap(find.text('blue'));
    await tester.pump();
    await tester.tap(inCard(find.widgetWithText(FilledButton, 'Send')));
    await tester.pump();

    expect(transport.clarifyAnswers.single.requestId, 'r2');
    expect(transport.clarifyAnswers.single.values, ['blue']);
    expect(transport.clarifyAnswers.single.questionId, isNull);
    await settle(tester);
  });

  testWidgets('a batch goes out one question id at a time', (tester) async {
    await raise(tester, const ClarifyRequested(_batch));

    await tester.enterText(inCard(find.byType(TextField)), 'Ada');
    await tester.tap(find.text('y'));
    await tester.pump();
    await tester.tap(inCard(find.widgetWithText(FilledButton, 'Confirm')));
    await tester.pump();

    expect(transport.clarifyAnswers.map((a) => a.questionId), ['a', 'b']);
    expect(transport.clarifyAnswers.map((a) => a.values), [
      ['Ada'],
      ['y'],
    ]);
    await settle(tester);
  });

  testWidgets('skipping a batch cancels it with one call', (tester) async {
    await raise(tester, const ClarifyRequested(_batch));

    await tester.tap(find.text('Skip'));
    await tester.pump();

    expect(transport.clarifyAnswers.single.questionId, isNull);
    expect(transport.clarifyAnswers.single.values, isEmpty);
    expect(find.text('Skipped'), findsOneWidget);
    expect(find.byType(ClarifyCard), findsOneWidget);
    await settle(tester);
  });

  testWidgets('finishing the reply expires a card nobody answered', (
    tester,
  ) async {
    final turn = await raise(tester, const ApprovalRequested(_approval));

    turn.emit(const ReplyCompleted('Done'));
    await tester.pump();

    expect(find.text('This request timed out'), findsOneWidget);
    await settle(tester);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/chat_input_request_test.dart`
Expected: tests FAIL. The cards render but tapping does nothing: `approvalAnswers` is empty because the screen passes no callbacks. If instead the file fails at setup (for example `sessionListBody(const [])` is not accepted or the composer is not found), fix the setup to mirror `test/chat_streaming_test.dart`'s `setUp` and `pumpChat`, then re-run.

- [ ] **Step 3: Send the answers from the screen**

In `lib/src/chat/chat_screen.dart`, add next to `_updateReply`:

```dart
  ChatMessage? _replyAwaiting(ChatThread thread, String requestId) {
    for (final message in thread.messages.reversed) {
      if (message.inputRequests.any((r) => r.requestId == requestId)) {
        return message;
      }
    }
    return null;
  }

  Future<void> _answerApproval(
    ChatThread thread,
    String requestId,
    String choice,
  ) async {
    final transport = _transport;
    final reply = _replyAwaiting(thread, requestId);
    if (transport == null || reply == null) return;
    final accepted = await transport.answerApproval(requestId, choice);
    if (!mounted) return;
    _updateReply(
      thread,
      reply,
      () => accepted
          ? recordApproval(reply, requestId, choice)
          : expireInputRequests(reply, requestId: requestId),
    );
  }

  Future<void> _answerClarify(
    ChatThread thread,
    String requestId,
    Map<String, List<String>> answers,
  ) async {
    final transport = _transport;
    final reply = _replyAwaiting(thread, requestId);
    if (transport == null || reply == null) return;
    final request = reply.inputRequests.firstWhere(
      (r) => r.requestId == requestId,
    );
    if (request is! ClarifyRequest) return;

    var accepted = true;
    if (answers.isEmpty) {
      accepted = await transport.answerClarify(requestId, const []);
    } else {
      for (final q in request.questions) {
        accepted = await transport.answerClarify(
          requestId,
          answers[q.qid] ?? const [],
          questionId: request.batch ? q.qid : null,
          multiSelect: q.multiSelect,
        );
        if (!accepted) break;
      }
    }
    if (!mounted) return;
    _updateReply(
      thread,
      reply,
      () => accepted
          ? recordClarifyAnswers(reply, requestId, answers)
          : expireInputRequests(reply, requestId: requestId),
    );
  }
```

`chat_reply.dart` and `chat_models.dart` are already imported by the screen (`ChatMessage`, `applyReplyEvent`); add the import if analysis says otherwise.

- [ ] **Step 4: Pass the callbacks down**

Where `_ThreadView(` is constructed in `build`, add:

```dart
                  onAnswerApproval: selected == null
                      ? null
                      : (id, choice) => _answerApproval(selected, id, choice),
                  onAnswerClarify: selected == null
                      ? null
                      : (id, answers) => _answerClarify(selected, id, answers),
```

In `_ThreadView`, add the two constructor parameters and fields:

```dart
  final Future<void> Function(String requestId, String choice)?
  onAnswerApproval;
  final Future<void> Function(String requestId, Map<String, List<String>> answers)?
  onAnswerClarify;
```

and forward them in `buildChatBuilders(onPickPrompt: onSend, greetingName: identity?.displayName, onAnswerApproval: onAnswerApproval, onAnswerClarify: onAnswerClarify)`.

- [ ] **Step 5: Run the tests and the whole suite**

Run: `dart format lib test && flutter analyze && flutter test test/chat_input_request_test.dart`
Expected: PASS.

Then: `flutter test`
Expected: the full suite passes. `real_backend_contract_test.dart` reports skipped.

- [ ] **Step 6: Commit**

```bash
git add lib test
git commit -m "feat(chat): answer agent requests from the chat"
```

---

### Task 6: Verify in the running app

**Files:** none (verification only; commit only if it turns up a fix).

- [ ] **Step 1: Format, analyze, test one last time**

Run: `dart format --output=none --set-exit-if-changed . && flutter analyze && flutter test`
Expected: all clean, all pass.

- [ ] **Step 2: Try the real flow**

Use the `verify-in-app` skill. It needs a Hermes backend, and each real prompt costs money (see the project memory on the dev backend), so keep it to two prompts:

1. Ask the agent to run a command that needs approval (for example, delete a temp file it created) and check that the approval card appears, that Allow once resumes the turn, and that the card locks to "Allowed once".
2. Ask it a question that makes it call clarify ("ask me which of two colours I prefer, using the clarify tool") and check that the card appears and answering resumes the turn.

If the model does not raise a request on demand, say so in the report instead of claiming the feature works against the real backend. The unit and widget tests are the evidence in that case.

- [ ] **Step 3: Report**

State what was verified against the real backend and what was only covered by tests.
