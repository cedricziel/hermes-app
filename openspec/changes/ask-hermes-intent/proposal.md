# Proposal

## Why

The quickest question to Hermes is one asked without picking up the phone: "Hey Siri, ask Hermes how many tickets are open" while driving, or a Shortcuts automation that passes text in and reads the answer out. Today every Hermes conversation needs the app on screen. The user wants Siri and Shortcuts to answer in place, the same way the watch already does through the phone (`WatchRequestHandler` sends a turn and waits for its reply).

## What Changes

- An "Ask Hermes" App Intent that runs without opening the app. It takes the question (Siri asks for it when it is missing), an optional Profile and an optional Chat (both the entities from `app-intents`).
- Without a Chat each ask starts a new chat in the profile (the app's current one by default); with a Chat it continues that chat.
- It waits up to about 25 seconds and returns the reply's text: Siri speaks it, Shortcuts gets it as the intent's output. A reply that takes longer returns "Still working — I'll notify you", and the reply arrives later as the usual "Reply ready" notification. If Hermes asks for an approval or an answer during the turn, the intent says so ("Hermes needs your answer. Open the chat in Hermes.") and the usual request notification is posted.
- The intent is allowed while the device is locked (the user's explicit choice). When the app's own App lock is on, it does not answer in place: it asks to continue in the app, which needs the device unlocked, and opens a new chat with the question in the composer, unsent.
- When Hermes cannot answer, Siri says why: "Sign in to Hermes first." when nobody is signed in, "Unlock your iPhone first." before the first unlock after a restart, and "Can't reach your Hermes server." when the server does not answer.
- App Shortcut phrases "Ask Hermes" and "Ask Hermes something".
- The intent runs Dart through the headless runtime (`headless-runtime`, `withHeadlessHermes`) in the app's own process: in the running app's engine when there is one, else in a background engine started for the ask.

Non-goals:

- No pending-requests or answer-approval intents (the `request-intents` change).
- No answering an approval or question inside Siri during an ask.
- No voice conversation with follow-up turns in Siri; one question, one answer.
- No attachments, model choice or slash commands in an ask.
- No Android, macOS or watch equivalent (the watch keeps its own relay).
- No change to `WatchRequestHandler` or anything under `lib/src/watch/`; this change uses it as it is.

Security and privacy impact:

- Allowed while locked means anyone holding the locked phone can ask Hermes a question by voice and hear the answer, in a chat that can run tools on the user's server. Siri may also speak the answer aloud where others hear it. That was chosen deliberately; the mitigations are: the intent only sends what was said and returns the reply, it cannot answer approvals or questions (so a dangerous command still needs the unlocked phone), it does not work before the first unlock after a restart (the tokens are readable only after first unlock; it says "Unlock your iPhone first."), and turning on App lock in Hermes turns in-place answering off. A Settings switch is not added; App lock is the opt-out.
- Tokens stay in secure storage; the headless runtime reads and, when it must, refreshes them as the app would (Contract 3). Nothing new is written to the App Group or preferences.
- The question and the reply text cross the method channel between Swift and Dart in memory only; they are never logged, traced or stored outside Hermes' own chat history.

Observability:

- Span `background.task` (from `headless-runtime`) with `task: intent.ask` and `outcome` (`answered`, `still_working`, `needs_you`, `failed`, `signed_out`, `device_locked`, `unreachable`, `unavailable`, `app_locked`), plus `engine` (`foreground` or `headless`) and `continued` (whether a Chat was given). It crosses the native/Dart boundary and a socket, so it is a span; it carries no text, title, profile or id.
- Log event `intent.ask` through `AppEventLogger` with the same `outcome` and a `waited_s` bucket (`<5`, `<15`, `<25`, `late`), to count how often answers make the 25-second window.
- Breadcrumbs `intent.ask.started` and `intent.ask.ended` (`outcome`) when the ask runs in the foreground engine, so a crash in the app right after an ask is explained.

## Capabilities

### New Capabilities

- `ask-hermes`: the "Ask Hermes" App Intent: inputs, where the turn runs, the in-place answer and the late notification, behavior while locked and under App lock, and the gateway contract it relies on.

### Modified Capabilities

None. The "Reply ready" and request notifications it posts are the notifications spec's own.

## Impact

- Swift: `AskHermesIntent` in `ios/HermesSurfaceKit` (Runner only, since it needs the app process), an `IntentsBridge` in the Runner that picks the engine and calls Dart over `hermes_app/intents`, a background task that keeps the process alive while a late reply is awaited, two phrases in `HermesAppShortcuts`.
- Dart: `lib/src/intents/ask_hermes.dart` (the ask, on `withHeadlessHermes` and `WatchRequestHandler`), the `hermes_app/intents` handler registered in the main isolate and in an `@pragma('vm:entry-point')` function in `lib/src/background/entry_points.dart`.
- Depends on `headless-runtime` (`withHeadlessHermes`, `HeadlessOutcome` and its background-engine hook in `AppDelegate`), `app-intents` (Chat and Profile entities, the shortcuts provider, the channel) and, for replies longer than iOS keeps the process alive, `background-refresh`'s finished-reply check.
- Backend: no new routes. Uses `session.create`, `session.resume`, `prompt.submit` and the reply events the chat already maps.
