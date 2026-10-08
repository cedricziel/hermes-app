## ADDED Requirements

### Requirement: HTTP and connection telemetry carries the connected server's attributes

When telemetry is enabled the system SHALL describe the Hermes server of the current connection with `hermes.*` attributes read from that server's public, unauthenticated `GET /api/status` answer when the app connects. A connection starts when the app connects to a server URL (typed in, restored on launch, or retried automatically) and ends on Change Server or when the next connect starts. Signing out or a session expiring does not end it.

The attributes and the status fields they come from are:

- `hermes.version` (string) from `version`
- `hermes.release_date` (string) from `release_date`
- `hermes.config_version` (int) from `config_version` (Hermes sends 0 for an unstamped config)
- `hermes.install_id` (string) from `install_id` (Hermes leaves it out when it cannot persist one)
- `hermes.auth.required` (bool) from `auth_required`
- `hermes.auth.providers` (list of strings) from `auth_providers`
- `hermes.gateway.mode` (string) from `gateway_mode` (`multiplex`, `single`, `multiple`, `none` or `unknown`)
- `hermes.profile.count` (int): the number of names in `profiles`, which includes parked profiles. Left out when `gateway_mode` is `unknown`, because Hermes then sends an empty list.
- `hermes.gateway.state` (string) from `gateway_state`
- `hermes.overall` (string) from `overall` (`ok` or `degraded`)

The system SHALL leave an attribute out when its field is absent or has an unexpected type, and SHALL connect exactly as it would without telemetry. No minimum Hermes version is required: an older server yields fewer attributes.

The attributes are fixed for the connection. The system SHALL add them to:

- every span and request log record of the HTTP clients built for that connection after its status is known: the authenticated client and the token client;
- every app event the connection controller logs after the status is known, including sign-in, session refresh, session expiry and `auth.state` events.

The system SHALL NOT add them to the resource, to the `/api/status` probe, to events logged before the status is known (such as `auth.connect.failed` or `auth.state` with `state` = `connecting`), to breadcrumbs, or to telemetry that belongs to no connection, such as uncaught errors. Attributes a span or log record sets itself SHALL take precedence over a `hermes.*` attribute of the same name.

#### Scenario: Connected server is described

- **WHEN** the app connects to a server whose status answer has `version` = `0.14.2`, `install_id` = `inst_42`, `auth_required` = true, `auth_providers` = [`basic`], `gateway_mode` = `multiplex`, `profiles` with three names, `gateway_state` = `running` and `overall` = `ok`
- **AND** the user signs in and the app requests `GET /api/sessions`
- **THEN** the `HTTP GET` span and request log record carry `hermes.version` = `0.14.2`, `hermes.install_id` = `inst_42`, `hermes.auth.required` = true, `hermes.auth.providers` = [`basic`], `hermes.gateway.mode` = `multiplex`, `hermes.profile.count` = 3, `hermes.gateway.state` = `running` and `hermes.overall` = `ok`
- **AND** `auth.sign_in.started` and `auth.sign_in.succeeded` carry the same attributes next to their own

#### Scenario: Token refresh is described

- **WHEN** the app refreshes its session against that server
- **THEN** the refresh request's span and log record, and `auth.session.refreshed`, carry the server's `hermes.*` attributes

#### Scenario: Sign-out keeps the connection

- **WHEN** the user signs out of that server and signs in again
- **THEN** the second sign-in's events and requests carry the same `hermes.*` attributes

#### Scenario: Older server sends fewer fields

- **WHEN** the status answer has `version` but no `install_id`, `gateway_mode` or `overall`
- **THEN** telemetry carries `hermes.version` and has no `hermes.install_id`, `hermes.gateway.mode`, `hermes.profile.count` or `hermes.overall`

#### Scenario: Field with the wrong type

- **WHEN** the status answer has `config_version` = `"seven"`
- **THEN** the app connects normally
- **AND** `hermes.config_version` is left out and every other attribute is still recorded

#### Scenario: Profiles could not be listed

- **WHEN** the status answer has `gateway_mode` = `unknown` and `profiles` = []
- **THEN** there is no `hermes.profile.count`

#### Scenario: Before the status is known

- **WHEN** the app probes `/api/status` and the probe fails
- **THEN** the probe's span and log record, `auth.connect.failed` and `auth.state` with `state` = `connecting` carry no `hermes.*` attribute

#### Scenario: Telemetry off

- **WHEN** telemetry is disabled
- **THEN** no `hermes.*` attribute is computed or recorded and connecting behaves as before

### Requirement: Server attributes stay with their connection and record no locations

