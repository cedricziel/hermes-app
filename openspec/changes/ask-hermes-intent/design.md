# Design

## Context

See proposal.md for motivation and specs/ask-hermes/spec.md for behavior.

- `headless-runtime` (wave 1, Contract 3) provides `withHeadlessHermes(body, task:, timeout:)`, which builds a connection from the saved server and `TokenStore`, hands the body a `HeadlessHermes` (`repositories`, `profiles()`, `transport()`, the gateway transport), closes the transport afterwards and returns a sealed `HeadlessOutcome<T>`: `HeadlessDone(value)`, `HeadlessSignedOut`, `HeadlessLocked` (secure storage unreadable before the first unlock) or `HeadlessUnreachable`. It also owns the `AppDelegate` hook that registers plugins in a background engine, and the `@pragma('vm:entry-point')` functions in `lib/src/background/entry_points.dart`.
- `app-intents` adds `ios/HermesSurfaceKit` with `ChatEntity` (id `<percent-encoded profile>/<thread id>`) and `ProfileEntity`, the Runner's `HermesAppShortcuts`, and the `hermes_app/intents` channel.
- `WatchRequestHandler.handle({'op': 'send', 'threadId': ..., 'text': ...})` already sends a turn on a `ChatTransport` and waits for it: it binds a thread to `<encoded profile>/<id>`, collects deltas, returns `{ok, threadId, text, failed, tools?}` on `ReplyCompleted`, returns `cannotAnswerText` as soon as the agent asks for an approval, a question, a secret or an unsupported input (including in the turn Hermes runs ahead of the prompt), announces the turn's end through `announce` with `attentionFor`, cuts text to 4000 characters, and closes the transport in `finally`. A null `threadId` starts a new chat in `activeProfile()`.
- App lock keeps its switch in shared preferences under `hermes.app_lock_enabled`.

## Goals / Non-Goals

**Goals:**

- One turn runner for the watch and Siri: reuse `WatchRequestHandler` as it is.
- Never two Dart isolates refreshing tokens at the same time when it can be avoided.
- An answer, or "Still working", within the time Siri allows, and the late reply not lost.

**Non-Goals:**

- A general Dart intent framework. The channel has a handful of named methods.
- Keeping the process alive until any reply finishes, however long.

## Decisions

### How `perform()` reaches Dart

`AskHermesIntent` is compiled into the Runner only and declares `supportedModes = .background` and `authenticationPolicy = .alwaysAllowed`. iOS runs `perform()` in the app's process: in the running app if it is alive (also when suspended, which iOS resumes for the intent), or in a process it launches in the background, where no scene connects and so no Flutter view or implicit engine starts.

`IntentsBridge` (Runner, Swift) picks the engine:

1. **The app's engine, when it exists.** `AppDelegate.didInitializeImplicitFlutterEngine` installs the `hermes_app/intents` channel on the implicit engine's messenger, and Dart calls `ready` on it once its handler is registered in `main`. The bridge uses this engine whenever it has said ready. This keeps the ask in the same isolate as `AuthController`, so the headless runtime can coordinate token refresh with it in one isolate instead of racing it from a second.
2. **Otherwise a background engine.** The bridge asks `headless-runtime`'s background-engine hook for an engine running the `intentsMain` entry point (`lib/src/background/entry_points.dart`), with the plugins that hook registers. `intentsMain` registers the same handler and calls `ready`. The bridge waits up to 5 seconds for it; if it is not ready by then the ask fails with "Hermes isn't available right now."

Lifetime: the background engine is created on first use, reused by an ask that comes while it lives, and destroyed 10 seconds after its last call finished, or when the background task (below) expires. Calls to it are serialized; a second ask while one runs waits for it (Siri does not run two asks at once in practice; Shortcuts automations can). When a scene connects while a background engine still serves an ask, that ask finishes there and new asks go to the app's engine once it has said ready; the background engine is then destroyed at its idle timeout. Two engines exist side by side for at most that overlap.

