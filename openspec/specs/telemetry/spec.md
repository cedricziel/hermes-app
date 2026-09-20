# Telemetry Specification

## Purpose

The app can export OpenTelemetry traces and logs to an OTLP HTTP endpoint over https (in practice SignalDB) so that the people who ship the app can see how sign-in, requests, the chat connection and crashes behave in the field. The server address is typed in by the user, and prompts, tokens and identities are private, so telemetry is opt-in at build time and records only coarse facts. This spec describes the behaviour as implemented today. Telemetry code must never affect what the user can do in the app.

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

The system SHALL treat an endpoint as unusable, disable telemetry and continue starting the app instead of throwing, when it has no scheme or no host, when its scheme is not `https`, or when its scheme is `http` and its host is not a loopback host (`localhost`, `127.0.0.1` or `::1`). Export requests carry the configured headers, which usually include a bearer token, so the system SHALL NOT send them over cleartext to any other host.

#### Scenario: Endpoint is not a URL

- **WHEN** the endpoint define is `not a url`
- **THEN** app start-up succeeds
- **AND** telemetry is disabled and no HTTP interceptor is offered

#### Scenario: Endpoint is cleartext http

- **WHEN** the endpoint define is `http://collector.example.com:4318` or `http://192.168.1.20:4318`
- **THEN** app start-up succeeds
- **AND** telemetry is disabled and no HTTP interceptor is offered

#### Scenario: Endpoint uses another scheme

- **WHEN** the endpoint define is `ftp://collector.example.com`
- **THEN** telemetry is disabled

#### Scenario: Loopback collector over http

- **WHEN** the endpoint define is `http://localhost:4318`, `http://127.0.0.1:4318` or `http://[::1]:4318`
- **THEN** telemetry is enabled, because the traffic never leaves the device

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

When telemetry is enabled the system SHALL attach a resource to every exported span and log record containing the service name, the service version (omitted when the version define is empty), the deployment environment, and device attributes. The device attributes SHALL be limited to the operating system, the app build mode, the form factor and facts shared by every unit of a device model:

- `os.type` (the operating system name) and `app.build_mode` (`release`, `profile` or `debug`), on every platform.
- `os.version`: on iOS and macOS the major and minor version without the build number; on Android the release version the device reports; omitted on other systems and whenever it cannot be determined.
- `device.form_factor`: `desktop` on macOS, Windows and Linux. On iPhone and iPad it SHALL follow the device family the system reports (`phone` for iPhone and iPod, `tablet` for iPad). When the family is not known, and on Android, it SHALL be `tablet` when the shortest logical screen side is at least 600 and `phone` otherwise. It SHALL be omitted when it cannot be determined, for example when the screen size is not yet known.
- `device.manufacturer` and `device.model.identifier` on iOS, macOS and Android: `Apple` and the hardware model identifier (such as `iPhone17,1` or `Mac14,2`) on Apple systems, the manufacturer and model the device reports (such as `Pixel 9`) on Android.
- `host.arch` (the processor architecture) on macOS only.
- `android.os.api_level` on Android only.
- `device.simulator` on iOS and Android: whether the device is a simulator or emulator.
- `app.ios_app_on_mac` on iOS only: whether the app is an iOS app running on a Mac.

The system SHALL NOT include the device name, vendor or hardware identifiers, locale, memory or disk sizes, or a build fingerprint. If reading the hardware facts fails, the system SHALL export the resource with the remaining attributes; if reading the basic attributes fails, it SHALL export the resource without any device attribute.

#### Scenario: iPhone

- **WHEN** telemetry is enabled on a physical iPhone whose model identifier is `iPhone17,1`, running a system that reports "Version 26.0 (Build 23A344)"
- **THEN** the resource has `os.type` = `ios`, `os.version` = `26.0`, `device.form_factor` = `phone`, `device.manufacturer` = `Apple`, `device.model.identifier` = `iPhone17,1` and `device.simulator` = false
- **AND** the build number is not part of any attribute

#### Scenario: iPad is a tablet by device family

- **WHEN** telemetry is enabled on an iPad
- **THEN** `device.form_factor` is `tablet` whatever the screen size is

#### Scenario: Android device

