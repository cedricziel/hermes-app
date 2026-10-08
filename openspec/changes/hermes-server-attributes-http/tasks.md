One PR, `feat(telemetry): describe the Hermes server on HTTP and auth telemetry`, about 400 lines with tests.

## 1. Status to attributes

- [ ] 1.1 Failing tests for `hermesServerAttributes`: a full status answer maps to the ten `hermes.*` attributes; absent fields are left out; a wrong-typed field (`config_version: "seven"`, `profiles: "x"`) drops only that attribute; `gateway_mode: unknown` drops `hermes.profile.count`; an ungated answer with `hermes_home`, `config_path`, `env_path`, `gateway_pid`, `gateway_health_url`, `gateways` and profile names yields none of those values. Then implement it
- [ ] 1.2 Failing test that `HermesStatus.fromJson` with `config_version: "seven"` still parses and exposes `serverAttributes` without it; then wire it in

## 2. Connection instruments

- [ ] 2.1 Failing tests for `Telemetry.forConnection`: the interceptor's span and request log carry the map under the request's own attributes; the event logger's log record carries the map under the call's attributes, while the breadcrumb trail records only the call's; with telemetry off it returns no interceptor and the no-op logger. Then implement it

## 3. AuthController

- [ ] 3.1 Failing test through `FakeHermesServer` and the in-memory exporters: after connecting and signing in, the authenticated request, the token refresh request, `auth.sign_in.*`, `auth.session.refreshed` and `server.connected` carry the server's `hermes.*`; the probe, `auth.state connecting` and a failed probe's `auth.connect.failed` carry none. Then replace `interceptors`/`events` with the connection factory and hold `_connectionTelemetry`
- [ ] 3.2 Failing test: sign out and back in, and the second sign-in carries the same attributes; Change Server then connect to B, and nothing after Change Server carries A's `install_id`; connected to A, a failed probe of a new address logs `auth.connect.failed` without A's attributes; reconnect to A reporting a new `version` shows the new value. Then reset on `connect()` and `changeServer()`
- [ ] 3.3 Failing test: a request to A that finishes after connecting to B keeps A's attributes
- [ ] 3.4 Failing test: a crash after connecting lists a `server.connected` breadcrumb with only `hermes.version`, and no other breadcrumb has a `hermes.*` attribute
- [ ] 3.5 Update `lib/main.dart` to pass the factory

## 4. Contract, docs and skills

- [ ] 4.1 Extend `test/real_backend_contract_test.dart`: `/api/status` has `version` (string), `config_version` (int), `auth_required` (bool), `auth_providers` (list of strings), `gateway_mode` (string), `profiles` (list of strings), `gateway_state`, `overall` (`ok` or `degraded`), and `install_id` when present
- [ ] 4.2 Update the Telemetry paragraph in `CLAUDE.md` (per-connection interceptor and events, `hermes.*`, `server.connected`)
- [ ] 4.3 Update the `observability` skill with the `hermes.*` attributes and example queries (distinct servers by `hermes.install_id`, failed sign-ins by `hermes.version`)

## 5. Verify

- [ ] 5.1 `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, and the targeted tests (`test/telemetry_test.dart`, the auth controller tests, the new tests); CI runs the full suite
- [ ] 5.2 `verify-in-app` against `scripts/dev-backend.sh` with a loopback OTLP collector: connect, sign in, sign out, Change Server, and check the exported records match the spec
- [ ] 5.3 `openspec validate hermes-server-attributes-http`