Plugin registration in the background engine is `headless-runtime`'s. This change needs from it: secure storage and shared preferences (tokens, server URL, app-lock flag, current profile), and the notifications plugin for the late "Reply ready" notification. See Risks for the notifications plugin.

### The ask in Dart

`lib/src/intents/ask_hermes.dart`:

```dart
Future<AskResult> askHermes({
  required String question,
  String? profile,   // resolved in Swift: the parameter, else the snapshot's profile
  String? chatId,    // ChatEntity id, `<encoded profile>/<thread id>`
  required Duration answerWithin, // what is left of the 25 s when Dart starts
  required void Function(AskResult early) answerEarly,
});
```

1. If `hermes.app_lock_enabled` is true, answer `app_locked` at once and do nothing else.
2. Run `withHeadlessHermes(..., task: 'intent.ask', timeout: 3 minutes)` and switch over every `HeadlessOutcome` case: `HeadlessDone` carries the result of the steps below; `HeadlessSignedOut` answers `signed_out` ("Sign in to Hermes first."); `HeadlessLocked` answers `device_locked` ("Unlock your iPhone first."); `HeadlessUnreachable` answers `unreachable` ("Can't reach your Hermes server."). `unavailable` ("Hermes isn't available right now.") is left for a Dart engine that never said ready.
3. In the body, build `WatchRequestHandler(repository: () => hermes.repositories.chat, transport: hermes.transport, activeProfile: () async => profile, announce: ...)` and call `handle({'op': 'send', 'threadId': chatId, 'text': question})`. No `sendId`, so no retry memory.
4. Race that future against `answerWithin`. If the reply comes first, answer with its text (`answered`), or with "Hermes needs your answer…" when the text is `WatchRequestHandler.cannotAnswerText` (`needs_you`), or with "Hermes couldn't answer." when `failed` or `ok: false`. If the deadline comes first, call `answerEarly(still_working)` and keep awaiting the reply in the body.
5. `announce` is gated: a request notification (approval, question, input) is always posted, since the user has to act in the app; a "Reply ready" or "Reply failed" notification is posted only after `still_working` was answered, so an answer given in place is not repeated as a notification. Posting goes through the app's `NotificationService` and `attentionFor`, so the notification is the one the notifications spec defines (title, preview body, per-chat id, tap opens the chat).

