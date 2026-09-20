# Telemetry Specification

## Purpose

The app can export OpenTelemetry traces and logs to an OTLP HTTP endpoint (in practice SignalDB) so that the people who ship the app can see how sign-in, requests and crashes behave in the field. The server address is typed in by the user, and prompts, tokens and identities are private, so telemetry is opt-in at build time and records only coarse facts. This spec describes the behaviour as implemented today. Telemetry code must never affect what the user can do in the app.

## Requirements

### Requirement: Telemetry is off unless a build enables it

The system SHALL leave telemetry off unless the build sets a non-empty `OTEL_EXPORTER_OTLP_ENDPOINT` through `--dart-define`. The system SHALL read the remaining settings from `--dart-define` values as well: `OTEL_EXPORTER_OTLP_HEADERS`, `OTEL_SERVICE_NAME` (default `hermes-app`), `OTEL_SERVICE_VERSION` (default empty) and `OTEL_DEPLOYMENT_ENVIRONMENT` (default `development`). There SHALL be no runtime or in-app setting that turns telemetry on.

#### Scenario: Plain run has no endpoint

- **WHEN** the app is started without any `OTEL_*` define, for example with plain `flutter run`
- **THEN** telemetry is disabled
- **AND** nothing is exported

#### Scenario: Build supplies an endpoint

- **WHEN** the app is built with `--dart-define=OTEL_EXPORTER_OTLP_ENDPOINT=<valid endpoint>`
- **THEN** telemetry is enabled and exports to that endpoint
- **AND** the service name is `hermes-app` and the deployment environment is `development` unless the corresponding defines override them

### Requirement: Export headers are parsed leniently

The system SHALL parse `OTEL_EXPORTER_OTLP_HEADERS` as comma-separated `key=value` pairs, split on the first `=` so that values may contain `=`, with surrounding whitespace trimmed. The system SHALL skip entries that have no `=` or an empty key instead of failing.

#### Scenario: Several headers

- **WHEN** the headers define is `authorization=Bearer abc,x-tenant-id=homelab,x-dataset-id=apps`
- **THEN** the export sends three headers: `authorization` = `Bearer abc`, `x-tenant-id` = `homelab` and `x-dataset-id` = `apps`

#### Scenario: Malformed entries

- **WHEN** the headers define is `a=b==,,novalue,=nokey, c = d `
- **THEN** the parsed headers are `a` = `b==` and `c` = `d`
- **AND** the entries `novalue`, `=nokey` and the empty entry are ignored

### Requirement: An unusable endpoint disables telemetry

The system SHALL treat an endpoint without a scheme or without a host as unusable, disable telemetry and continue starting the app instead of throwing.

#### Scenario: Endpoint is not a URL

- **WHEN** the endpoint define is `not a url`
- **THEN** app start-up succeeds
- **AND** telemetry is disabled and no HTTP interceptor is offered

### Requirement: No SDK, no interceptor, no header, no handlers when off

While telemetry is disabled the system SHALL NOT create an OpenTelemetry SDK, SHALL NOT offer an HTTP interceptor, SHALL NOT add a `traceparent` header to any request, SHALL NOT change the Flutter or platform error handlers, and SHALL make every telemetry event a no-op.

#### Scenario: Disabled telemetry hands out nothing

- **WHEN** telemetry is disabled
- **THEN** the HTTP interceptor is absent
- **AND** the event function does nothing when called

#### Scenario: Error handlers stay untouched when disabled

- **WHEN** uncaught-error logging is requested while telemetry is disabled
- **THEN** the Flutter error handler and the platform error handler are the same objects as before

### Requirement: Resource attributes describe the app and device coarsely

When telemetry is enabled the system SHALL attach a resource to every exported span and log record containing the service name, the service version (omitted when the version define is empty), the deployment environment, and these device attributes: `os.type` (the operating system name), `os.version` (major and minor version, only on iOS and macOS, without the build number), `device.form_factor` and `app.build_mode` (`release`, `profile` or `debug`). `device.form_factor` SHALL be `desktop` on macOS, Windows and Linux, and on iOS and Android `tablet` when the shortest logical screen side is at least 600 and `phone` otherwise. The system SHALL omit `os.version` and `device.form_factor` when they cannot be determined. The system SHALL NOT include a device model, device name, locale or hardware identifier. If reading the device attributes fails, the system SHALL export the resource without them.

