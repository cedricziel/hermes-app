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

The resource SHALL also carry `app.installation.id`: the vendor identifier (`identifierForVendor`) on iOS, `ANDROID_ID` on Android, and on other systems a random UUID created on first use and kept in the app support directory. It SHALL be omitted when it cannot be read or stored.

The system SHALL NOT include the device name, hardware identifiers, locale, memory or disk sizes, or a build fingerprint. If reading the hardware facts fails, the system SHALL export the resource with the remaining attributes; if reading the basic attributes fails, it SHALL export the resource without any device attribute.

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

#### Scenario: Installation ID is vendor-scoped

- **WHEN** the resource is exported on iOS
- **THEN** `app.installation.id` is the vendor identifier, which changes once every app of the vendor is removed
- **AND** on macOS it is the same UUID on every launch until the app's support data is removed

#### Scenario: Nothing that identifies a person or the hardware

- **WHEN** the resource is exported on any platform
- **THEN** it has no device name, hardware identifier, locale, memory size or disk size

### Requirement: Every HTTP request through the app's clients is traced and logged

When telemetry is enabled the system SHALL add one interceptor to every HTTP client the connection controller builds (the authenticated client, the token endpoint client and the page-token client) that records one client span and one log record per request. The span SHALL be named `HTTP <METHOD>` and carry `http.request.method`, `http.route` (when known), `http.response.status_code` (when there is a response) and `error.type` (when the request failed). The span status SHALL be an error for a failed request or a status of 400 or above, and OK otherwise. The log record SHALL have the body `HTTP <METHOD> [<route>] <status or error type>`, the attributes `http.request.method`, `http.route` (when known), `http.response.status_code` (when known), `http.duration_ms` and `error.type` (when failed), severity `error` when the request failed or the status is 400 or above and `info` otherwise, so the span and the log always agree on whether a request failed, and the trace and span identifiers of the request span. The span SHALL always be ended, whether the request succeeded or failed.

#### Scenario: Successful request

- **WHEN** the app requests `GET /api/status` and the server answers 200
- **THEN** one span `HTTP GET` with `http.route` = `/api/status`, `http.response.status_code` = 200 and status OK is ended
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

- Opening the socket SHALL be one client span named `HTTP GET` with `http.request.method` = `GET` and `http.route` = `/api/ws`. When the upgrade succeeds the span carries `http.response.status_code` = 101 and status OK; when opening fails it carries `error.type` (the exception type name only) and an error status, and the exception is passed on unchanged. The span is always ended.
- Each JSON-RPC request SHALL be one producer span named `<method> send`, started when the request is sent and ended when the gateway answers. It carries `messaging.system` = `hermes.gateway`, `messaging.operation.type` = `send`, `messaging.destination.name` and `rpc.method` (the method name), `messaging.message.id` (the JSON-RPC request id), `rpc.system` = `jsonrpc` and `rpc.jsonrpc.version` = `2.0`. It ends with status OK on a result; on a JSON-RPC error it ends with an error status and `rpc.jsonrpc.error_code`; when the connection closes before an answer it ends with an error status and `error.type`.
- Each event the gateway pushes SHALL be one instant consumer span named `<event> receive` with `messaging.system` = `hermes.gateway`, `messaging.operation.type` = `receive` and `messaging.destination.name` = the event type, ended immediately with status OK. Only the events the app handles (`message.start`, `message.complete`, `tool.start`, `tool.complete`, `session.title`, `sessions.changed`, `approval.request`, `approval.expire`, `clarify.request`, `clarify.expire`) SHALL be named after their type; any other event type SHALL be recorded as `other`.
- Reply deltas (`message.delta`) SHALL NOT produce a span, so that streaming a reply does not emit one span per chunk.
- Request and event spans SHALL be linked to the span of the connection and SHALL NOT be its children, so that no trace stays open for as long as the connection lives. A request or event recorded before any connection span has ended has no link.

The Kanban events socket (`/api/plugins/kanban/events`) SHALL be traced the same way, with `messaging.system` = `hermes.kanban`: its upgrade is a client span with `http.route` = `/api/plugins/kanban/events`, and each event in a received batch is an instant consumer span named after its `kind`. Only the kinds the Kanban plugin writes to its task events (`archived`, `assigned`, `attached`, `blocked`, `changes_requested`, `claim_rejected`, `claimed`, `commented`, `completed`, `created`, `decomposed`, `dependency_wait`, `edited`, `gave_up`, `linked`, `promoted`, `reclaimed`, `reconciled`, `reprioritized`, `review_requested`, `scheduled`, `spawned`, `stale`, `status`, `timed_out`, `unblocked`, `unlinked`) SHALL be named after their kind; any other kind SHALL be recorded as `other`. `heartbeat` events SHALL NOT produce a span. A frame that cannot be decoded SHALL be passed on to the board unchanged and record nothing.

#### Scenario: Socket opens

- **WHEN** the chat opens its socket to the gateway
- **THEN** one client span `HTTP GET` with `http.route` = `/api/ws` and `http.response.status_code` = 101 is ended with status OK

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