The text returned to Swift is the reply as `WatchRequestHandler` cut it (4000 characters). Swift gives Siri a spoken dialog with Markdown markers stripped (`**`, `` ` ``, `#`, list bullets, link targets), and returns the unstripped text as the intent's `String` output for Shortcuts.

`WatchRequestHandler` lives under `lib/src/watch/`, which this rollout must not change, so the Siri wording is substituted by comparing against its public `cannotAnswerText` constant. A later change that moves its send loop to `lib/src/chat/` (with the watch owner) would remove that coupling.

### Timing

Siri gives an intent a little over 30 seconds before it gives up; the user chose about 25. The Swift side owns the clock: it starts at `perform()`, passes Dart the time left (`25 s - elapsed`, so a cold engine start of 1 to 3 seconds is paid out of the same budget), and if Dart has not answered by 25 seconds it answers "Still working — I'll notify you." itself (Dart may still be connecting). The question is sent in any case once Dart has it; the late answer is the notification.

### Keeping the late reply

When the ask has answered `still_working`, the bridge holds a `UIApplication` background task opened at the start of `perform()` until Dart reports the body finished or iOS expires the task (typically about 30 seconds more). On expiry it calls `expire` on the channel, Dart mutes `announce` (closing the transport makes `WatchRequestHandler` announce a failed end, which must not reach the user as "Reply failed"), lets `withHeadlessHermes` close the transport, and the engine is torn down. A reply that finishes after that is announced by `background-refresh`'s finished-reply check the next time it runs; `askHermes` records the chat in the place that check reads (its contract, not redefined here). Until `background-refresh` lands, such a reply shows in the chat but is not announced.

### App lock and the locked device

`authenticationPolicy = .alwaysAllowed` lets the intent run on a locked device. Tokens are readable after the first unlock (`TokenStore`'s iOS accessibility), so before it `withHeadlessHermes` returns `HeadlessLocked` and the intent says "Unlock your iPhone first." App lock is the opt-out: with it on, Dart answers `app_locked` and Swift calls `continueInForeground(_:)`, which asks the user to unlock and opens the app, then hands the question over as `hermes://new?profile=…&prompt=<question>` (Contract 1: prefills, never sends). This holds also when the ask names a Chat: App lock hands over a new chat, so the question is never sent unseen. The app's own lock screen then asks for Face ID as usual.

### Platforms and native changes

- iOS: `AskHermesIntent` and `IntentsBridge` in the Runner, two App Shortcut phrases, the channel installed in `didInitializeImplicitFlutterEngine`. No new target, entitlement or Info.plist key (`supportedModes` needs none). `HermesSurfaceKit` keeps the intent free of UIKit; the background task sits behind `#if canImport(UIKit)` in the bridge.
- Android, macOS, Windows, Linux, watchOS: none.

### Invariants touched

- Auth: the headless runtime never signs the user out and gives up on a refresh conflict (Contract 3). Preferring the app's engine keeps refreshes in one isolate when the app runs. A concurrent 401 in the app is unaffected.
- Tokens: read from secure storage by the runtime only; never crossing the channel.
- Telemetry: recorded in Dart (`ask_hermes.dart`): span `background.task` (`task: intent.ask`, `outcome`, `engine`, `continued`), log event `intent.ask` (`outcome`, `waited_s`), breadcrumbs `intent.ask.started` / `intent.ask.ended` (`outcome`) in the foreground engine only. None carries the question, the reply, a title, a profile name or an id. Failures to record are swallowed.
- API layering: no REST call added; the turn goes over the gateway transport as the chat sends one.
- Tests: `askHermes` is tested with `FakeChatTransport` behind a fake `HeadlessHermes`, and the repository against `FakeHermesServer`.

## Risks / Trade-offs

- [Notifications plugin in a second engine] → `flutter_local_notifications` installs itself as the notification center's delegate when registered; registering it in the background engine could take taps away from the app's engine. `headless-runtime` owns the plugin set; if it cannot register the plugin safely, the late notification is posted by the app's engine when present and otherwise left to `background-refresh`.
- [Two isolates refresh tokens at once] → only in the short overlap when the app opens during a background ask. The runtime gives up quietly on a conflict, so the ask may fail but the app stays signed in.
- [A cold engine eats the budget] → engine start, token read and `session.create` can take several seconds on a slow network; the answer then more often says "Still working". The `intent.ask` log event's `waited_s` shows how often.
- [Siri speaking a long reply] → the reply is cut at 4000 characters; Siri reads it all. A shorter spoken cut was considered and left out: Shortcuts users want the full text and the dialog and output are one result.
- [Anyone with the locked phone can ask] → stated in the proposal; App lock turns it off.
- [The question reaches Hermes even when Siri already said "Still working"] → intended: the answer arrives later.

## Dependencies

- `headless-runtime`: `withHeadlessHermes`, `HeadlessOutcome`, the background-engine hook and `entry_points.dart`.
- `app-intents`: `ios/HermesSurfaceKit`, the Chat and Profile entities, `HermesAppShortcuts` and the `hermes_app/intents` channel.
- `background-refresh` (optional): its finished-reply check announces replies that outlive the background task.
- `deep-links`: the `hermes://new?prompt=` hand-over, through `app-intents`.

## Migration Plan

Nothing to migrate. Rollback removes the intent and the phrases; saved shortcuts that use it fail with iOS's own message.
