## Context

The watch app has no network of its own. Its `send` request reaches `WatchRequestHandler.send` on the phone, which opens its own gateway connection, streams the turn and returns the final text to the watch in one reply. The phone's notification stack (`NotificationService`, `attentionFor`, `NotificationSettings`) is wired to the chat screen: `AttentionNotifier` lives in `ChatScreen`, so events of a watch turn never reach it.

## Evidence

Read from this repository at `main` (03856f2). Nothing was run against a paired watch.

- `lib/src/notifications/attention_policy.dart`: `attentionFor` returns the title, body and profile for `ReplyCompleted`, `ApprovalRequested`, `ClarifyRequested` and `UnsupportedRequested`, and null while notifications are off or when the app is focused on that very thread. The body rules (preview, "Reply failed", generic request bodies) live only here.
- `lib/src/notifications/attention_notifier.dart`: owns an `AppLifecycleState` observer, the tap subscription (`service.taps.listen(onOpen)`) and the once-only permission request. One instance belongs to one chat screen.
- `lib/src/notifications/local_notification_service.dart`: `show` never throws and drops a notification the system will not show. The service is an app-wide `Provider` in `lib/main.dart`.
- `openspec/changes/archive/2026-09-19-agent-input-requests/design.md`: a pending approval or question lives on the connection that raised it and is not replayed after a reconnect (`approval.pending` and `session.resume` are out of scope); if the socket drops, the request expires.
- `lib/src/watch/watch_request_handler.dart`: the send loop handles `ThreadBound` and `ReplyCompleted` and ignores every other event. `.timeout(sendTimeout)` bounds the gap between events. A thrown timeout or stream error reaches `handle`, which answers `failed`.
- `lib/main.dart`: the `WatchBridge` provider is created before `NotificationSettings` and `NotificationService`.

## Decision

`WatchRequestHandler` gains an `announce` callback, `void Function(AttentionNotification)`, that defaults to doing nothing. The send loop calls it, and only the loop knows the events.

- **Which events.** A `ReplyCompleted` is announced with `attentionFor`. A turn that breaks once the thread is bound (a stream error, the send timeout, or the stream ending without a completion) is announced as a failed reply, exactly like the phone does. A turn that breaks before `ThreadBound` announces nothing: there is no chat to point at.
- **Reusing the policy.** The handler builds a `ChatThread` from the bound session id and the title, and calls `attentionFor` with `appFocused: false`, `selectedThreadId: null` and `enabled: true`. That skips the "focused on the open chat" rule on purpose, and keeps every body string in one place. The on and off setting is applied by the announcer below, not by `attentionFor`.
- **Title.** The last `ThreadTitled` of the turn, else "Hermes". The relay only holds a session id for an existing thread, so it cannot name one the gateway does not rename during the turn.
- **Profile.** The active profile the send already resolved goes into the notification, so its identifier is the same as the phone's for that chat and a later notification for the chat replaces it.
- **Announcer.** `WatchBridge.announcer(service, settings)` returns the closure `forAuth` passes in. It does nothing without a service, and shows the notification only when `settings` is null or loaded and enabled, the rule `AttentionNotifier.announce` applies. It calls `service.show` unawaited; `show` never throws.
- **Input requests.** `ApprovalRequested`, `ClarifyRequested` and `UnsupportedRequested` end the loop at once with `{ok: true, threadId, text: <fixed sentence>, failed: false}`. The existing `finally` closes the connection. Nobody can answer the request (see Evidence), so the turn is left to expire on the gateway, and no notification is posted. The sentence is "Hermes asked for something the watch can't answer. Ask again on your iPhone." It names neither the command nor the question. The watch already shows the returned text as an assistant message, so no Swift change is needed.
- **Wiring.** `WatchBridge.forAuth(auth, notifications:, settings:)`. In `lib/main.dart` the `WatchBridge` provider moves below `NotificationService` because `context.read` only sees providers declared above it.

## Alternatives considered

- **Reuse `AttentionNotifier`.** It is tied to a chat screen (lifecycle observer, tap subscription, permission request). A second instance would open a chat twice per tap. Only `service.show` and `attentionFor` are needed.
- **Keep waiting on an input request, or keep the connection open after answering the watch.** Nothing on the phone can answer the request, so this only holds a socket and makes the user wait for the timeout.
- **Announce an input request with "Waiting for your approval".** It would send the user to a chat that cannot answer it.
- **The watch sends the thread's title with each send.** Better titles for existing threads, but a wire and Swift change (`RelayClient`, `ConversationModel`). Left for a later change.
- **Ask for notification permission on the first watch send.** The system prompt would appear on a phone that is in a pocket, and may not show at all while the app is in the background.

## Risks

- **Phone suspended.** iOS suspends the phone app shortly after it leaves the foreground. A watch turn can outlive that, and then nothing is announced. This is the limit the notification settings already state ("while Hermes is running, including for a short time after the user leaves it").
- **No permission yet.** A user who has only ever sent from the watch has never been asked; nothing is posted until a chat on the phone triggers the prompt.
- **Foreground banner.** The app delegate lets a notification show while the phone app is in front, so a watch turn shows a banner on the phone as well as the watch reply.
- **Generic title.** A watch reply into an existing thread is titled "Hermes", not the thread's name.
- **Unverified on device.** Mirroring to the watch is iOS behaviour and is not covered by a test; the check is the user's paired device.

## Platforms and invariants

iOS only, in Dart. `WatchBridge.forAuth` still returns null elsewhere. No native, entitlement, manifest or Xcode change; the watchOS sources are unchanged. Touches no auth, API-layering or telemetry invariant: no REST call, no token handling, no span.