- **WHEN** telemetry is enabled on an Android device
- **THEN** the resource has `device.manufacturer`, `device.model.identifier`, `os.version` (the Android release), `android.os.api_level` and `device.simulator`
- **AND** `device.form_factor` is `tablet` when the shortest logical screen side is 600 or more and `phone` otherwise

#### Scenario: Mac

- **WHEN** telemetry is enabled on macOS
- **THEN** `device.form_factor` is `desktop`, `device.manufacturer` is `Apple`, `device.model.identifier` is the Mac model and `host.arch` is the processor architecture

#### Scenario: Unknown facts are left out

- **WHEN** the screen size is not yet known on Android (or on iOS when the device family is also unknown), or the system is neither iOS, macOS nor Android
- **THEN** `device.form_factor` (unknown screen size) or `os.version` (other systems) is omitted rather than filled with a placeholder

#### Scenario: Hardware lookup fails

- **WHEN** reading the hardware model fails
- **THEN** the resource still has `os.type`, `app.build_mode` and the other basic attributes
- **AND** no error reaches the user

#### Scenario: Nothing that identifies a person or one device

- **WHEN** the resource is exported on any platform
- **THEN** it has no device name, vendor identifier, hardware identifier, locale, memory size or disk size

### Requirement: Every HTTP request through the app's clients is traced and logged

When telemetry is enabled the system SHALL add one interceptor to every HTTP client the connection controller builds (the authenticated client, the token endpoint client and the page-token client) that records one client span and one log record per request. The span SHALL be named `HTTP <METHOD>` and carry `http.method`, `http.route` (when known), `http.status_code` (when there is a response) and `error.type` (when the request failed). The span status SHALL be an error for a failed request or a status of 400 or above, and OK otherwise. The log record SHALL have the body `HTTP <METHOD> [<route>] <status or error type>`, the attributes `http.method`, `http.route` (when known), `http.status_code` (when known), `http.duration_ms` and `error.type` (when failed), severity `error` when the request failed or the status is 400 or above and `info` otherwise, so the span and the log always agree on whether a request failed, and the trace and span identifiers of the request span. The span SHALL always be ended, whether the request succeeded or failed.

#### Scenario: Successful request

- **WHEN** the app requests `GET /api/status` and the server answers 200
- **THEN** one span `HTTP GET` with `http.route` = `/api/status`, `http.status_code` = 200 and status OK is ended
- **AND** one info log `HTTP GET /api/status 200` with a duration is emitted, linked to that span

#### Scenario: Error response

- **WHEN** the server answers with a 4xx or 5xx status
- **THEN** the span status is an error, carries the status code and the error type `badResponse`, and is ended
- **AND** the log record has severity `error` and includes the status

#### Scenario: Non-error status

- **WHEN** the server answers 204 or 304
- **THEN** the span status is OK and the log record has severity `info`

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

### Requirement: The chat gateway socket is traced as an upgrade plus linked messages

When telemetry is enabled the system SHALL trace the dashboard's chat gateway socket (`/api/ws`) like a messaging system instead of as one long trace:

- Opening the socket SHALL be one client span named `HTTP GET` with `http.method` = `GET` and `http.route` = `/api/ws`. When the upgrade succeeds the span carries `http.status_code` = 101 and status OK; when opening fails it carries `error.type` (the exception type name only) and an error status, and the exception is passed on unchanged. The span is always ended.
- Each JSON-RPC request SHALL be one producer span named `<method> send`, started when the request is sent and ended when the gateway answers. It carries `messaging.system` = `hermes.gateway`, `messaging.operation.type` = `send`, `messaging.destination.name` and `rpc.method` (the method name), `messaging.message.id` (the JSON-RPC request id), `rpc.system` = `jsonrpc` and `rpc.jsonrpc.version` = `2.0`. It ends with status OK on a result; on a JSON-RPC error it ends with an error status and `rpc.jsonrpc.error_code`; when the connection closes before an answer it ends with an error status and `error.type`.
- Each event the gateway pushes SHALL be one instant consumer span named `<event> receive` with `messaging.system` = `hermes.gateway`, `messaging.operation.type` = `receive` and `messaging.destination.name` = the event type, ended immediately with status OK. Only the events the app handles (`message.start`, `message.complete`, `tool.start`, `tool.complete`, `session.title`, `sessions.changed`, `approval.request`, `approval.expire`, `clarify.request`, `clarify.expire`) SHALL be named after their type; any other event type SHALL be recorded as `other`.
- Reply deltas (`message.delta`) SHALL NOT produce a span, so that streaming a reply does not emit one span per chunk.
- Request and event spans SHALL be linked to the span of the connection and SHALL NOT be its children, so that no trace stays open for as long as the connection lives. A request or event recorded before any connection span has ended has no link.

