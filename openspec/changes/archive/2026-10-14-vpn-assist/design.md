# Design

## Context

- `AuthController.connect` (`lib/src/auth/auth_controller.dart`) already keeps stored tokens on a network failure, prefills the setup field with the saved address, and shows the setup screen for `connectionError`. Those parts of the original idea need no work; the gaps are the message, the missing hint and the missing retry.
- The status probe, providers request and identity request each map a `DioException` to a message through `_describeDioError`, which returns one fallback string for every network failure.
- HTTP goes through Dio's default adapter (`dart:io`), not `NSURLSession`. App Transport Security does not apply to it, so plain HTTP to a `.ts.net` or `100.x` host works on iOS as well. Cleartext is therefore not a failure class here, and the earlier suspicion that iOS blocks it does not hold for this app.
- The chat socket (`HermesGatewayTransport._client`) opens a new connection on the next send when the previous one closed. A dropped VPN already fails that one reply and the next send recovers. Verified on `main` (0.1.18).
- Notifications only exist while the app holds a live socket (`openspec/specs/notifications`). Unchanged.

## Goals / Non-Goals

**Goals:**

- One pure, unit-testable classifier: `(DioException, Uri) -> ConnectFailure` with `kind` and `hostKind`.
- One retry path driven by an injectable "network changed" stream, testable without the plugin.

**Non-Goals:**

- No VPN state in the controller's public state. The hint reads it at render time.
- No changes to the chat transport, the login flow or token storage.

## Decisions

1. **Classify from the error, hint from the address.** Kind comes from `DioException.type` and the wrapped `SocketException` (`OSError.errorCode`/message for lookup failure and refusal, `HandshakeException`/`TlsException` for TLS). Host kind comes from parsing the host: `.ts.net`, `.local`, an IPv4 literal in `100.64.0.0/10` or RFC 1918. The alternative, asking a plugin whether a VPN is on, fails on iOS and macOS and says nothing about whether the server is reachable.
2. **Store the last failure on `AuthController`** (`lastFailure`, cleared on a new connect) so the setup screen renders hint text from it and the retry logic can tell network failures from others. The user-facing message strings stay exactly as specified today.
3. **`connectivity_plus` is a trigger and a hint source, nothing else.** A small `NetworkSignals` interface exposes `Stream<void> changes` (debounced 1 s) and `bool? vpnActive` (`null` where the platform cannot tell: iOS, macOS, Linux; a value on Android and Windows). The production implementation wraps the plugin; tests pass a fake. Alternative considered: `NWPathMonitor` and `ConnectivityManager` through our own platform channels. Rejected: more native code to keep for a trigger.
4. **Retry from `AuthController`,** subscribed to `changes`, which the plugin-backed implementation also fires on app resume. It calls `connect(saved)` only when `state == connectionError`, the address that failed is the saved one and `lastFailure` is retryable. The setup screen is already showing, so the `connecting` state only turns the Connect button into a spinner, which is the "checking again" feedback, and it keeps a user tap from racing the retry.
5. **Guidance text is static.** A short paragraph under the existing helper text and a README section. No in-app browser and no deep links. The existing helper text ("hermes dashboard --host 0.0.0.0") is reworded so it no longer suggests binding to all interfaces as the only option.

## Platforms

- iOS, Android, macOS, Windows, Linux: the retry and classifier are Dart only. `connectivity_plus` adds its native part on each of them.
- Android: no manifest change; the plugin's own manifest declares `ACCESS_NETWORK_STATE`. `usesCleartextTraffic` stays as is.
- iOS, macOS: no Info.plist, entitlement or Xcode change. `ios/Runner.xcodeproj` and `macos/` may be rewritten by a build; stage files by name.
- watchOS: unaffected.

## Invariants touched

- Auth: a retry must not sign the user out or leave sign-in spinning. It only calls `connect`, which keeps tokens on a network failure, and it never runs during `signingIn`.
- Telemetry: the new event is emitted through the existing `_events` helper, which swallows failures. It carries no host or address.
- API layering: no new REST calls.

## Risks / Trade-offs

- [iOS/macOS emit noisy or duplicate connectivity events] → debounce and the "no connect in flight" guard; an extra `GET /api/status` is cheap.
- [Error classification depends on `dart:io` error text, which differs per OS] → classify on `OSError.errorCode` where possible, fall back to message matching, and default to "other" (no hint, same message as today). A wrong guess never blocks a connection.
- [Hint shown when the real cause is a wrong address] → the hint is worded as a question and appears only for VPN-looking addresses.
- [Retry connects to a server the user did not intend after they edit the field] → the retry uses the saved address only, and is skipped while the user's own submitted connect is running.
- [New dependency and native code on six platforms] → the plugin is widely used and first-party-maintained; the fake keeps tests off the plugin.

## Open Questions

- Copy for the setup note and the three hints can be refined in review without changing the specs' behavior.