#### Scenario: iPhone

- **WHEN** telemetry is enabled on an iPhone whose shortest logical side is below 600, running a system that reports "Version 26.0 (Build 23A344)"
- **THEN** the resource has `os.type` = `ios`, `os.version` = `26.0` and `device.form_factor` = `phone`
- **AND** the build number is not part of any attribute

#### Scenario: Tablet by screen size

- **WHEN** the shortest logical side of an iOS or Android device is 600 or more
- **THEN** `device.form_factor` is `tablet`

#### Scenario: Mac

- **WHEN** telemetry is enabled on macOS
- **THEN** `device.form_factor` is `desktop`

#### Scenario: Unknown facts are left out

- **WHEN** the screen size is not yet known on iOS or Android, or the system is neither iOS nor macOS
- **THEN** `device.form_factor` (unknown screen size) or `os.version` (other systems) is omitted rather than filled with a placeholder

### Requirement: Every HTTP request through the app's clients is traced and logged

When telemetry is enabled the system SHALL add one interceptor to every HTTP client the connection controller builds (the authenticated client, the token endpoint client and the page-token client) that records one client span and one log record per request. The span SHALL be named `HTTP <METHOD>` and carry `http.method`, `http.route` (when known), `http.status_code` (when there is a response) and `error.type` (when the request failed). The span status SHALL be an error for a failed request or a status of 400 or above, and OK otherwise. The log record SHALL have the body `HTTP <METHOD> [<route>] <status or error type>`, the attributes `http.method`, `http.route` (when known), `http.status_code` (when known), `http.duration_ms` and `error.type` (when failed), severity `error` when the request failed or the status is not 2xx and `info` otherwise, and the trace and span identifiers of the request span. The span SHALL always be ended, whether the request succeeded or failed.

#### Scenario: Successful request

- **WHEN** the app requests `GET /api/status` and the server answers 200
- **THEN** one span `HTTP GET` with `http.route` = `/api/status`, `http.status_code` = 200 and status OK is ended
- **AND** one info log `HTTP GET /api/status 200` with a duration is emitted, linked to that span

#### Scenario: Error response

- **WHEN** the server answers with a 4xx or 5xx status
- **THEN** the span status is an error, carries the status code and the error type `badResponse`, and is ended
- **AND** the log record has severity `error` and includes the status

#### Scenario: No response

- **WHEN** a request fails without a response, for example a connection error
- **THEN** the span and log carry `error.type` = `connectionError` and no status code
- **AND** the log body ends with the error type

### Requirement: HTTP telemetry never records where or what was sent

The HTTP interceptor SHALL NOT record the URL, host, query string, fragment, request or response headers (including `Authorization`), request or response bodies, exception messages or span events. It SHALL NOT add a `traceparent` header or any other header to the request. It SHALL record `http.route` only for request paths that start with `/`, and then only the first two path segments, without the query string and fragment, so that path parameters such as session ids, profile names and task ids are never recorded. For an absolute URL or any other path it SHALL leave `http.route` out.

#### Scenario: Query string is dropped

- **WHEN** the app requests `/api/x?token=hunter2`
- **THEN** `http.route` is `/api/x`

#### Scenario: Path parameters are dropped

- **WHEN** the app requests `/api/sessions/20260919_abc123/messages`, `/api/profiles/work-laptop`, `/api/plugins/kanban/tasks/t_8f3a` or `/api/mcp/servers/github/auth`
- **THEN** `http.route` is `/api/sessions`, `/api/profiles`, `/api/plugins` and `/api/mcp` respectively
- **AND** neither the span nor the log record contains the session id, profile name, task id or server name

#### Scenario: Short paths are kept

- **WHEN** the app requests `/api/status`, or `/api/sessions/` with a trailing slash
- **THEN** `http.route` is `/api/status` and `/api/sessions` respectively

#### Scenario: Secrets in a failed request

- **WHEN** a POST to `/api/x?token=hunter2#frag` with body `{"message": "my secret prompt"}` and header `Authorization: Bearer hunter2` fails with an exception message naming the server host
- **THEN** neither the span nor the log record contains the host, `hunter2`, `frag` or the prompt text
- **AND** the span has no status description and no events

#### Scenario: Absolute URL

- **WHEN** a request is made to an absolute URL such as `https://<host>/auth/native/refresh?code=abc`
- **THEN** there is no `http.route` and the host does not appear anywhere in the span or log

