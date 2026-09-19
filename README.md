# hermes-app

A Flutter client for [Hermes Agent](https://github.com/NousResearch/hermes-agent)
(by [Nous Research](https://nousresearch.com))'s web dashboard — connect to a
self-hosted `hermes dashboard` instance and sign in with either an OIDC
identity provider or a username/password.

## Status

Bootstrap scaffold: server discovery, sign-in (OIDC + password, both via the
same native flow — see below), token storage/refresh, and a minimal
authenticated home screen that reads `/api/status` and `/api/auth/me`. It is
the foundation for the real chat/session UI, not that UI itself.

## How auth works

Hermes Agent's dashboard (`hermes_cli/dashboard_auth/`) gates the API behind
one or more pluggable providers — OAuth/OIDC (Nous Portal, or any
self-hosted OpenID Connect IdP) and a bundled username/password provider —
and exposes an RFC 8252 ("OAuth 2.0 for Native Apps") flow purpose-built for
non-browser clients like this one:

1. `GET /api/status` (public) reports whether the gate is engaged
   (`auth_required`), which providers are registered, and whether the
   `native_pkce` flow is available.
2. `GET /api/auth/providers` (public) lists the registered providers
   (`name`, `display_name`, `supports_password`).
3. Signing in to *any* provider — OIDC or password — opens the **system
   browser** at `GET /auth/native/authorize` with a fresh PKCE
   (`code_challenge`/`S256`), a `redirect_uri` pointing at a loopback HTTP
   server this app binds on an ephemeral port, and a CSRF `state`. An OIDC
   provider redirects through its IdP as normal; the password provider
   instead renders Hermes's own `/login` form in the system browser (so the
   OS password manager can autofill it — that's the documented reason the
   backend routes password logins through the browser too). Either way, the
   browser is finally redirected back to `http://127.0.0.1:<port>/callback`
   with a one-time authorization `code`.
4. The app redeems that code at `POST /auth/native/token` (with the PKCE
   verifier) for a bearer `access_token` + `refresh_token` pair, stored in
   the OS keychain/keystore (`flutter_secure_storage`) — never a cookie.
5. Every REST call after that carries `Authorization: Bearer <access_token>`.
   An expired token is rotated transparently via `POST /auth/native/refresh`
   before it's used, and again on any `401` the server returns, mirroring
   the gate's own cookie-refresh semantics.

This mirrors the native login flow Hermes Desktop implements
(`apps/desktop/electron/native-oauth*.ts`) — see
`lib/src/auth/native_login_flow.dart` and `lib/src/auth/pkce.dart`.

When `/api/status` reports `auth_required: false` (the dashboard's default
loopback-only dev mode), the app skips sign-in entirely.

## Project layout

```
lib/
  main.dart                       # wires up AuthController + HermesApp
  src/
    app.dart                      # routes on AuthController.state
    auth/
      auth_controller.dart        # connection/session state machine, Dio + refresh
      native_login_flow.dart      # RFC 8252 system-browser + loopback + PKCE
      pkce.dart                   # PKCE verifier/challenge/state generation
      token_store.dart            # flutter_secure_storage wrapper
    api/
      hermes_api_client.dart      # status/providers/me + HermesApiClient.raw (see below)
    models/                       # HermesStatus, AuthProviderInfo, HermesSession, HermesIdentity
    screens/                      # server setup, login, home
packages/
  hermes_api/                      # generated dio client for the rest of the REST API
openapi/
  hermes-agent.openapi.json        # the backend's OpenAPI spec (see openapi/README.md)
scripts/
  generate_hermes_api_client.sh    # regenerates packages/hermes_api from the spec
```

## The generated API client

`hermes_cli.web_server:app` (the dashboard backend) has ~300 routes, and
hand-writing a Dio call and model class for each one doesn't scale.
`packages/hermes_api` is a `dart-dio`-flavored [OpenAPI Generator](https://openapi-generator.tech/)
client generated straight from `openapi/hermes-agent.openapi.json`, covering
every route the spec declares a request/response schema for.
`HermesApiClient.raw` (`lib/src/api/hermes_api_client.dart`) exposes it on
the same authenticated `Dio` instance `AuthController` already manages, so
new features should call `authController.api!.raw.<operation>(...)` instead
of adding another hand-rolled REST call.

`fetchStatus`/`fetchAuthProviders`/`fetchMe` on `HermesApiClient` stay
hand-written: `/api/status`, `/api/auth/providers` and `/api/auth/me` don't
declare response schemas in the spec (FastAPI only emits one for a route
with a Pydantic `response_model`), so there's nothing for codegen to build a
typed model from.

To regenerate after pulling a newer spec:

```bash
./scripts/generate_hermes_api_client.sh
```

This needs a JDK (to run `openapi-generator-cli` via `npx`) and the Dart SDK
on `PATH`. It patches a few spec constructs the `dart-dio` template can't
render (see `scripts/patch_openapi_for_dart.py`), a couple of its own
codegen bugs in the result (`scripts/patch_generated_dart_client.py`), then
runs `pub get` + `build_runner` + `dart analyze` inside
`packages/hermes_api`. Review the diff before committing — a spec change can
rename or retype generated methods.

`.github/workflows/verify-hermes-api-client.yml` runs the same script in CI
(on any push/PR touching `openapi/`, `scripts/`, or `packages/hermes_api/`)
and fails if it produces a diff — so a spec update that lands without a
regenerated client gets caught instead of silently drifting.
`packages/hermes_api/pubspec.lock` is committed (unlike the usual
library-package advice) so that check isn't at the mercy of an unrelated
transitive dependency picking up a new version between two runs.

## Getting started

Point the app at a running dashboard:

```bash
# on the machine that will host the dashboard
hermes dashboard --host 0.0.0.0 --port 9119 --no-open
```

then enter that machine's address (e.g. `http://192.168.1.20:9119`) on the
app's first screen. See the [Web Dashboard docs](https://hermes-agent.nousresearch.com/docs/user-guide/features/web-dashboard)
for configuring the username/password or self-hosted OIDC provider.

### Run

```bash
flutter pub get
flutter run
```

### Notes for local/self-hosted dashboards

- Android: cleartext (plain HTTP) traffic is allowed app-wide
  (`android:usesCleartextTraffic="true"`) since `hermes dashboard` defaults
  to HTTP on a LAN.
- iOS/macOS: `NSAllowsLocalNetworking` is set so ATS permits HTTP to local
  network / loopback addresses without a blanket ATS opt-out.
- macOS: the App Sandbox entitlements include both
  `com.apple.security.network.client` (REST calls) and
  `com.apple.security.network.server` (the loopback OAuth callback
  listener).

## Contributing

This project uses [cedricziel/claude-plugins](https://github.com/cedricziel/claude-plugins)'
`oss` plugin (commit discipline, stacked PRs, test-writing, technical
writing, etc.) for anyone working on it with Claude Code:

```
/plugin marketplace add cedricziel/claude-plugins
/plugin install oss@cedricziel
```
