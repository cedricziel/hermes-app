## Why

Cancelling sign-in can leave the login screen on the "Continue in your browser…" spinner. `runNativeLogin` awaits `closeBrowser()` in its `finally` block, and on iOS that is a platform call. If the user taps Cancel in that window, the login result has already been produced, so the flow returns a session instead of throwing `NativeLoginCancelled`. `signInWithProvider` then sees the cancel signal, discards the session and returns without setting a state. The state stays `signingIn` and Cancel is now a no-op, so the user is stuck. This breaks the rule that sign-in is never left spinning (#86).

## What Changes

- When a cancel arrives after the flow already returned a session, the late session is still discarded, and the state now goes to needs login, like every other cancel.
- If the user left the server or signed out while the flow was finishing, the state stays where that action put it (unchanged).
- The spec gains a scenario for a cancel that arrives while the browser is closing.

## Impact

- Auth: `lib/src/auth/auth_controller.dart` (`signInWithProvider`).
- Tests: `test/auth_controller_sign_in_test.dart`.
- No change to the generated API client, routes or native code.

## Non-goals

- Restructuring `runNativeLogin` or making `closeBrowser()` non-blocking.
- Changing what a cancel does while the token exchange is in flight (already covered by the existing scenario).

## Security impact

None. The late session is discarded and never written to secure storage, exactly as before. The change only fixes which state the app ends in.

## Telemetry impact

None. This path already records `auth.sign_in.cancelled` before returning, so the outcome is reported. No new event, span or attribute is needed.
