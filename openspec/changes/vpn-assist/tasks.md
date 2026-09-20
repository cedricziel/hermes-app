# Tasks

## 1. Classify connection failures

- [ ] 1.1 Write failing unit tests for the failure classifier (lookup failure, refused, connect and receive timeout, TLS handshake, HTTP error answer, other) and host kind (`*.ts.net`, `100.64.0.0/10` edges `100.63.x`/`100.64.x`/`100.127.x`/`100.128.x`, RFC 1918, `.local`, public); verify they fail
- [ ] 1.2 Implement the pure classifier under `lib/src/auth/` and verify the tests pass
- [ ] 1.3 Record the last failure on `AuthController` for the status probe, providers request and stored-session check, keeping every existing message string, with tests that drive `FakeHermesServer` to each failure and check `lastFailure` and the unchanged messages

## 2. Hint and guidance on the setup screen

- [ ] 2.1 Add a `NetworkSignals` interface (`changes`, `vpnActive`) with a `connectivity_plus` implementation and a fake in `test/support/`; add the `connectivity_plus` dependency and verify `flutter pub get` and `flutter analyze` are clean
- [ ] 2.2 Write failing widget tests for the hint (tailnet timeout, VPN-state variants, refused, public host with no hint) and the static VPN note, then render them on `ServerSetupScreen` and verify the tests pass
- [ ] 2.3 Reword the helper text so it no longer implies `--host 0.0.0.0` is the only option, and add the README section (Tailscale Serve, WireGuard address, binding to the VPN interface); verify the README renders the section and the screen text matches

## 3. Check again after a network change

- [ ] 3.1 Write failing tests with a fake `NetworkSignals` and `FakeHermesServer`: retry after a change when the last failure was a timeout, one attempt for a burst of changes, none after an HTTP error or malformed response, none while a connect is in flight or while signing in, a successful retry opens the app with tokens kept
- [ ] 3.2 Implement the retry on network change and on app resume in `AuthController` and verify the tests pass
- [ ] 3.3 Add a test that a failing retry leaves the state as connection error and refreshes the message and hint

## 4. Telemetry and housekeeping

- [ ] 4.1 Emit `auth.connect.failed` (`reason`, `host_kind`, `retry`) and add a test that it carries no host or address and that a throwing sink does not break a connect
- [ ] 4.2 Check `.claude/skills/verify-in-app/SKILL.md` for anything this makes stale and update it, or note that nothing changed
- [ ] 4.3 Run `dart format .`, `flutter analyze`, `flutter test`, then a verify-in-app check: start `scripts/dev-backend.sh`, enter an address that times out, see the message and hint, start the backend, and confirm the app connects without tapping Connect
