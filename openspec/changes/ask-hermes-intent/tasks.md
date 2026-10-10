# Tasks

One PR, `feat(ios): answer "Ask Hermes" from Siri and Shortcuts in place`. Needs `headless-runtime` and `app-intents` merged. No API routes change, so no OpenAPI regeneration.

## 1. The ask in Dart (TDD)

- [ ] 1.1 Write failing tests in `test/intents/ask_hermes_test.dart` with `FakeChatTransport` behind a fake `HeadlessHermes`: new chat in the given profile, a Chat continued in its own profile, reply in time (`answered`, text cut at 4000), empty reply text, failed reply, approval/clarify/vault/unsupported request (`needs_you`, request notification posted), each `HeadlessOutcome` (`HeadlessSignedOut` → `signed_out`, `HeadlessLocked` → `device_locked`, `HeadlessUnreachable` → `unreachable`, nothing sent in any), App lock on (`app_locked`, nothing sent), deadline before the reply (`still_working` answered early, then "Reply ready" posted on completion), and no "Reply ready" when answered in place; implement `lib/src/intents/ask_hermes.dart` on `withHeadlessHermes` and `WatchRequestHandler`; verify the tests pass.
- [ ] 1.2 Write failing tests for the `hermes_app/intents` handler: `ask` arguments parsed (question, profile, chat id, ms left), malformed arguments answered `failed`, `expire` cancels a running ask, `ready` called once after registration; implement `lib/src/intents/intents_channel.dart`, register it in `main` and in an `intentsMain` entry point in `lib/src/background/entry_points.dart`; verify.

## 2. Swift intent and bridge

- [ ] 2.1 Write failing `swift test` cases in `ios/HermesSurfaceKit` for the spoken-text cleanup (bold, code, headings, bullets, links), the dialog chosen for each outcome ("Sign in to Hermes first.", "Unlock your iPhone first.", the unreachable text) and the `hermes://new?profile=&prompt=` hand-over URL; implement them and `AskHermesIntent` (`supportedModes = .background`, `authenticationPolicy = .alwaysAllowed`, `requestValueDialog` for the question, `String` output); verify.
- [ ] 2.2 Implement `IntentsBridge` in the Runner: the app engine when it said ready, else `headless-runtime`'s background engine on `intentsMain` with a 5-second ready wait; serialized calls; 10-second idle teardown; the 25-second clock with the Swift-side "Still working"; a background task held until Dart finishes or iOS expires it (then `expire`); `continueInForeground` and the `hermes://new?prompt=` hand-over for `app_locked`. Add "Ask Hermes" phrases to `HermesAppShortcuts`. Verify `flutter build ios --simulator -d <udid>` succeeds.

## 3. Telemetry

- [ ] 3.1 Write failing tests with a recording tracer, event logger and breadcrumb trail that each outcome records the `background.task` span (`task`, `outcome`, `engine`, `continued`), the `intent.ask` log event (`outcome`, `waited_s` bucket) and, in the foreground engine only, `intent.ask.started`/`intent.ask.ended`, and that no attribute holds the question, reply, title, profile or id; implement; verify.

## 4. Docs and skills

- [ ] 4.1 Update CLAUDE.md (a short "App Intents" paragraph: the bridge's engine choice, the reuse of `WatchRequestHandler`, the 25-second clock) and the `verify-in-app` skill with how to run "Ask Hermes" from the Shortcuts app in the simulator with the app killed, running, and with App lock on.

## 5. Verify

- [ ] 5.1 Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test` and `swift test` in `ios/HermesSurfaceKit`; all pass.
- [ ] 5.2 In the iOS simulator against `scripts/dev-backend.sh` with `HERMES_DEV_MODEL_CALLS=1`: run "Ask Hermes" from Shortcuts with the app killed and with it in the background, check the spoken/output text and that the new chat appears in the app; ask something slow and check "Still working" and the later notification; trigger an approval and check the answer and notification; turn on App lock and check the hand-over. Restore the `ios/`/`macos/` Xcode files the build rewrites, staging files by name.
