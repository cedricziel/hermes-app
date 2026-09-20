# Chat Follow-ups Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the gaps the reviews of PR #55 (answering agent requests) and PR #56 (local notifications) left open: two turns on one gateway session, requests the app cannot answer yet, silent stream failures, notification tap edge cases, and the size of `chat_screen.dart`.

**Architecture:** Five small, independent changes, each on its own branch stacked on the previous one so each becomes its own PR. They build on the branch of PR #56 (`feat/local-notifications`), because Tasks 3 to 5 touch the notification wiring that PR adds.

**Tech Stack:** Flutter, Dart 3, `provider`, `flutter_test`.

**Spec:** These are follow-ups to `docs/superpowers/specs/2026-09-19-agent-input-requests-design.md` and `docs/superpowers/specs/2026-09-19-local-notifications-design.md`. There is no separate spec: each change is small and its behavior is stated in the task.

## Global Constraints

- Run every command from the worktree root. Never `cd` elsewhere. Never use bare `git stash`.
- Stack: Task N is implemented on its own branch, created from the tip of the previous task's branch (Task 1 from `feat/local-notifications`). The controller pushes branches and opens the PRs; implementers only create the branch, commit and stop. Branch names: Task 1 `feat/one-turn-per-thread`, Task 2 `feat/unsupported-requests`, Task 3 `feat/notify-stream-failure`, Task 4 `fix/notification-tap-edges`, Task 5 `refactor/notification-wiring`.
- Before each commit: `dart format lib test` and `flutter analyze` must be clean. CI also runs `dart format --output=none --set-exit-if-changed .`.
- Semantic commit messages, one concern per commit. No "and" in a subject.
- No code comments unless they explain something the code cannot. Match the surrounding doc-comment style (`///` on public types).
- New behavior needs a test written first. Follow `test/chat_notifications_test.dart` and `test/chat_input_request_test.dart` for screen tests, `test/hermes_gateway_transport_test.dart` for the gateway.
- Preference writes awaited directly in a `testWidgets` body hang under fake-async: wrap them in `await tester.runAsync(() => ...)`.
- `secret` and `sudo` values are never sent by the app in this plan: it only tells the user to answer them elsewhere.
- Do not touch `packages/hermes_api` (generated client, never hand-edited).

---

## File Structure

| File                                                 | Change           | Task          |
| ---------------------------------------------------- | ---------------- | ------------- |
| `lib/src/chat/chat_screen.dart`                      | modify           | 1, 2, 3, 4, 5 |
| `test/chat_one_turn_test.dart`                       | create           | 1             |
| `lib/src/chat/chat_models.dart`                      | modify           | 2             |
| `lib/src/chat/chat_transport.dart`                   | modify           | 2             |
| `lib/src/chat/chat_reply.dart`                       | modify           | 2             |
| `lib/src/chat/gateway/hermes_gateway_transport.dart` | modify           | 2             |
| `lib/src/chat/widgets/unsupported_request_card.dart` | create           | 2             |
| `lib/src/chat/widgets/chat_builders.dart`            | modify           | 2             |
| `lib/src/notifications/attention_policy.dart`        | modify           | 2             |
| `lib/src/notifications/attention_notifier.dart`      | create           | 5             |
| Tests next to each                                   | modify or create | 2 to 5        |

---

### Task 1: One turn per thread

Sending a second prompt on a thread that is still replying puts two turns on one gateway session: both listen to the same runtime session, so both see every event. A request raised later can land in both replies as duplicate cards, and one turn ending can clear the other's bookkeeping. The chat never blocked sending while a reply streams.

Ruling: block sending on a thread while it has a pending reply, and say why. A pending request counts as a pending reply (the agent is waiting on the user, so the user answers the card instead). Other threads are not affected. After a reply completes or breaks, sending works again.

**Files:**

- Modify: `lib/src/chat/chat_screen.dart` (`_send`)
- Test: `test/chat_one_turn_test.dart`

**Interfaces:**

- Produces: `_isReplying(ChatThread)` (private). No public API change.

- [ ] **Step 0: Create the branch**

Run: `git switch -c feat/one-turn-per-thread` (from the current tip, `feat/local-notifications`).

- [ ] **Step 1: Write the failing tests**

Create `test/chat_one_turn_test.dart`. Copy the `setUp`, the `pump` helper and the `send` helper from `test/chat_notifications_test.dart` (fake server with sessions `s1` "Run failure" and `s2` "Release notes" and their message routes, `FakeChatTransport`, `pumpChatScreen`), without the notification providers. Then:

