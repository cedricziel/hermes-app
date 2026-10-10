# Tasks

One PR, `feat(background): run Hermes work without a screen`. About 500 changed lines with tests (runtime ~200, AuthController ~40, Swift ~30, tests ~230). No API routes change, so no OpenAPI regeneration. No UI.

## 1. Groundwork

- [ ] 1.1 Export `kSavedServerUrlKey` from `auth_controller.dart`. Build on #587's adoption on main (`HermesSession.serverUrl`/`mintedAt`, `sameOwner`, `isNewerThan`, `_adoptStored`); extract the adoption predicate into a shared function only if `_HeadlessAuth` needs it, keeping `test/auth_controller_refresh_test.dart` green; verify.

## 2. Headless runtime (TDD)

- [ ] 2.1 Write failing tests in `test/background/headless_hermes_test.dart` with `FakeHermesServer` and `MemoryTokenStore`: `HeadlessSignedOut` with no saved server and with no session, `HeadlessLocked` when the store reports the keychain unreadable, `HeadlessUnreachable` for an unreachable server; `authRequired: false` runs without a session; repositories reach the server with the bearer token; `profiles()` lists names and falls back to the default profile; the body's error and a timeout give `HeadlessUnreachable` and close transports; success gives `HeadlessDone(value)`.
- [ ] 2.2 Write failing token tests: an expired access token is refreshed and written back; a pair rotated in storage meanwhile is adopted instead of refreshed; storage changed during the refresh is left alone; a rejected refresh gives `HeadlessSignedOut` and leaves storage untouched; a network error during refresh gives `HeadlessUnreachable`; at most one refresh per run.
- [ ] 2.3 Add `TokenStore.readState()` (empty, session, unreadable) with a test for each, keeping `read()` as is. Implement `lib/src/background/headless_hermes.dart` (`HeadlessOutcome` and its four cases, `withHeadlessHermes`, `HeadlessHermes`, `HeadlessConnection`, `_HeadlessAuth`) and `entry_points.dart` (`prepareBackgroundIsolate`); verify 2.1 and 2.2 pass.

## 3. Telemetry

- [ ] 3.1 Write failing tests with a recording tracer and event logger: one `background.task` span per run with `task`, each `outcome` and the `hermes.*` attributes; `background.refresh_conflict` on a storage conflict; no token, URL or text in any attribute. Implement; verify.

## 4. iOS background plugins

- [ ] 4.1 Add `ios/Runner/BackgroundPlugins.swift` registering the curated plugins, add it to the Runner target; verify `flutter build ios --simulator -d <udid>` succeeds and restore the Xcode files the build rewrites except `project.pbxproj`'s new file reference.
- [ ] 4.2 Temporarily call `BackgroundPlugins.register` from a debug-only second `FlutterEngine` running `prepareBackgroundIsolate` plus a `withHeadlessHermes` read of the profiles against `scripts/dev-backend.sh` in the simulator; confirm in the log that it returns profiles, that tapping a notification afterwards opens the app once, then remove the debug hook.

## 5. Replace `RequestAnswerSender`'s bootstrap

- [ ] 5.1 Write a failing test that `LoneAnswerer` (`lib/src/notifications/request_answers.dart`) answers through `withHeadlessHermes(task: 'answer_request')` and maps each outcome to its existing fallback (open the app); replace its own `AuthController`/transport bootstrap; verify.

## 6. Docs and skills

- [ ] 6.1 Add a "Headless runtime" paragraph to CLAUDE.md (Architecture: when to use `withHeadlessHermes`, the never-sign-out rule, `BackgroundPlugins`) and a note to the `verify-in-app` skill on checking background work in the simulator's log.

## 7. Verify

- [ ] 7.1 Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze` and `flutter test`; all pass.
- [ ] 7.2 verify-in-app on macOS against `scripts/dev-backend.sh`: sign in, let the access token expire (short TTL on the dev backend), confirm the app refreshes and stays signed in (connection behaviour changed).