#### Scenario: Outgoing headers are unchanged

- **WHEN** a request goes through the interceptor
- **THEN** the request sent to the server has no `traceparent` header

### Requirement: Sign-in and session events are logged with coarse values

When telemetry is enabled the connection controller SHALL log app events as info log records whose body is the event name and whose attributes are fixed names and coarse values only. Callers SHALL NOT pass a URL, host, provider name, user identity, token or exception message. The events are:

- `auth.sign_in.started` with `auth.password` (whether the provider supports password sign-in).
- `auth.sign_in.succeeded`, `auth.sign_in.failed` and `auth.sign_in.cancelled`, each with `auth.password` and `duration_ms`. A failure adds `reason` (the login failure reason, `profile_load` when loading the profile failed, or `unexpected`) and `http.status_code` when known; an unexpected failure adds `exception.type` (the type name only).
- `auth.session.refreshed` with `trigger` (`proactive` or `after_401`).
- `auth.session.refresh_failed` with `trigger`, `rejected` and `http.status_code` when known.
- `auth.session.expired` with `cause` (`unauthorized_after_retry`, `no_refresh_token` or `refresh_rejected`).
- `auth.state` with `state` (the name of the new connection state) on every state change.

#### Scenario: Sign-in cancelled

- **WHEN** the user starts a sign-in and then cancels it
- **THEN** the events `auth.sign_in.started` and `auth.sign_in.cancelled` are logged in that order

#### Scenario: Sign-in fails

- **WHEN** a sign-in ends with a login failure
- **THEN** `auth.sign_in.failed` is logged with the failure `reason`, `auth.password` and `duration_ms`
- **AND** no message text, server address or provider name is included

#### Scenario: Refresh rejected

- **WHEN** a token refresh is rejected by the server and the session is dropped
- **THEN** `auth.session.refresh_failed` is logged with `rejected` = true
- **AND** `auth.session.expired` is logged with a `cause`
- **AND** the last `auth.state` event has `state` = `needsLogin`

#### Scenario: Refresh succeeds

- **WHEN** a token refresh succeeds
- **THEN** `auth.session.refreshed` is logged with the `trigger` that caused it

### Requirement: Uncaught errors are logged by type only

When telemetry is enabled the system SHALL log every uncaught Flutter framework error as an error log record with the body `Uncaught Flutter error` and every uncaught asynchronous error as an error log record with the body `Uncaught async error`. The only attribute SHALL be `exception.type`, the runtime type name of the error. The system SHALL NOT record the error message or stack trace. The system SHALL then call the error handler that was installed before it; for asynchronous errors the result of that handler is returned, and it is `false` (unhandled) when there was none.

#### Scenario: Framework error

- **WHEN** a framework error carrying the message `user typed: hunter2` is reported
- **THEN** one error log `Uncaught Flutter error` with `exception.type` = `StateError` and no other attributes is emitted
- **AND** the previously installed Flutter error handler is still called

#### Scenario: Async error

- **WHEN** an asynchronous error whose message is a URL with a token is reported
- **THEN** one error log `Uncaught async error` with `exception.type` = `ArgumentError` is emitted and the message is not recorded
- **AND** the previous platform handler's verdict is returned

#### Scenario: No previous handler

- **WHEN** an uncaught asynchronous error is reported and no platform handler was installed before
- **THEN** the error is logged and reported as unhandled (`false`)

### Requirement: Telemetry failures never break the app

The system SHALL swallow any failure raised while starting a span, ending a span, setting attributes or emitting a log record, so that requests, sign-in and error handling behave the same as with telemetry off. A failing tracer SHALL NOT prevent the request from completing or the request log from being emitted. A failing logger SHALL NOT prevent the request or the span from completing.

#### Scenario: Tracer throws

- **WHEN** the tracer throws while a request is made
- **THEN** the request completes with its normal response
- **AND** the request log is still emitted

#### Scenario: Logger throws on an HTTP request

- **WHEN** the logger throws while a request finishes
- **THEN** the request completes with its normal response and the span is still ended

#### Scenario: Logger throws on an event

- **WHEN** the logger throws while an app event is emitted
- **THEN** the event call returns normally

#### Scenario: Logger throws on an uncaught error

- **WHEN** the logger throws while an uncaught error is reported
- **THEN** the error still reaches the previously installed handler
