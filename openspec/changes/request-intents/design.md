# Design

## Context

See proposal.md for motivation and specs/request-intents/spec.md for behavior.

- `surface-snapshot`'s `pending` rows are `{profile, threadId, threadTitle, kind: approval|question|input, requestId, createdAt, url}`, never the command or the question (Contract 2). `HeadlessHermes.refreshSnapshot({pending})` (added by `background-refresh`) rebuilds and stores the snapshot; without `pending` it keeps the stored requests, so a fresh list has to be read first. `OpenRequestsStep` (`lib/src/background/background_refresh.dart`) reads it: `session.active_list` per profile, then `approval.pending` for each session that waits.
- `ask-hermes-intent` is built in parallel and not on main. This change therefore brings its own small bridge (`RequestIntentsBridge`, below) on its own channel, `hermes_app/request_intents`, so the two changes can land in either order. When both are on main the bridges can be merged into one; that is a follow-up, not part of this change.
- Gateway (`openrpc/hermes-gateway.openrpc.json`): `session.active_list {profile?}` returns live sessions with `id` (live session id), `session_key` (stored session id) and `status`; `approval.pending {session_id, profile?}` returns `{approvals: [{request_id, command, description, choices, allow_session, allow_permanent, …}]}` with the command already redacted by the server; `approval.respond {session_id, profile?, request_id?, choice?}` returns `{resolved: int}` and falls back to the durable identity when the live session id is stale.
- `headless-runtime`: `withHeadlessHermes(body, task:, timeout:)` returns a sealed `HeadlessOutcome<T>`: `HeadlessDone(value)`, `HeadlessSignedOut`, `HeadlessLocked` (secure storage unreadable before the first unlock) or `HeadlessUnreachable`.
- #587 (on main) added `ChatTransport.answerOpenRequest(String id, OpenRequestAnswer answer, {String? profile})` (Hermes `request.answer`, falling back to `approval.respond` / the clarify answer) and `RequestAnswerSender` in `lib/src/notifications/request_answers.dart`, which answers a request by id from any engine. `HermesGatewayTransport.answerApproval(requestId, choice)` only answers requests the same transport saw raised, so it is not used here.

## Goals / Non-Goals

**Goals:**

- The answer path shared with notification buttons where the peer already built one.
- The command shown only after unlock, only inside the intent's confirmation.

**Non-Goals:**

- A Siri dialog for clarify questions (free text answers by voice are a different design).

## Decisions

### Every headless outcome handled

Every Dart method switches over every `HeadlessOutcome` case. `HeadlessDone` carries the result. For "Pending Requests", `HeadlessSignedOut`, `HeadlessLocked` and `HeadlessUnreachable` fall back to the stored snapshot (below), and with no stored list answer "Sign in to Hermes first.", "Unlock your iPhone first." or "Can't reach your Hermes server." (the sentences "Ask Hermes" uses for the same situations). For "Answer Approval" they end the intent with the same three sentences and send nothing (`HeadlessLocked` cannot normally happen there, since the device was unlocked, but is handled the same way). A bridge that gets no answer from Dart says "Hermes isn't available right now.".

### Pending Requests: a fresh snapshot, the stored one as fallback

`PendingRequestsIntent` (`supportedModes = .background`, `authenticationPolicy = .alwaysAllowed`) calls `pending` on the bridge. Dart runs `withHeadlessHermes(task: 'intent.pending', timeout: 15 s)`: it reads the open requests with `OpenRequestsStep` (a context with notifications off, so nothing is announced and nothing is remembered as announced), stores them with `refreshSnapshot(pending:)` so the widgets, the badge and the entity picker agree (best effort, 6 s; the stored rows carry the time each request was first seen), and returns the rows (filtered by profile when given, oldest first) without their `url`. A profile the server refuses to list fails the whole read, since the step then cannot say what waits; the intent falls back to the stored list. When the outcome is not `HeadlessDone` or Dart times out, Swift reads the stored snapshot itself and prefixes the answer with "As of <time>,". The pending list's sources (which requests, across which profiles) are the snapshot builder's, so the widgets, the badge and this intent agree.

The answer lists at most five requests, oldest first, then "and N more". When the app-lock flag is on, Dart returns only the count and Swift says "N requests are waiting. Open Hermes to see them."; a stored list whose titles are empty (written under App Lock) is spoken the same way, prefixed with "As of <time>,". Shortcuts receives the requests as `[PendingRequestEntity]` (their count is the count), none under App Lock.

### Answer Approval: live lookup, confirm, respond

`AnswerApprovalIntent` (`supportedModes = .background`, `authenticationPolicy = .requiresAuthentication`, so iOS asks to unlock before `perform()` runs):

