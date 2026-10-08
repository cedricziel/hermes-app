## Why

Telemetry says a lot about the app and the device, and nothing about the Hermes server on the other end. When sign-in fails or requests error, we cannot tell which Hermes version was involved, whether it was one server or many, or whether that server was already degraded. `GET /api/status` hands the app exactly those facts on every connect, so recording them costs nothing extra.

This is the first of two changes. It covers HTTP requests and the connection controller's events. `hermes-server-attributes-sockets` brings the same attributes to the gateway and Kanban sockets and the feature controllers' events.

## What Changes

- The app reads ten `hermes.*` facts from the `/api/status` answer each time it connects to a server: version, release date, config version, install id, auth gate shape, gateway mode, profile count, gateway state and overall health.
- They form one fixed set per connection. A connection starts when the app connects to a server URL and ends on Change Server or the next connect. Signing out does not end it; the app is still connected to that server and asks the user to sign in.
- The set is added to the spans and request logs of the clients built for that connection (the authenticated client and the token client) and to the connection controller's app events from the moment the status is known.
- A new app event `server.connected` is logged once per connection, so a crash report's breadcrumbs show which Hermes version the user was on without repeating every attribute on every breadcrumb.
- The `/api/status` probe, events before the status is known (`auth.connect.failed`, `auth.state connecting`), breadcrumbs and uncaught errors carry no `hermes.*` attributes.
- A field Hermes leaves out or sends with an unexpected type only drops that attribute; it never fails the connect.

## Non-goals

- No new requests. `/api/system/stats` (host OS, CPU, hostname) is not read, and `/api/status` is not re-probed while connected: health attributes describe the server at connect time.
- No resource change, and no process-wide attribute state.
- No upstream change: `DioOTelInterceptor` already takes a fixed attributes map.
- No change to the gateway or Kanban sockets or the feature controllers (second change).
- No `flutter_otel` bump; it is unrelated and goes in its own `build(deps)` PR.
- No multi-server support in the app; the design only stays correct if it arrives.

## Security and privacy impact

New data leaves the device only when telemetry is built in, and only to the operator's own OTLP endpoint (https or loopback, unchanged).

- `hermes.install_id` is a stable identifier of the user's Hermes server, not of a person. Hermes serves it on its public, unauthenticated status probe. It lets us count distinct servers and group failures by server.
- `hermes.auth.providers` is the server's list of configured providers (`basic`, `nous`), which the probe also serves publicly. The rule that sign-in events never name the provider used for an attempt stays; the requirement is reworded so the two are not confused.
- The server URL and host, `hermes_home`, config and env paths, gateway PID, health URL, ports, the `gateways` list and profile names are never recorded, even when an ungated server includes them. Only the profile count is.
- Tokens and secure storage: none touched.

## Telemetry emitted

New attributes on existing spans and log records, and one new app event:

| Attribute               | Type     | From `GET /api/status`                                          |
| ----------------------- | -------- | --------------------------------------------------------------- |
| `hermes.version`        | string   | `version`                                                       |
| `hermes.release_date`   | string   | `release_date`                                                  |
| `hermes.config_version` | int      | `config_version`                                                |
| `hermes.install_id`     | string   | `install_id`                                                    |
| `hermes.auth.required`  | bool     | `auth_required`                                                 |
| `hermes.auth.providers` | string[] | `auth_providers`                                                |
| `hermes.gateway.mode`   | string   | `gateway_mode`                                                  |
| `hermes.profile.count`  | int      | length of `profiles`, left out when `gateway_mode` is `unknown` |
| `hermes.gateway.state`  | string   | `gateway_state`                                                 |
| `hermes.overall`        | string   | `overall`                                                       |

- `server.connected` (info log, breadcrumb): `hermes.version` on the breadcrumb, all `hermes.*` on the log record.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `telemetry`: new requirements for per-connection `hermes.*` attributes on HTTP telemetry and connection events, and for keeping them to one connection and free of locations; the sign-in events requirement is modified to add `server.connected`, list `auth.connect.failed`, and allow the server's attributes next to the "no provider name" rule.

## Impact

- `lib/src/models/hermes_status.dart` or a new `lib/src/telemetry/hermes_server_attributes.dart`: lenient parsing of the status fields.
- `lib/src/telemetry/telemetry.dart`: an interceptor and an event logger built for a given attribute set.
- `lib/src/auth/auth_controller.dart`, `lib/main.dart`: the controller builds the connection's attribute set and instruments on connect and drops them on the next connect or Change Server.
- `test/real_backend_contract_test.dart`: assert the status fields this relies on.
- `openspec/specs/telemetry/spec.md`: synced on archive.
