# Design

## Context

See proposal.md for motivation and specs/request-intents/spec.md for behavior.

- `surface-snapshot`'s `pending` rows are `{profile, threadId, threadTitle, kind: approval|question|input, requestId, createdAt, url}`, never the command or question (Contract 2). `HeadlessHermes.refreshSnapshot()` (added by `background-refresh`) rebuilds and stores the snapshot, pending list included, and returns it.
- `ask-hermes-intent` adds `IntentsBridge` (engine choice, serialized calls, background engine on `intentsMain`) and the `hermes_app/intents` handler in Dart. This change adds two methods to both.
- Gateway (`openrpc/hermes-gateway.openrpc.json`): `session.active_list {profile?}` returns live sessions with `id` (live session id), `session_key` (stored session id) and `status`; `approval.pending {session_id, profile?}` returns `{approvals: [{request_id, command, description, choices, allow_session, allow_permanent, …}]}` with the command already redacted by the server; `approval.respond {session_id, profile?, request_id?, choice?}` returns `{resolved: int}` and falls back to the durable identity when the live session id is stale.
- `headless-runtime`: `withHeadlessHermes(body, task:, timeout:)` returns a sealed `HeadlessOutcome<T>`: `HeadlessDone(value)`, `HeadlessSignedOut`, `HeadlessLocked` (secure storage unreadable before the first unlock) or `HeadlessUnreachable`.
- PR #587 (actionable notifications) adds `ChatTransport.answerOpenRequest(String id, OpenRequestAnswer answer, {String? profile})` (Hermes `request.answer`, falling back to `approval.respond` / the clarify answer) and `RequestAnswerSender` in `lib/src/notifications/request_answers.dart`, which answers a request by id from any engine. `HermesGatewayTransport.answerApproval(requestId, choice)` only answers requests the same transport saw raised, so it is not used here.

## Goals / Non-Goals

**Goals:**

- The answer path shared with notification buttons where the peer already built one.
- The command shown only after unlock, only inside the intent's confirmation.

**Non-Goals:**

- A Siri dialog for clarify questions (free text answers by voice are a different design).

## Decisions

### Every headless outcome handled

Both Dart methods switch over every `HeadlessOutcome` case. `HeadlessDone` carries the result. For "Pending Requests", `HeadlessSignedOut`, `HeadlessLocked` and `HeadlessUnreachable` fall back to the stored snapshot (below), and with no stored list answer "Sign in to Hermes first.", "Unlock your iPhone first." or "Hermes can't reach your server right now.". For "Answer Approval" they end the intent with the same three sentences and send nothing (`HeadlessLocked` cannot normally happen there, since the device was unlocked, but is handled the same way).

### Pending Requests: a fresh snapshot, the stored one as fallback

`PendingRequestsIntent` (`supportedModes = .background`, `authenticationPolicy = .alwaysAllowed`) calls `pending` on the bridge. Dart runs `withHeadlessHermes((h) => h.refreshSnapshot(), task: 'intent.pending', timeout: 15 s)` and returns the `pending` rows (filtered by profile when given) without their `url`. When the outcome is not `HeadlessDone` or Dart times out, Swift reads the stored snapshot itself and prefixes the answer with "As of <time>,". The pending list's sources (which requests, across which profiles) are the snapshot builder's, so the widgets, the badge and this intent agree.

The answer lists at most five requests, oldest first, then "and N more". When the app-lock flag is on, Dart returns only the count and Swift says "N requests are waiting. Open Hermes to see them."

### Answer Approval: live lookup, confirm, respond

`AnswerApprovalIntent` (`supportedModes = .background`, `authenticationPolicy = .requiresAuthentication`, so iOS asks to unlock before `perform()` runs):

