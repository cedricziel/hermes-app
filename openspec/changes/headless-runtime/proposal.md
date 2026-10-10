# Proposal

## Why

Background refresh, App Intents ("Ask Hermes" while the phone is locked) and notification actions all need to talk to Hermes with no screen: no `AppShell`, no `AuthController` driving sign-in, often in a separate Flutter engine that iOS started for a few seconds. Today every request goes through `AuthController`, which is built for the foreground: on a rejected refresh it clears the stored session and shows the sign-in screen. Running that in the background would sign the user out behind their back, and running two independent refreshers (foreground and background) against Hermes' rotating refresh tokens can spend a token twice. One small, shared headless runtime with its own conservative token rules lets every later surface reuse the app's repositories and gateway transport safely.

## What Changes

- A new `withHeadlessHermes(body, {task, timeout})` runs `body` with a `HeadlessHermes` that holds the app's repositories (the same `HermesRepositories` the screens use), the list of profiles, and a gateway `ChatTransport` on a fresh socket that is closed when `body` ends.
- It connects to the saved server (or the `HERMES_SERVER_URL` define) with the session from secure storage and returns a `HeadlessOutcome<T>`, a sealed type every caller handles case by case:
  - `HeadlessDone(value)`: the work ran;
  - `HeadlessSignedOut`: no server saved, no session stored, or the server rejected the refresh token;
  - `HeadlessLocked`: secure storage is not readable yet (before the first unlock after a restart);
  - `HeadlessUnreachable`: the server did not answer, the refresh failed without a rejection, the time budget (25 s by default) ran out, or the work threw.

  None of them touches stored state.
- It refreshes an expired access token with the stored refresh token and writes the new pair back only when storage still holds the pair it started from. It never clears the stored session and never signs the user out; a rejected or conflicting refresh means "give up quietly".
- The foreground `AuthController` learns to adopt a session that background work has already rotated: before it refreshes, and when a refresh is rejected, it re-reads secure storage and, if that holds a newer pair, uses it instead of signing the user out.
- iOS gets a curated plugin list for background engines (`BackgroundPlugins.register(with:)`), so the plugins the runtime needs work in a second engine without registering UI and URL-handling plugins twice.
- `lib/src/background/entry_points.dart` holds the isolate setup every `@pragma('vm:entry-point')` function calls first.

Non-goals:

- No consumer yet: background refresh, intents and notification actions arrive in their own changes. This change ships the runtime, its tests and the foreground fix.
- No scheduling (BGTaskScheduler, WorkManager); that is `background-refresh`.
- No `refreshSnapshot()`: `background-refresh` adds it, since it needs `surface-snapshot`.
- No sign-in, server change or token creation in the background.
- No macOS, Windows or Linux background engine.

Security and privacy impact: background code reads the same keychain entry as the app (`first_unlock_this_device`, unchanged), so it works on a locked phone only after the first unlock since boot. Tokens never leave secure storage or the in-memory client, are never logged or written to preferences or the App Group. The runtime can rotate tokens while the app is suspended; the foreground now re-reads storage rather than trusting its in-memory copy, which also closes an existing gap with conversation windows' engines. Telemetry carries no token, URL or message text.

Observability:

- Span `background.task` (attributes `task`, `outcome` and the connection's `hermes.*` server attributes): a background run takes seconds and crosses the network, and iOS kills it without warning, so the span shows how far it got and how long it took.
- Log event `auth.session.adopted` (`trigger`: `before_refresh`, `after_rejected`) from `AuthController`: counting it shows how often background work rotates tokens under the foreground, which is the race this change guards.
- Log event `background.refresh_conflict` (no attributes beyond the connection's): a refresh the runtime gave up on because storage changed under it.
- No breadcrumbs: nothing here is a user step.

## Capabilities

### New Capabilities

- `headless-runtime`: running Hermes work without a screen: which session it uses, when it gives up, how it refreshes tokens without signing anyone out, its time budget, and how the foreground app picks up tokens it rotated.

### Modified Capabilities

None in `openspec/specs/`. The foreground adoption rule is stated in the new capability so it is reviewed with the race it closes; `auth` is synced when this change is archived.

## Impact

- Dart: new `lib/src/background/headless_hermes.dart` and `entry_points.dart`; `AuthController._refreshSession` and its 401 path re-read `TokenStore`; the saved-server preferences key becomes a shared constant.
- iOS: new `ios/Runner/BackgroundPlugins.swift`, added to the Runner target in `project.pbxproj`. No entitlement or Info.plist change in this change.
- Dependencies: none inside this set of changes. Overlaps peer PR #587, which also makes `AuthController` re-read `TokenStore` and adopt a newer pair before signing out on a rejected refresh. Whichever lands second reconciles the two into one adoption path. Once both are on main, `RequestAnswerSender`'s own bootstrap (`_answerAlone` in `lib/src/notifications/request_answers.dart`) is replaced by `withHeadlessHermes`.
- Backend: `GET /api/status`, `POST /auth/native/refresh`, `GET /api/profiles`, and the `/api/ws` gateway, all already used.