The Kanban events socket (`/api/plugins/kanban/events`) is not traced.

#### Scenario: Socket opens

- **WHEN** the chat opens its socket to the gateway
- **THEN** one client span `HTTP GET` with `http.route` = `/api/ws` and `http.status_code` = 101 is ended with status OK

#### Scenario: Socket cannot be opened

- **WHEN** opening the socket fails with an exception
- **THEN** the upgrade span is ended with an error status and `error.type` set to the exception's type name
- **AND** the exception still reaches the caller

#### Scenario: Request answered

- **WHEN** the app sends `prompt.submit` as request 3 and the gateway answers with a result
- **THEN** a producer span `prompt.submit send` with `messaging.message.id` = `3` and `rpc.method` = `prompt.submit` is ended with status OK
- **AND** it is linked to the connection span

#### Scenario: Request answered with an error

- **WHEN** the gateway answers a request with a JSON-RPC error whose code is -32000
- **THEN** the request span is ended with an error status and `rpc.jsonrpc.error_code` = -32000
- **AND** the error message the gateway supplied is not recorded

#### Scenario: Connection closes with a request outstanding

- **WHEN** the socket closes before the gateway answered a request
- **THEN** the request span is ended with an error status and `error.type` = `GatewayConnectionClosed`

#### Scenario: Server event

- **WHEN** the gateway pushes a `tool.start` event
- **THEN** a consumer span `tool.start receive` is recorded and ended, linked to the connection span

#### Scenario: Unknown event type

- **WHEN** the gateway pushes an event type the app does not handle
- **THEN** the span is named `other receive` and `messaging.destination.name` is `other`, not the event type

#### Scenario: Reply deltas are not traced

- **WHEN** a reply streams as many `message.delta` events
- **THEN** no span is recorded for any of them

#### Scenario: Kanban events socket

- **WHEN** the Kanban tab opens its events socket
- **THEN** no gateway span is recorded for it

### Requirement: Gateway telemetry never records what is sent or received

The gateway spans SHALL record only method names, event type names, request ids, the connection route and error codes. They SHALL NOT record request parameters, results, event payloads, message or reply text, session ids, the ticket, token or any other query parameter of the socket URL, the host, error messages from the gateway, or exception messages. The route recorded for the upgrade SHALL be the socket path only. The system SHALL NOT add a `traceparent` header or any other header to the socket upgrade. While telemetry is disabled the system SHALL NOT record any gateway span.

#### Scenario: Prompt text and session id stay out

- **WHEN** the app submits the prompt "my secret prompt" to session `abc123` and the reply streams back
- **THEN** no attribute of any gateway span contains the prompt text, the reply text or `abc123`

#### Scenario: Credentials in the socket URL

- **WHEN** the socket is opened with the query parameter `ticket=hunter2`
- **THEN** the upgrade span has `http.route` = `/api/ws` and nothing on any gateway span contains `hunter2`

#### Scenario: Telemetry off

- **WHEN** telemetry is disabled and the chat sends a message
- **THEN** no gateway span is recorded and the chat behaves as usual

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

#### Scenario: Tracer throws on the gateway socket

- **WHEN** the tracer throws while the socket is opened, a request is sent or an event arrives
- **THEN** the socket still opens, the request still completes with the gateway's answer and the event still reaches the chat

#### Scenario: Logger throws on an HTTP request

- **WHEN** the logger throws while a request finishes
- **THEN** the request completes with its normal response and the span is still ended

#### Scenario: Logger throws on an event

- **WHEN** the logger throws while an app event is emitted
- **THEN** the event call returns normally

#### Scenario: Logger throws on an uncaught error

- **WHEN** the logger throws while an uncaught error is reported
- **THEN** the error still reaches the previously installed handler