```dart
  testWidgets('a second prompt is not sent while the reply is streaming', (
    tester,
  ) async {
    await pump(tester);
    await send(tester, 'One');

    await send(tester, 'Two');

    expect(transport.sends, hasLength(1));
    expect(
      find.text(
        'Hermes is still replying. Wait for it to finish, or answer its '
        'request.',
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('sending works again once the reply completed', (tester) async {
    await pump(tester);
    final first = await send(tester, 'One');
    first.emit(const ReplyCompleted('Done.'));
    await tester.pump();

    await send(tester, 'Two');

    expect(transport.sends, hasLength(2));
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a pending request also blocks sending', (tester) async {
    await pump(tester);
    final first = await send(tester, 'One');
    first.emit(
      const ApprovalRequested(
        ApprovalRequest(
          requestId: 'r1',
          command: 'ls',
          description: 'list',
          choices: ['once', 'deny'],
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    await send(tester, 'Two');

    expect(transport.sends, hasLength(1));
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a broken stream frees the thread again', (tester) async {
    await pump(tester);
    final first = await send(tester, 'One');
    first.fail();
    await tester.pump();

    await send(tester, 'Two');

    expect(transport.sends, hasLength(2));
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('another thread can be written to meanwhile', (tester) async {
    await pump(tester);
    await send(tester, 'One');
    await tester.tap(
      find.descendant(
        of: find.byType(ThreadSidebar),
        matching: find.text('Release notes'),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    await send(tester, 'Two');

    expect(transport.sends, hasLength(2));
    expect(transport.sends.last.threadId, 's2');
    await tester.pump(const Duration(seconds: 5));
  });
```

Adapt the imports (`chat_models.dart` for `ApprovalRequest`, `chat_transport.dart` for the events, `thread_sidebar.dart`). If the snackbar text assertion is brittle because of animation, pump once more before the `expect`.

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/chat_one_turn_test.dart`
Expected: the "not sent while streaming" and "pending request also blocks" tests FAIL (`sends` has 2 entries); the others PASS.

- [ ] **Step 3: Implement**

In `chat_screen.dart` add next to `_replyAwaiting`:

```dart
  bool _isReplying(ChatThread thread) => thread.messages.any(
    (m) => m.role == ChatRole.assistant && m.isPending,
  );
```

In `_send`, directly after `final selected = _selectedThread;` and before the thread is created, add:

```dart
    if (selected != null && _isReplying(selected)) {
      _showMessage(
        'Hermes is still replying. Wait for it to finish, or answer its '
        'request.',
      );
      return;
    }
```

- [ ] **Step 4: Run tests and analysis**

Run: `dart format lib test && flutter analyze && flutter test test/chat_one_turn_test.dart test/chat_streaming_test.dart test/chat_input_request_test.dart test/chat_notifications_test.dart test/thread_actions_test.dart`
Expected: PASS. Then `flutter test` (full). Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "fix(chat): send one prompt at a time on a thread"
```

---

### Task 2: Requests the app cannot answer yet

`secret.request` (an API key or similar) and `sudo.request` (a sudo password) are ignored, so the turn waits with a thinking indicator until the backend gives up, and the chat looks broken. Show a card saying so, tell the user where to answer it, and lock it on expiry. The app still never asks for a secret or a password.

Wire format (from `tui_gateway/agent_callbacks.py` and `server.py`): `secret.request` payload `{request_id, prompt, env_var, metadata?}`; `sudo.request` payload `{request_id}`; both time out with `secret.expire` / `sudo.expire` `{request_id}`.

**Files:**

- Modify: `lib/src/chat/chat_models.dart`, `lib/src/chat/chat_transport.dart`, `lib/src/chat/chat_reply.dart`, `lib/src/chat/gateway/hermes_gateway_transport.dart`, `lib/src/chat/widgets/chat_builders.dart`, `lib/src/chat/chat_screen.dart` (one `case`), `lib/src/notifications/attention_policy.dart`
- Create: `lib/src/chat/widgets/unsupported_request_card.dart`
- Test: `test/chat_reply_test.dart`, `test/hermes_gateway_transport_test.dart`, `test/unsupported_request_card_test.dart`, `test/chat_builders_test.dart`, `test/chat_input_request_test.dart`, `test/attention_policy_test.dart`

**Interfaces:**