The system SHALL attach to each piece of telemetry the attributes of the connection that produced it. Telemetry produced after a connection ended SHALL NOT carry that connection's attributes, and a request that started on one connection SHALL keep that connection's attributes even if it finishes after the next connection started. When the app connects again, even to the same URL, telemetry from the new connection SHALL carry the values of the new status answer.

The system SHALL NOT record the server URL or host, `hermes_home`, `config_path`, `env_path`, `gateway_pid`, `gateway_health_url`, the `gateways` list, ports, profile names, or any other path or address from the status answer, even when an unauthenticated server includes them.

#### Scenario: Changing servers

- **WHEN** the user is connected to server A (`install_id` = `inst_a`), chooses Change Server, and connects to server B (`install_id` = `inst_b`)
- **THEN** every span and log record made for server B carries `hermes.install_id` = `inst_b`
- **AND** nothing logged after Change Server carries `inst_a`

#### Scenario: Failed connect to a new address

- **WHEN** the user is connected to server A, types a new address, and the probe of that address fails
- **THEN** `auth.connect.failed` and the following `auth.state` events carry no `hermes.*` attribute

#### Scenario: Request in flight across a switch

- **WHEN** a request to server A is still running when the user connects to server B, and finishes afterwards
- **THEN** that request's span and log record carry server A's attributes

#### Scenario: Server upgraded between connects

- **WHEN** the app connects again to a server that now reports `version` = `0.15.0` instead of `0.14.2`
- **THEN** telemetry from the new connection carries `hermes.version` = `0.15.0`

#### Scenario: Ungated server exposes paths

- **WHEN** an unauthenticated server's status answer includes `hermes_home`, `config_path`, `gateway_pid`, `gateways` and profile names
- **THEN** no span or log record contains any of those values or the server's address
- **AND** `hermes.profile.count` is the only fact recorded about profiles

## MODIFIED Requirements

### Requirement: Sign-in and session events are logged with coarse values

When telemetry is enabled the connection controller SHALL log app events as info log records whose body is the event name and whose attributes are fixed names and coarse values only. Callers SHALL NOT pass a URL, host, user identity, token or exception message, and SHALL NOT name the provider used for a sign-in attempt. The server's `hermes.*` attributes, including its list of configured providers, are added as described in "HTTP and connection telemetry carries the connected server's attributes" and are not affected by this rule. The events are:

- `auth.connect.failed` with `reason` (the classified failure kind), `host_kind` (the kind of address, never the address) and `retry` (whether the attempt was automatic).
- `server.connected` once per connection, when its status is known. The breadcrumb records only `hermes.version`; the log record carries every `hermes.*` attribute.
- `auth.sign_in.started` with `auth.password` (whether the provider supports password sign-in).
- `auth.sign_in.succeeded`, `auth.sign_in.failed` and `auth.sign_in.cancelled`, each with `auth.password` and `duration_ms`. A failure adds `reason` (the login failure reason, `profile_load` when loading the profile failed, or `unexpected`) and `http.response.status_code` when known; an unexpected failure adds `exception.type` (the type name only).
- `auth.session.refreshed` with `trigger` (`proactive` or `after_401`).
- `auth.session.refresh_failed` with `trigger`, `rejected` and `http.response.status_code` when known.
- `auth.session.expired` with `cause` (`unauthorized_after_retry`, `no_refresh_token` or `refresh_rejected`).
- `auth.state` with `state` (the name of the new connection state) on every state change.

Breadcrumbs kept for crash reports SHALL record each event with the attributes its caller passed, without the `hermes.*` attributes, except `server.connected` as described above.

#### Scenario: Sign-in cancelled

- **WHEN** the user starts a sign-in and then cancels it
- **THEN** the events `auth.sign_in.started` and `auth.sign_in.cancelled` are logged in that order

#### Scenario: Sign-in fails

- **WHEN** a sign-in ends with a login failure
- **THEN** `auth.sign_in.failed` is logged with the failure `reason`, `auth.password` and `duration_ms`
- **AND** no message text, server address or name of the provider used is included

#### Scenario: Refresh rejected

- **WHEN** a token refresh is rejected by the server and the session is dropped
- **THEN** `auth.session.refresh_failed` is logged with `rejected` = true
- **AND** `auth.session.expired` is logged with a `cause`
- **AND** the last `auth.state` event has `state` = `needsLogin`

#### Scenario: Refresh succeeds

- **WHEN** a token refresh succeeds
- **THEN** `auth.session.refreshed` is logged with the `trigger` that caused it

#### Scenario: Connected

- **WHEN** the app connects to a server reporting `version` = `0.14.2`
- **THEN** `server.connected` is logged once with the server's `hermes.*` attributes
- **AND** a crash reported afterwards lists a `server.connected` breadcrumb with `hermes.version` = `0.14.2` and no other `hermes.*` attribute on any breadcrumb
