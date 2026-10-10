# Design

## Context

See proposal.md for motivation and specs/headless-runtime/spec.md for behaviour. The Dart surface is Contract 3 of the iOS surfaces rollout.

What exists today:

- `AuthController` (`lib/src/auth/auth_controller.dart`) reads the server from `SharedPreferencesAsync` key `hermes.server_base_url` (or the `HERMES_SERVER_URL` define), the session from `TokenStore`, probes `/api/status`, and builds the authenticated `Dio` (`RequestTimeoutInterceptor`, telemetry interceptor, bearer attach, proactive refresh, refresh on 401). `_refreshSession` single-flights refreshes inside one isolate and calls `_handleSessionExpired` (clear storage, show sign-in) when Hermes rejects the refresh token.
- `refreshNativeSession` (`native_login_flow.dart`) repeats an unanswered attempt once with the same token, because Hermes keeps a refresh result for 30 s and answers a repeat of it with the same pair. The identity provider may end the session when a spent refresh token comes back later than that.
- `TokenStore` uses `KeychainAccessibility.first_unlock_this_device` on iOS, and `read()` returns null (without clearing) when the keychain cannot be read.
- `HermesRepositories(api, telemetry:)` builds every repository from one `HermesApiClient`. `HermesGatewayTransport` with `hermesGatewayConnect(baseUrl:, authRequired:, api:, telemetry:)` opens the `/api/ws` socket.
- `AppDelegate` registers all plugins into the implicit engine only (`didInitializeImplicitFlutterEngine`). Several plugins act as scene or application delegates (`receive_sharing_intent`, `live_activities`, later `app_links`, `home_widget`), so registering them in a second engine would double-handle URLs and shares.

## Goals / Non-Goals

**Goals:** reuse the app's repositories and transport unchanged; never sign out from the background; tolerate the foreground and background refreshing at about the same time; testable entirely in Dart with `FakeHermesServer` and an in-memory token store.

**Non-Goals:** task scheduling, consumers, a cross-isolate lock.

## Decisions

### `HeadlessConnection` instead of a headless `AuthController`

`AuthController` mixes connection building with sign-in UI state and the sign-out reaction, which is exactly what must not run here. `headless_hermes.dart` holds a private `HeadlessConnection`:

1. Server: the define, else the saved key (`kSavedServerUrlKey`, now exported from `auth_controller.dart`). None → `HeadlessSignedOut` (`outcome: no_server`).
2. Status: `HermesApiClient.probeStatus()` on a plain `Dio` with `RequestTimeoutInterceptor` (5 s connect). Failure → `HeadlessUnreachable` (`outcome: unreachable`). `authRequired == false` → no session needed.
3. Session: `TokenStore().readState()`, a new method beside `read()` that tells an empty store from an unreadable keychain (`errSecInteractionNotAllowed` before the first unlock). Empty → `HeadlessSignedOut` (`outcome: no_session`); unreadable → `HeadlessLocked` (`outcome: locked`). `read()` keeps its behaviour.
4. Client: `Dio` with `RequestTimeoutInterceptor`, the connection's telemetry interceptor (`Telemetry.forConnection(hermesServerAttributes(status))`) and `_HeadlessAuth`, wrapped in `HermesApiClient` and `HermesRepositories`.

`_HeadlessAuth` attaches the bearer token and refreshes at most once per run, proactively when `needsRefresh()` or after a 401, using compare-and-swap on storage:

- Before refreshing, re-read `TokenStore`. If the stored refresh token differs from the one held, adopt the stored pair (someone else rotated it) and retry without refreshing.
- Refresh with `refreshNativeSession` (same retry rule as the foreground).
- On success, re-read storage: write the new pair only if storage still holds the token that was spent; otherwise keep the stored one and use the new pair for this run only.
- On rejection: end the run with `HeadlessSignedOut` (`outcome: auth_failed`), unless storage changed meanwhile, in which case record `background.refresh_conflict` and end with `HeadlessUnreachable`. On a parse failure or network error: `HeadlessUnreachable` (`outcome: auth_failed`). Storage is never cleared.

Why this is safe without a lock: the foreground and background can only spend the same refresh token if both read it before either wrote the rotated pair. A refresh plus write takes at most two 12 s attempts, so the second spend falls inside Hermes' 30 s replay window and gets the same pair back. Every other ordering makes the second party see the rotated pair in storage and adopt it.

### Foreground adoption in `AuthController`

Peer PR #587 makes the same change for the rejected-refresh case (re-read `TokenStore`, adopt a newer pair before clearing on `refresh_rejected`). Whichever of the two lands second reconciles them into one code path and keeps both sets of tests; this change then only adds what #587 lacks (the `before_refresh` read and the `auth.session.adopted` event).

Two small changes in `_refreshSession` and its 401 handler:

- Before calling `refreshNativeSession`, read `TokenStore`; if it holds a session for the same provider whose refresh token differs from `_session`, adopt it (`_session = stored`, `auth.session.adopted` with `trigger: before_refresh`) and return it when it does not itself need a refresh.
- When the refresh is rejected, read `TokenStore` again before `_handleSessionExpired`; if it holds a different refresh token, adopt it (`trigger: after_rejected`) and retry the request once instead of signing out.

Both reads go through the existing single-flight future, so concurrent 401s in the foreground still share one refresh and one read (invariant kept).

### `withHeadlessHermes` shape