- Produces:
  - `enum UnsupportedKind { secret, sudo }`
  - `final class UnsupportedRequest extends InputRequest { const UnsupportedRequest({required super.requestId, required this.kind, super.status}); final UnsupportedKind kind; UnsupportedRequest withStatus(InputRequestStatus status) }`
  - `final class UnsupportedRequested extends ChatEvent { const UnsupportedRequested(this.request); final UnsupportedRequest request; }`
  - `UnsupportedRequestCard({required UnsupportedRequest request})`
  - `const kNeedsYouBody = 'Waiting for you in Hermes'` in `attention_policy.dart`

- [ ] **Step 0: Create the branch**

Run: `git switch -c feat/unsupported-requests` (from the tip of Task 1's branch).

- [ ] **Step 1: Write the failing tests**

`test/chat_reply_test.dart`, next to the other request tests:

```dart
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
```

`test/hermes_gateway_transport_test.dart`, inside the 'agent input requests' group:

```dart
    test('a secret request becomes an unsupported request', () async {
      gateway.turn = (g, sid) {
        g.event('secret.request', sid, {
          'request_id': 'r5',
          'prompt': 'Enter the key',
          'env_var': 'SERVICE_API_KEY',
        });
        g.event('message.complete', sid, {'text': 'ok', 'status': 'complete'});
      };

      final events = await reply();

      final request = events.whereType<UnsupportedRequested>().single.request;
      expect(request.requestId, 'r5');
      expect(request.kind, UnsupportedKind.secret);
    });

    test('a sudo request becomes an unsupported request', () async {
      gateway.turn = (g, sid) {
        g.event('sudo.request', sid, {'request_id': 'r6'});
        g.event('message.complete', sid, {'text': 'ok', 'status': 'complete'});
      };

      final events = await reply();

      final request = events.whereType<UnsupportedRequested>().single.request;
      expect(request.kind, UnsupportedKind.sudo);
    });

    test('secret and sudo expire events end the request', () async {
      gateway.turn = (g, sid) {
        g.event('secret.expire', sid, {'request_id': 'r5'});
        g.event('sudo.expire', sid, {'request_id': 'r6'});
        g.event('message.complete', sid, {'text': 'ok', 'status': 'complete'});
      };

      final events = await reply();

      expect(events.whereType<InputRequestExpired>().map((e) => e.requestId), [
        'r5',
        'r6',
      ]);
    });
```

`test/unsupported_request_card_test.dart` (pump like `test/approval_card_test.dart`):

```dart
  testWidgets('a sudo request says the app cannot ask for it yet', (tester) async {
    await _pump(
      tester,
      const UnsupportedRequest(requestId: 'r', kind: UnsupportedKind.sudo),
    );

    expect(find.text('Hermes needs something else'), findsOneWidget);
    expect(find.textContaining('sudo password'), findsOneWidget);
    expect(find.textContaining('terminal or dashboard'), findsOneWidget);
  });

  testWidgets('a secret request names a secret value', (tester) async {
    await _pump(
      tester,
      const UnsupportedRequest(requestId: 'r', kind: UnsupportedKind.secret),
    );

    expect(find.textContaining('secret value'), findsOneWidget);
  });

  testWidgets('an expired request says it timed out', (tester) async {
    await _pump(
      tester,
      const UnsupportedRequest(
        requestId: 'r',
        kind: UnsupportedKind.sudo,
        status: InputRequestStatus.expired,
      ),
    );

    expect(find.text('This request timed out'), findsOneWidget);
    expect(find.textContaining('terminal or dashboard'), findsNothing);
  });
```

`test/chat_builders_test.dart`: a `kKindInputRequest` custom message carrying an `UnsupportedRequest` renders an `UnsupportedRequestCard`.

`test/chat_input_request_test.dart`: raise `UnsupportedRequested` on a sent turn and expect the card and no `ThinkingIndicator`; then `InputRequestExpired('r9')` locks it with 'This request timed out'.

`test/attention_policy_test.dart`: `UnsupportedRequested` is announced with body `kNeedsYouBody` when unfocused, and never when focused on that thread. Add it to the events lists in the "when it is said" group.

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/chat_reply_test.dart test/hermes_gateway_transport_test.dart test/unsupported_request_card_test.dart test/chat_builders_test.dart test/chat_input_request_test.dart test/attention_policy_test.dart`
Expected: compile errors first (`UnsupportedRequest` not defined), then assertion failures once it exists.

- [ ] **Step 3: Implement the model and event**

In `chat_models.dart`, after `ClarifyRequest`:

```dart
enum UnsupportedKind { secret, sudo }

/// The agent asked for something this app cannot ask the user for yet, such
/// as a secret value or a sudo password, and waits for it elsewhere.
final class UnsupportedRequest extends InputRequest {
  const UnsupportedRequest({
    required super.requestId,
    required this.kind,
    super.status,
  });

  final UnsupportedKind kind;

  @override
  UnsupportedRequest withStatus(InputRequestStatus status) =>
      UnsupportedRequest(requestId: requestId, kind: kind, status: status);
}
```

In `chat_transport.dart`, after `ClarifyRequested`:

```dart
final class UnsupportedRequested extends ChatEvent {
  const UnsupportedRequested(this.request);

  final UnsupportedRequest request;
}
```

In `chat_reply.dart`, in `applyReplyEvent` next to the other request cases:

```dart
    case UnsupportedRequested(:final request):
      reply.inputRequests = [...reply.inputRequests, request];
```

In `hermes_gateway_transport.dart` `_toChatEvent`, before `_ => null`:

```dart
      'secret.request' => UnsupportedRequested(
        UnsupportedRequest(
          requestId: text('request_id'),
          kind: UnsupportedKind.secret,
        ),
      ),
      'sudo.request' => UnsupportedRequested(
        UnsupportedRequest(
          requestId: text('request_id'),
          kind: UnsupportedKind.sudo,
        ),
      ),
```

and extend the expire case to `'approval.expire' || 'clarify.expire' || 'secret.expire' || 'sudo.expire' => InputRequestExpired(text('request_id')),`.

In `chat_screen.dart` `_onReplyEvent`, add `UnsupportedRequested()` to the `case ReplyDelta() || ...` group that calls `_updateReply`.

In `attention_policy.dart` add `const kNeedsYouBody = 'Waiting for you in Hermes';` and the case `UnsupportedRequested() => kNeedsYouBody,` in the `switch (event)`.

- [ ] **Step 4: Implement the card and route it**

`lib/src/chat/widgets/unsupported_request_card.dart`:

```dart
import 'package:flutter/material.dart';

import '../chat_models.dart';
import 'input_card_frame.dart';

/// The agent waits on something this app cannot ask for yet. The card says
/// what and where to answer it; it never collects a value.
class UnsupportedRequestCard extends StatelessWidget {
  const UnsupportedRequestCard({super.key, required this.request});

  final UnsupportedRequest request;

  @override
  Widget build(BuildContext context) {
    final asked = switch (request.kind) {
      UnsupportedKind.secret => 'a secret value, such as an API key',
      UnsupportedKind.sudo => 'your sudo password',
    };
    return InputCardFrame(
      icon: Icons.lock_outline,
      title: 'Hermes needs something else',
      child: request.status == InputRequestStatus.expired
          ? const InputCardNote('This request timed out')
          : Text(
              'Hermes asked for $asked. This app cannot ask for it yet. '
              'Answer it in the Hermes terminal or dashboard.',
            ),
    );
  }
}
```

In `chat_builders.dart`, in the `switch (metadata![kMetaInputRequest])` add before `_ =>`:

```dart
        UnsupportedRequest request => UnsupportedRequestCard(request: request),
```

and import the card.

- [ ] **Step 5: Run tests and analysis**

Run: `dart format lib test && flutter analyze && flutter test`
Expected: analyze clean; the full suite PASSES. Fix any exhaustive-switch error the analyzer reports for the new `ChatEvent` or `InputRequest` subtype.

- [ ] **Step 6: Commit**

```bash
git add lib test
git commit -m "feat(chat): show a card for requests the app cannot answer yet"
```

---

### Task 3: Tell the user when a turn breaks

A dropped socket mid-turn is the most likely way a turn ends while the user is away, and it is the one case that produces no notification. When a reply stream ends while the reply is still pending, announce "Reply failed" through the same policy.

**Files:**

- Modify: `lib/src/chat/chat_screen.dart` (`_streamReply`, `end()`)
- Test: `test/chat_notifications_test.dart`

- [ ] **Step 0: Create the branch**

Run: `git switch -c feat/notify-stream-failure` (from the tip of Task 2's branch).

- [ ] **Step 1: Write the failing tests**

In `test/chat_notifications_test.dart`, next to the other announcing tests:

```dart
  testWidgets('a turn that breaks while the app is away is announced', (
    tester,
  ) async {
    await pump(tester);
    final turn = await send(tester, 'Any news?');
    leaveTheApp(tester);

    turn.fail();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final n = service.shown.single;
    expect(n.threadId, 's1');
    expect(n.body, kReplyFailedBody);
  });

  testWidgets('a broken turn is not announced while you are looking at it', (
    tester,
  ) async {
    await pump(tester);
    final turn = await send(tester, 'Any news?');

    turn.fail();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(service.shown, isEmpty);
  });

  testWidgets('a reply that ended normally is announced once', (tester) async {
    await pump(tester);
    final turn = await send(tester, 'Any news?');
    leaveTheApp(tester);

    turn.emit(const ReplyCompleted('Nothing new.'));
    await tester.pump();
    turn.finish();
    await tester.pump(const Duration(seconds: 1));

    expect(service.shown, hasLength(1));
    expect(service.shown.single.body, 'Nothing new.');
  });
```

Import `kReplyFailedBody` from `attention_policy.dart` if not already imported.

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/chat_notifications_test.dart`
Expected: 'a turn that breaks while the app is away is announced' FAILS (`shown` is empty); the other two PASS.

- [ ] **Step 3: Implement**

In `_streamReply`, replace the body of `end()`:

```dart
    void end() {
      _replies.remove(subscription);
      if (reply.isPending) {
        _updateReply(thread, reply, () => failReply(reply));
        _announce(thread, const ReplyCompleted('', failed: true));
      }
    }
```

- [ ] **Step 4: Run tests and analysis**

Run: `dart format lib test && flutter analyze && flutter test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "feat(notifications): announce a reply that broke while you were away"
```

---

### Task 4: Notification tap edge cases

Two problems: (1) a tap reaches `_selectThread`, which also closes the drawer with `Navigator.maybePop()`. On a narrow layout with another screen open (Profiles, Bots) that pops the screen the user is on. (2) A tap, or a launch tap, for a thread that is not in the loaded list does nothing, with no explanation.

Ruling: a notification tap selects the thread without touching the navigator, and when the thread is not in the list the app says so.

**Files:**

- Modify: `lib/src/chat/chat_screen.dart`
- Test: `test/chat_notifications_test.dart`

- [ ] **Step 0: Create the branch**

Run: `git switch -c fix/notification-tap-edges` (from the tip of Task 3's branch).

- [ ] **Step 1: Write the failing tests**

In `test/chat_notifications_test.dart`:

```dart
  testWidgets('a tap for a thread that is not listed says so', (tester) async {
    await pump(tester);

    service.tap('gone');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Could not open that chat.'), findsOneWidget);
    expect(selected(tester), 's1');
  });

  testWidgets('a launch thread that is not listed says so', (tester) async {
    service.launchThread = 'gone';

    await pump(tester);
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Could not open that chat.'), findsOneWidget);
    expect(selected(tester), 's1');
  });

  testWidgets('a tap does not close a screen that sits above the chat', (
    tester,
  ) async {
    await pump(tester);
    tester.view.physicalSize = const Size(500, 900);
    await tester.pump();
    Navigator.of(tester.element(find.byType(ThreadSidebar).first)).push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('a screen above the chat')),
      ),
    );
    await tester.pumpAndSettle();

    service.tap('s2');
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('a screen above the chat'), findsOneWidget);
  });
```

If `find.byType(ThreadSidebar)` is not in the tree at a narrow width (the sidebar may live in a drawer), use `find.byType(Scaffold).first` for the navigator lookup. The last test must fail on the old code: verify that `maybePop` really pops the pushed screen there, and adapt the setup until it does.

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/chat_notifications_test.dart`
Expected: the three new tests FAIL.

- [ ] **Step 3: Implement**

Give `_selectThread` an option and keep its default:

```dart
  void _selectThread(String id, {bool closeDrawer = true}) {
    setState(() => _selectedId = id);
    if (closeDrawer) _closeDrawerIfNarrow();
    if (_repository != null) _loadMessages(id);
  }
```

Replace `_openFromNotification`:

```dart
  void _openFromNotification(String threadId) {
    if (_threads.any((t) => t.id == threadId)) {
      _selectThread(threadId, closeDrawer: false);
    } else {
      _showMessage(_couldNotOpenChat);
    }
  }
```

Add `const _couldNotOpenChat = 'Could not open that chat.';` at the top level of the file. In `_loadThreads`, after the `setState` that applies `launchId`, add:

```dart
      if (launchId != null && _selectedId != launchId) {
        _showMessage(_couldNotOpenChat);
      }
```

- [ ] **Step 4: Run tests and analysis**

Run: `dart format lib test && flutter analyze && flutter test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib test
git commit -m "fix(notifications): open a tapped thread without closing other screens"
```

---

### Task 5: Move the notification wiring out of the chat screen

`chat_screen.dart` carries about 45 lines of notification wiring on top of thread loading and share intake: focus tracking, the tap subscription, the launch lookup, `_announce` and the permission request. Move it into a small class so the screen stays a screen. No behavior change.

**Files:**

- Create: `lib/src/notifications/attention_notifier.dart`
- Modify: `lib/src/chat/chat_screen.dart`
- Test: existing tests (`test/chat_notifications_test.dart`, `test/chat_one_turn_test.dart`, `test/chat_input_request_test.dart`) stay unchanged and must still pass; add `test/attention_notifier_test.dart` for what moves.

**Interfaces:**

- Produces: `AttentionNotifier({required NotificationService? service, required NotificationSettings? settings, required void Function(String threadId) onOpen})` with `void announce(ChatThread thread, ChatEvent event, {required String? selectedThreadId})`, `Future<void> askForPermission()`, `Future<String?> get launchThreadId` (the lookup, started at construction), `bool get focused`, and `void dispose()`. It registers itself as a `WidgetsBindingObserver` and subscribes to the service's taps in its constructor; `dispose` undoes both.

- [ ] **Step 0: Create the branch**

Run: `git switch -c refactor/notification-wiring` (from the tip of Task 4's branch).

- [ ] **Step 1: Write the tests for the new class**

Create `test/attention_notifier_test.dart` using `FakeNotificationService` and a `NotificationSettings` (prefs via `SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty()`; setup that awaits preference writes goes through `tester.runAsync` in `testWidgets`, or use plain `test` where no binding is needed). Cover, with the same expectations the screen tests already have but at the class level:

- `announce` shows what `attentionFor` returns, and nothing without a service or when the switch is off;
- `askForPermission` asks once, records the answer, does not ask when off or already asked, and does not ask twice concurrently;
- a tap on the service calls `onOpen` with the thread id; after `dispose` it no longer does;
- `focused` follows `AppLifecycleState` (use `TestWidgetsFlutterBinding.ensureInitialized()` and `binding.handleAppLifecycleStateChanged`), and `dispose` removes the observer.

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/attention_notifier_test.dart`
Expected: compile error, `attention_notifier.dart` not found.

- [ ] **Step 3: Implement the class**

Create `lib/src/notifications/attention_notifier.dart` by moving, unchanged in behavior, these members out of `_ChatScreenState`: `_notifications`, `_notificationSettings`, `_notificationTaps`, `_launchLookup`, `_focused`, `_askingPermission`, `didChangeAppLifecycleState`, `_announce` (now `announce`, taking `selectedThreadId`) and `_askForNotificationPermission` (now `askForPermission`). The class mixes in `WidgetsBindingObserver`, adds itself in the constructor, reads the initial focus from `WidgetsBinding.instance.lifecycleState` exactly as the screen does (unknown counts as focused), and subscribes to `service.taps` to call `onOpen`.

- [ ] **Step 4: Use it in the screen**

In `chat_screen.dart` replace the moved fields and methods with one field, created in `initState`:

```dart
  late final AttentionNotifier _attention;
  ...
    _attention = AttentionNotifier(
      service: _maybeRead<NotificationService>(),
      settings: _maybeRead<NotificationSettings>(),
      onOpen: _openFromNotification,
    );
```

`_openFromNotification` and `_couldNotOpenChat` stay in the screen (they touch thread selection and the snackbar). `_loadThreads` awaits `_attention.launchThreadId` where it awaited `_launchLookup` (still consumed once: keep a `_launchConsumed` flag or set a nullable field to null after use, as before). `_onReplyEvent` and `end()` call `_attention.announce(thread, event, selectedThreadId: _selectedId)`; `_send` calls `unawaited(_attention.askForPermission())`. `dispose` calls `_attention.dispose()`. Remove the `WidgetsBindingObserver` mixin, the observer registration and the now-unused imports from the screen.

- [ ] **Step 5: Verify nothing changed and the screen shrank**

Run: `dart format lib test && flutter analyze && flutter test`
Expected: the FULL suite passes with the existing screen tests untouched. Then `wc -l lib/src/chat/chat_screen.dart`: it should be at least 40 lines shorter than before this task (`git diff --stat` shows the removal).

- [ ] **Step 6: Commit**

```bash
git add lib test
git commit -m "refactor(notifications): move the wiring out of the chat screen"
```