1. Parameter `request: PendingRequestEntity`. The entity's query offers the snapshot's `pending` rows of kind `approval` (filtered by the optional profile), oldest first, shown as the chat title with "Approval" and the time it was raised. Id: `<encoded profile>/<thread id>/<encoded request id>`.
2. `perform()` calls `approvalDetail` on the bridge. Dart, in `withHeadlessHermes`: `session.active_list {profile}`, the row whose `session_key` is the thread id, then `approval.pending {session_id: <its id>, profile}` and the entry with the request id. It returns `{command, description, choices}` or `gone`.
3. Choice: the parameter when given and offered; when given and not offered, the intent ends with "Hermes doesn't offer <choice> for this request." When missing, Swift asks with `requestDisambiguation` among the offered choices.
4. Unless the choice is Deny, Swift calls `requestConfirmation` with "Allow Hermes to run this <once / for this session / always>?" and the command (and description, when given) in the confirmation snippet. Cancel ends with `cancelled` and sends nothing.
5. `answerApproval` on the bridge: Dart answers through #587's `RequestAnswerSender`, which calls `answerOpenRequest(requestId, OpenRequestAnswer(choice), profile: profile)` on the headless runtime's transport. A request Hermes reports as no longer waiting is `gone`. Then it refreshes the snapshot so the badge and widgets drop the request.

### Where the gateway calls live

Answering is #587's: `RequestAnswerSender` and `ChatTransport.answerOpenRequest`. This change adds no answering method and no coordinate-based answer. It adds one read-only call, `ChatTransport.pendingApprovals({required String threadId, String? profile})` (`session.active_list`, then `approval.pending`), implemented on `HermesGatewayTransport` with its existing `_call` and timeouts, and on `FakeChatTransport`, because the confirmation needs the command and offered choices, which neither the snapshot nor #587 provides.

### Platforms and native changes

- iOS: two intents, an entity and an enum in `HermesSurfaceKit`, compiled into the Runner only (they need the app process); phrases in `HermesAppShortcuts`. No new target, entitlement or Info.plist key.
- Android, macOS, Windows, Linux, watchOS: none.

### Invariants touched

- Auth: the headless runtime's rules (never signs out, gives up on a refresh conflict).
- API layering: gateway RPC only, through the existing transport; no REST call.
- Telemetry, recorded in `lib/src/intents/request_intents.dart`: span `background.task` (`task`, `outcome`, `engine`), log event `intent.answer_approval` (`outcome`, `choice`), breadcrumbs `intent.pending.ended` / `intent.answer_approval.ended` (`outcome`) in the foreground engine only. No command, title, profile or id; `choice` is one of four fixed words.
- Tests: Dart against `FakeChatTransport` and, for the transport methods, the existing gateway test harness with scripted RPC answers.

## Risks / Trade-offs

- [`session_key` is assumed to be the stored session id the snapshot's `threadId` holds] → the transport's `activeStatuses` already relies on it; the real-backend contract test gets a case that raises an approval and finds it by `session_key` through `approval.pending`.
- [Approval raised in a session that is no longer live in the gateway process] → `approval.pending` cannot list it; the intent says "That request is no longer waiting." The pending list is the snapshot's and may still show it until the next refresh.
- [Siri speaks the command aloud] → only after unlock and on the user's own request; stated in the proposal.
- [Size] → about 550 changed lines with tests; kept as one PR because the two intents share the entity and the transport calls.

## Dependencies

- PR #587: `answerOpenRequest`, `OpenRequestAnswer`, `RequestAnswerSender`.
- `headless-runtime`: `withHeadlessHermes` and `HeadlessOutcome`.
- `background-refresh`: `HeadlessHermes.refreshSnapshot()`.
- `surface-snapshot`: the `pending` rows.
- `app-intents`: `HermesSurfaceKit`, the Profile entity, `HermesAppShortcuts`.
- `ask-hermes-intent`: `IntentsBridge`, the `hermes_app/intents` handler and the `intentsMain` entry point.

## Migration Plan

Nothing to migrate.