```dart
sealed class HeadlessOutcome<T> {}
final class HeadlessDone<T> extends HeadlessOutcome<T> { final T value; }
final class HeadlessSignedOut<T> extends HeadlessOutcome<T> {}
final class HeadlessLocked<T> extends HeadlessOutcome<T> {}
final class HeadlessUnreachable<T> extends HeadlessOutcome<T> {}

Future<HeadlessOutcome<T>> withHeadlessHermes<T>(
  Future<T> Function(HeadlessHermes hermes) body, {
  required String task,
  Duration timeout = const Duration(seconds: 25),
  @visibleForTesting HeadlessDeps? deps,
});

class HeadlessHermes {
  HermesRepositories get repositories;
  Future<List<String?>> profiles();
  HermesGatewayTransport transport(); // fresh socket, closed when body ends
}
```

Outcome mapping (span `outcome` → result):

| `outcome`       | Result                                               |
| --------------- | ---------------------------------------------------- |
| `ok`            | `HeadlessDone(value)`                                |
| `no_server`     | `HeadlessSignedOut`                                  |
| `no_session`    | `HeadlessSignedOut`                                  |
| `locked`        | `HeadlessLocked`                                     |
| `auth_failed`   | `HeadlessSignedOut` when the refresh was rejected and storage unchanged, else `HeadlessUnreachable` |
| `unreachable`   | `HeadlessUnreachable`                                |
| `timeout`       | `HeadlessUnreachable`                                |
| `failed`        | `HeadlessUnreachable`                                |

`HeadlessSignedOut` after a rejected refresh only says what the background saw; it never clears storage, and the app in front decides on its own refresh. A timeout and a failed body are reported as unreachable because to a caller (Siri, a notification action) they mean the same: Hermes did not answer in time; telemetry keeps them apart. Callers switch exhaustively over the sealed type, so a new case breaks their build.

`task` names the span and is required, so every run is attributable. `deps` injects preferences, token store, `Dio` adapter and clock for tests. The whole run (connect plus body) races `timeout`; on expiry, open transports are closed and `HeadlessUnreachable` is returned. Errors from `body` are caught and logged as `outcome: failed` with `error.type`; nothing is rethrown, because a background callback that throws is reported to iOS as a failure and can lower future scheduling. `HeadlessHermes.transport()` builds a `HermesGatewayTransport` (the app's `ChatTransport` implementation, returned with its concrete type so callers can also use `request` and `answerOpenRequest`) per call and tracks it for closing; `profiles()` returns `repositories.profiles.list()` names, falling back to `[null]` (the server's default profile) when the list fails.

### Isolate setup in `entry_points.dart`

`prepareBackgroundIsolate()` (idempotent) calls `WidgetsFlutterBinding.ensureInitialized()`, `DartPluginRegistrant.ensureInitialized()` and `Telemetry.initialize(TelemetryConfig.fromEnvironment())` once, and makes the telemetry instance available to `withHeadlessHermes`. Consumers' `@pragma('vm:entry-point')` functions call it first.

### `BackgroundPlugins.swift`

`enum BackgroundPlugins { static func register(with registry: FlutterPluginRegistry) }` registers only `flutter_secure_storage`, `shared_preferences_foundation`, `path_provider_foundation`, `package_info_plus` and `flutter_local_notifications`, each through its own `registrar(forPlugin:)`. Consumers pass it to their plugin's registrant callback (`WorkmanagerPlugin.setPluginRegistrantCallback`, `FlutterLocalNotificationsPlugin.setPluginRegistrantCallback`). Later changes append `home_widget`. URL, share, Live Activity, picker and UI plugins are left out on purpose.

Platforms affected: iOS (new Swift file in the Runner target). The Dart runtime is platform-neutral and also runs in Android WorkManager's engine, which registers all plugins itself. No entitlement, manifest or Info.plist change.

### Invariants touched

- Auth: "concurrent 401s must not sign the user out" is extended across isolates: the foreground adopts a rotated pair instead of signing out, and the background never signs out. Tokens stay in secure storage only.
- API layering: the runtime uses the generated client through `HermesRepositories`; only `/api/status` goes through the existing hand-written call.
- Telemetry: the span is recorded in `withHeadlessHermes` with `task`, `outcome` (`ok`, `no_server`, `unreachable`, `no_session`, `locked`, `auth_failed`, `timeout`, `failed`) and `hermes.*`; `background.refresh_conflict` in `_HeadlessAuth`; `auth.session.adopted` in `AuthController` with `trigger`. None holds a token, URL or text. Telemetry failures are swallowed through `safely`.
- Tests: `FakeHermesServer` for HTTP, `MemoryTokenStore` for storage.

## Risks / Trade-offs

- [iOS gives a background run about 30 s and may kill it sooner] → 25 s default budget, connect timeouts of 5 s, and the body decides what to skip.
- [Keychain unreadable before first unlock] → `HeadlessLocked`, nothing changes; the next run tries again, and Siri can say "Unlock your iPhone first".
- [A second engine double-handles notifications] → only `flutter_local_notifications` of the delegate-style plugins is registered, and the background isolate never sets a tap handler; verify in the simulator that a tap opens the app once (task 4.2).
- [Foreground adoption reads the keychain on every refresh] → one read per refresh, already single-flighted; refreshes are rare.
- [An identity provider that ends the session on any reuse] → the 30 s replay window covers the only overlapping order; outside it the background gives up and the foreground adopts, so the user is never signed out by this change.

## Migration Plan

No stored format changes. Rollback removes the runtime; the foreground adoption is harmless without it.

Once both this change and #587 are on main, `RequestAnswerSender`'s `_answerAlone` bootstrap moves onto `withHeadlessHermes(task: 'answer_request')`, so one headless path remains.