- **WHEN** the Kanban tab opens its events socket and receives a batch with a `claimed` event, a `heartbeat` and an event of an unknown kind
- **THEN** an upgrade span with `http.route` = `/api/plugins/kanban/events` is recorded
- **AND** consumer spans `claimed receive` and `other receive` with `messaging.system` = `hermes.kanban` are recorded, and none for the heartbeat
- **AND** the board receives the frame unchanged

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

#### Scenario: A failed send says where it stopped

- **WHEN** a send fails, before or after the prompt was submitted
- **THEN** the system logs `gateway.send_failed` with `step` (`connect`, `open`, `attach`, `submit` or `reply`), `new_thread`, and `cause` (`closed`, `rejected` with the gateway's `code`, `profile`, `timeout`, or `other` with the exception's type name)
- **AND** the record carries no prompt text, error message or session id

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

### Requirement: Navigation and chat activity are kept as breadcrumbs for crash reports

When telemetry is enabled the system SHALL keep the last 40 breadcrumbs in memory, shared with the app events above, and attach them to the log record of an uncaught error. A breadcrumb is a name and a few attributes of fixed names and coarse values: a destination, a state, a count, a flag or an outcome. The system SHALL NOT export a breadcrumb as a log record of its own, and SHALL NOT put message or prompt text, a chat title, a profile name, a server address or a chat or session id in one. Recording a breadcrumb SHALL never throw, and does nothing when telemetry is off. The breadcrumbs are:

- `nav.destination` with `destination` (`chat`, `bots`, `kanban`, `schedules` or `profiles`) when the shell moves to another destination; `gone` = true when the destination in front went away and the shell fell back to Chat.
- `app.lifecycle` with `state` (`resumed` or `paused`).
- `chat.threads.loaded` with `switched` (the profile changed) and `count`; `chat.threads.failed`.
- `chat.thread.selected` with `remote`; `chat.thread.new`; `chat.thread.closed`.
- `chat.open.requested` with `fetch_missing`, when a notification, handoff or search asks for a chat; `chat.open.failed` when it could not be opened.
- `chat.reply.started` with `queued` and `attachments` (a count); `chat.reply.ended` with `outcome` (`completed`, `stopped`, `failed` or `folded`).
- `window.opened` and `window.closed`, each with `open` (how many conversation windows are open), and `window.key` with `conversation` (a conversation window rather than the main window is key), on macOS.
- The `gateway.reconnect`, `gateway.turn_settled`, `gateway.event_unmapped` and `gateway.send_failed` app events, which are also breadcrumbs.

#### Scenario: Moving between destinations

- **WHEN** the user opens Kanban and then Chat
- **THEN** the breadcrumbs `nav.destination` with `destination` = `kanban` and `nav.destination` with `destination` = `chat` are recorded in that order
- **AND** opening the destination that is already in front records nothing

#### Scenario: App goes to the background

- **WHEN** the app is paused and then resumed
- **THEN** `app.lifecycle` is recorded with `state` = `paused` and then `resumed`
- **AND** the passing `inactive` and `hidden` states record nothing

#### Scenario: A reply

- **WHEN** the user sends a prompt and the reply completes
- **THEN** `chat.reply.started` and `chat.reply.ended` with `outcome` = `completed` are recorded
- **AND** neither carries the prompt, the reply, the chat title, the profile name or the chat id

#### Scenario: A reply that cannot finish

- **WHEN** a send fails, or its stream ends with no completion
- **THEN** `chat.reply.ended` is recorded with `outcome` = `failed`

#### Scenario: A crash after a chat was opened

- **WHEN** an uncaught error is reported after the user opened a chat
- **THEN** the crash record's `breadcrumbs` list `chat.thread.selected` before the error
- **AND** no log record named `chat.thread.selected` was exported

#### Scenario: Telemetry off

- **WHEN** telemetry is disabled and the user navigates
- **THEN** nothing is recorded and nothing fails

### Requirement: Uncaught errors are logged as crash records

