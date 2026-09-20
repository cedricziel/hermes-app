## MODIFIED Requirements

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