1. Parameter `request: PendingRequestEntity`. The entity's query offers the snapshot's `pending` rows of kind `approval` (filtered by the optional profile through an `IntentParameterDependency`), oldest first, shown as the chat title with "Approval" and the time it was raised. Id: `<profile>/<thread id>/<request id>`, each part percent-encoded (a thread id can hold a slash). A row of another kind (passed in from "Pending Requests") ends with "Only approvals can be answered here.".
2. `perform()` calls `approvalDetail` on the bridge. Dart, with App Lock off, in `withHeadlessHermes`: `ChatTransport.pendingApprovals` (below) and the entry with the request id. It returns `{command, description, choices}` or `gone`. With App Lock on it returns `app_locked` and reads nothing: the command would show past the lock, and notification buttons refuse the same way.
3. Choice: the parameter when given and offered; when given and not offered, the intent ends with "Hermes doesn't offer <choice> for this request." When missing, Swift asks with `requestDisambiguation` among the offered choices.
4. Unless the choice is Deny, Swift calls `requestConfirmation` with "Allow Hermes to run this <once / for this session / always>?", then the command, then its description (when given), as the dialog: it is shown and spoken, which a snippet view would add nothing to. Cancel ends with `cancelled`, tells Dart (`record`, for the log event) and sends nothing.
5. `answerApproval` on the bridge: Dart answers through #587's `RequestAnswerSender`, which calls `answerOpenRequest(requestId, ApprovalChoiceAnswer(choice), threadId:, profile:, raisedAsEvent: true)` on the headless runtime's transport. `raisedAsEvent` is true because `approval.pending` lists the approvals a session raised as events, which `request.answer` does not know; the sender then resumes the chat and uses `approval.respond`, like the background refresh's notification buttons. A request Hermes reports as no longer waiting is `gone`. Then it refreshes the snapshot without that request so the badge and widgets drop it.

The bridge and its channel are below. The flows themselves (`PendingRequestsFlow`, `ApprovalAnswerFlow`) sit in `HermesSurfaceKit` behind a `RequestIntentsBackend` protocol, so `swift test` covers the confirm flow, an expired request and every outcome with a fake backend.

### The bridge: always a background engine

`RequestIntentsBridge` (Runner, Swift) starts a Flutter engine on `requestIntentsMain` (`lib/src/background/entry_points.dart`) with `BackgroundPlugins` (secure storage, shared preferences, package and device info, notifications, home widget, workmanager), waits up to 5 s for Dart's `ready` call on `hermes_app/request_intents`, serializes calls, holds a `UIApplication` background task while one runs, and destroys the engine 10 s after the last call. It does not look for the app's own engine: the intents' Dart work is a few headless runs whichever isolate does them, and `withHeadlessHermes` already reconciles tokens with the foreground `AuthController` through the stored pair. So the span's `engine` is always `background`. `AppDelegate` sets `RequestIntentsRuntime.backend` at launch, which also happens in a launch for an intent with no scene.

### Where the gateway calls live

Answering is #587's: `RequestAnswerSender` and `ChatTransport.answerOpenRequest`. This change adds no answering method and no coordinate-based answer. It adds one read-only call, `ChatTransport.pendingApprovals({required String threadId, String? profile})` (`session.active_list`, then `approval.pending`; an empty list when the session is not live or the server lacks `approval.pending`), implemented on `HermesGatewayTransport` with its existing `_call` and timeouts, and on `FakeChatTransport`, because the confirmation needs the command and offered choices, which neither the snapshot nor #587 provides.

### Platforms and native changes

- iOS: two intents, an entity and an enum in `HermesSurfaceKit`, compiled into the Runner only (they need the app process); the bridge in the Runner; phrases in `HermesAppShortcuts`. No new target, entitlement or Info.plist key.
- Android, macOS, Windows, Linux, watchOS: none.

### Invariants touched

- Auth: the headless runtime's rules (never signs out, gives up on a refresh conflict).
- API layering: gateway RPC only, through the existing transport; no REST call.
- Telemetry, recorded in `lib/src/intents/request_intents.dart`: span `background.task` (`task`, `engine`, `result`, a request count; its `outcome` stays the headless runtime's own, so the intent's result is the attribute `result`, set when the body ran), log event `intent.answer_approval` (`outcome`, `choice`). There are no breadcrumbs: the intents run in a background engine whose trail is never exported. No command, title, profile or id; `choice` is one of four fixed words.
- Tests: Dart against `FakeChatTransport` and, for the transport methods, the existing gateway test harness with scripted RPC answers.

## Risks / Trade-offs

- [`session_key` is assumed to be the stored session id the snapshot's `threadId` holds] → the transport's `activeStatuses` already relies on it; the real-backend contract test gets a case that raises an approval and finds it by `session_key` through `approval.pending`.
- [Approval raised in a session that is no longer live in the gateway process] → `approval.pending` cannot list it; the intent says "That request is no longer waiting." The picker's list is the snapshot's and may still show it until the next refresh.
- [A cold engine eats the time] → engine start, token read and the gateway calls can take several seconds; each call has its own timeout (20 s to read, 25 s to answer) and the user's confirmation between the two does not count against either.
- [Two engines at once] → when the app is open, the intent's engine runs beside the app's. They share storage and `withHeadlessHermes` gives up quietly on a refresh conflict, so the worst case is an intent that says it cannot reach the server.
- [Siri speaks the command aloud] → only after unlock and on the user's own request; stated in the proposal.
- [Size] → about 550 changed lines with tests; kept as one PR because the two intents share the entity and the transport calls.

## Dependencies

- #587 (on main): `answerOpenRequest`, `OpenRequestAnswer`, `RequestAnswerSender`.
- `headless-runtime`: `withHeadlessHermes` and `HeadlessOutcome`.
- `background-refresh`: `HeadlessHermes.refreshSnapshot()`.
- `surface-snapshot`: the `pending` rows.
- `app-intents`: `HermesSurfaceKit`, the Profile entity, `HermesAppShortcuts`.
- None on `ask-hermes-intent`. The bridges of the two changes may be merged once both are on main.

## Migration Plan

Nothing to migrate.
