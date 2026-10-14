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
2. Keychain: `TokenStore().readState(repair: false)` is read before any request, so a locked keychain ends the run (`outcome: locked`) without one. `repair: false` makes it read-only: it neither saves the session again under the current options nor clears a value it cannot parse.
3. Status: `HermesApiClient.probeStatus()` on a plain `Dio` with `RequestTimeoutInterceptor` (5 s connect). Failure → `HeadlessUnreachable` (`outcome: unreachable`). `authRequired == false` → no session needed.
4. Session: `readState()` is a new method beside `read()` that tells an empty store from an unreadable keychain (`errSecInteractionNotAllowed` before the first unlock). Empty, or minted by another dashboard → `HeadlessSignedOut` (`outcome: no_session`), after the status request, since a server without the auth gate needs no session. `read()` keeps its behaviour.
5. Client: `Dio` with `RequestTimeoutInterceptor`, the connection's telemetry interceptor (`Telemetry.forConnection(hermesServerAttributes(status))`) and `_HeadlessAuth`, wrapped in `HermesApiClient` and `HermesRepositories`.

`_HeadlessAuth` attaches the bearer token and refreshes at most once per run, proactively when `needsRefresh()` or after a 401, using compare-and-swap on storage:

- Before refreshing, re-read `TokenStore`. If the stored pair `sameOwner` the held one, has the same `serverUrl` and `isNewerThan` it, adopt it (someone else rotated it) and retry without refreshing. The same predicate `AuthController._adoptStored` uses on main; no second definition.
- Refresh with `refreshNativeSession` (same retry rule as the foreground).
- On success, re-read storage: write the new pair (with its `serverUrl` and a fresh `mintedAt`) only if storage still holds the token that was spent and no pair that `isNewerThan` it; otherwise keep the stored one and use the new pair for this run only.
- On rejection: end the run with `HeadlessSignedOut` (`outcome: auth_failed`), unless storage changed meanwhile, in which case record `background.refresh_conflict` and end with `HeadlessUnreachable`. On a parse failure or network error: `HeadlessUnreachable` (`outcome: auth_failed`). Storage is never cleared.

Why this is safe without a lock: the foreground and background can only spend the same refresh token if both read it before either wrote the rotated pair. A refresh plus write takes at most two 12 s attempts, so the second spend falls inside Hermes' 30 s replay window and gets the same pair back. Every other ordering makes the second party see the rotated pair in storage and adopt it.

### Foreground adoption in `AuthController` (on main)

#587 already gives `AuthController` what this change needs: `HermesSession` carries `serverUrl` and `mintedAt`; the controller re-reads `TokenStore` before every refresh, and when a refresh is rejected `_refreshRejected` re-reads it (again 1 s later) and `_adoptStored` takes over a stored pair only if it `sameOwner` the spent one, has the controller's `serverUrl` and `isNewerThan` it, logging `auth.session.adopted`. This change adds nothing to `AuthController` beyond exporting `kSavedServerUrlKey`.

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
- Telemetry: the span is recorded in `withHeadlessHermes` with `task`, `outcome` (`ok`, `no_server`, `unreachable`, `no_session`, `locked`, `auth_failed`, `timeout`, `failed`) and `hermes.*`; `background.refresh_conflict` in `_HeadlessAuth`; `auth.session.adopted` stays as `AuthController` logs it on main. None holds a token, URL or text. Telemetry failures are swallowed through `safely`.
- Tests: `FakeHermesServer` for HTTP, `MemoryTokenStore` for storage.

## Risks / Trade-offs

- [iOS gives a background run about 30 s and may kill it sooner] → 25 s default budget, connect timeouts of 5 s, and the body decides what to skip.
- [Keychain unreadable before first unlock] → `HeadlessLocked`, nothing changes; the next run tries again, and Siri can say "Unlock your iPhone first".
- [A second engine double-handles notifications] → only `flutter_local_notifications` of the delegate-style plugins is registered, and the background isolate never sets a tap handler; verify in the simulator that a tap opens the app once (task 4.2).
- [Foreground adoption reads the keychain on every refresh] → one read per refresh, already single-flighted; refreshes are rare.
- [An identity provider that ends the session on any reuse] → the 30 s replay window covers the only overlapping order; outside it the background gives up and the foreground adopts, so the user is never signed out by this change.

## Migration Plan

No stored format changes. Rollback removes the runtime; the foreground adoption is harmless without it.

`LoneAnswerer` (`lib/src/notifications/request_answers.dart`), which builds its own `AuthController` and transport in the iOS background isolate, moves onto `withHeadlessHermes(task: 'answer_request')`, so one headless path remains.

## As built

Where the build differed from the plan above:

- `AuthController` gained no behaviour. The saved-server key (`kSavedServerUrlKey`), the dev define (`kDevServerUrlDefine`) and the URL normalizer (`normalizeServerUrl`) are exported from it, and the no-gate page token moved to `auth/page_token.dart` (`PageToken`, `pageTokenInterceptor`), so a headless run against a dashboard without the auth gate sends the same header the app does.
- `TokenStore.readState({repair})` returns a sealed `SessionRead` (`SessionFound`, `SessionEmpty`, `SessionUnreadable`); `read()` is built on it.
- `HeadlessDeps` is a plain class, not `@visibleForTesting`, because `LoneAnswerer` passes it through. A run uses the device's parts unless told otherwise.
- `profiles()` returns `List<String?>` (`[null]` when the list fails or is empty), as designed; Contract 3 in the rollout notes says `List<String>`.
- `BackgroundPlugins` also registers `device_info_plus` (the telemetry resource reads it) and has no `path_provider_foundation`, which is Dart-only on iOS. `NotificationActions.registerPlugins` calls it and adds the Runner's own channels.
- `LoneAnswerer(transportFor:, deps:)` replaces `createAuth`/`transportFor(auth)`. `answerRequestInBackground` calls `prepareBackgroundIsolate()`, so telemetry is now initialized in that isolate too; its spans are exported in batches, so a run that iOS suspends first may lose its span.
- A rejected refresh re-reads storage, again after `rejectionRecheck` (1 s), as `AuthController` does: a pair that `sameOwner` and `isNewerThan` is adopted; any other changed pair ends the run as `HeadlessUnreachable` and logs `background.refresh_conflict`.
- Ending a run (`_Run.close`) stops new requests and refreshes, waits up to `closeGrace` (3 s) for a refresh in flight so its pair is stored before the caller lets iOS suspend the app, then closes every socket and `Dio`. A refresh only starts with at least `minRefreshBudget` (4 s) left and its attempts are cut to fit the budget, so the budget cannot end a run between the server rotating the token and the write. The storage read before the write-back does not skip it when the read fails, and a failed write logs `auth.session.store_failed`.
- A body that gets through despite a failed session keeps its result; one that fails after it reports the auth outcome. `profiles()` throws once the session has failed.
- Only a keychain that reports `errSecInteractionNotAllowed` (-25308) is `HeadlessLocked`; other read errors are `HeadlessUnreachable`.
- Not done: the window between the write-back's read and its write cannot be closed without an atomic compare-and-set in the keychain, which the plugin lacks; the read is directly before the write.
- `LoneAnswerer` checks App Lock before `withHeadlessHermes`, so a locked app never touches the server or the tokens.