When telemetry is enabled the system SHALL log an uncaught Flutter framework error as an error log record with the body `Uncaught Flutter error`, and an uncaught asynchronous error as one with the body `Uncaught async error`. The record SHALL carry `exception.type` (the runtime type name of the error), `exception.message` (the error's text), `exception.stacktrace` when the error came with a stack trace, and `breadcrumbs` (the recent breadcrumbs, oldest first) when there are any. The message and the stack trace SHALL each be kept up to 4096 bytes of UTF-8, the largest attribute value SignalDB keeps by default. A longer stack trace is cut after its last whole frame that fits and ends with a line `... N more frames`. A longer message is cut and ends with `…`. The `breadcrumbs` list SHALL fit the same 4096 bytes counted the way SignalDB counts an array, as the encoded size of all elements together: the oldest breadcrumbs are left out first, and the list then starts with a line `... N older breadcrumbs dropped`. A single breadcrumb that is longer than that alone is cut and ends with `…`. A missing stack trace SHALL NOT be replaced by another one.

An error that recurs SHALL be logged in full the first time only. Later occurrences with the same body, type, message and top five stack frames SHALL be counted instead. At most once a minute, the error SHALL be logged again with the same attributes plus `exception.repeat_count`, the number of occurrences that record stands for. Up to 100 different errors are tracked. Beyond that, the least recently seen one is forgotten after its pending count is logged.

For every occurrence, logged or counted, the system SHALL then call the error handler that was installed before it. For asynchronous errors the result of that handler is returned, and it is `false` (unhandled) when there was none.

#### Scenario: Framework error

- **WHEN** a framework error with the message `boom` is reported after the event `auth.signed_in`
- **THEN** one error log `Uncaught Flutter error` is emitted with `exception.type` = `StateError`, an `exception.message` containing `boom`, and `breadcrumbs` listing `auth.signed_in`
- **AND** the previously installed Flutter error handler is still called

#### Scenario: Async error

- **WHEN** an asynchronous `ArgumentError` with the message `bad input` and a stack trace is reported
- **THEN** one error log `Uncaught async error` is emitted with `exception.type` = `ArgumentError`, the message and the stack trace
- **AND** the previous platform handler's verdict is returned

#### Scenario: No previous handler

- **WHEN** an uncaught asynchronous error is reported and no platform handler was installed before
- **THEN** the error is logged and reported as unhandled (`false`)

#### Scenario: Error repeated on every frame

- **WHEN** the same framework error is reported 50 times in a row
- **THEN** one error log `Uncaught Flutter error` is emitted
- **AND** a minute later the error is logged once more with `exception.repeat_count` = 49

#### Scenario: Long stack trace

- **WHEN** an error is reported with a stack trace longer than 4096 bytes
- **THEN** its `exception.stacktrace` is at most 4096 bytes, starts with the top frame and ends with `... N more frames`

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
- `hermes.profile.count` (int): the number of names in `profiles` (Hermes lists parked profiles apart, in `parked_profiles`). Left out when `gateway_mode` is `unknown`, because Hermes then sends an empty list.
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

### Requirement: Socket and feature telemetry carries the connected server's attributes

When telemetry is enabled the system SHALL add the `hermes.*` attributes of a connection, as defined in "HTTP and connection telemetry carries the connected server's attributes", to:

- every span of the chat gateway sockets (`/api/ws`) opened on that connection: the upgrade span, request spans and event spans;
- every span of the Kanban events socket (`/api/plugins/kanban/events`) opened on that connection: the upgrade span and event spans;
- the app events logged by the gateway transport (`gateway.reconnect`, `gateway.turn_settled`, `gateway.event_unmapped`, `gateway.send_failed`), the Kanban board (`kanban.events.reconnect`), the plugin, catalog and provider screens (`plugins.*`) and the skills hub (`skills.job`) while they work against that connection.

A socket keeps the attributes of the connection it was opened on for as long as it lives, including across its own reconnects. Attributes a span or log record sets itself SHALL take precedence. Breadcrumbs of these events SHALL NOT carry `hermes.*` attributes. Events of the watch bridge and the token store SHALL NOT carry them. While telemetry is disabled no attribute is computed and the sockets behave as before.

No backend change is needed: the attributes come from the `GET /api/status` answer read when the app connects; the sockets and their frames are unchanged.

#### Scenario: Gateway spans are described

- **WHEN** the app is connected to a server reporting `version` = `0.14.2` and `install_id` = `inst_42`, and the user submits a prompt
- **THEN** the `/api/ws` upgrade span, the `prompt.submit send` span and the `message.complete receive` span carry `hermes.version` = `0.14.2` and `hermes.install_id` = `inst_42`

#### Scenario: Kanban spans are described

- **WHEN** the Kanban tab opens its events socket on that connection and receives a `claimed` event
- **THEN** the upgrade span and the `claimed receive` span carry the server's `hermes.*` attributes

#### Scenario: Gateway reconnect event is described

- **WHEN** the gateway socket drops while a reply runs and the transport reconnects
- **THEN** the `gateway.reconnect` log record carries the server's `hermes.*` attributes
- **AND** its breadcrumb does not

#### Scenario: Plugin action is described

- **WHEN** the user enables a plugin
- **THEN** the `plugins.enable.*` log record carries the server's `hermes.*` attributes

#### Scenario: Socket outlives a switch

- **WHEN** a gateway socket opened on server A is still open after the user connects to server B, and receives an event
- **THEN** that event's span carries server A's attributes
- **AND** sockets opened after connecting to B carry server B's

#### Scenario: Watch bridge stays undescribed

- **WHEN** the watch bridge logs an event
- **THEN** the record has no `hermes.*` attribute

### Requirement: Each socket links its messages to its own upgrade

Each gateway and Kanban socket SHALL link its request and event spans to the upgrade span of that same socket. When two sockets are open at once, for example the chat screen's and the shell's gateway sockets, neither SHALL link its messages to the other's upgrade span.

#### Scenario: Two gateway sockets

- **WHEN** the chat screen and the shell each open a gateway socket, and each then sends a request
- **THEN** each request span is linked to the upgrade span of the socket it was sent on

