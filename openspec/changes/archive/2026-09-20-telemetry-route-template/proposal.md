## Why

`HttpTelemetryInterceptor` records `http.route` on every span and log record. It strips the query string and fragment but keeps the rest of the path, so path parameters go out verbatim: `/api/sessions/<id>`, `/api/profiles/<name>`, `/api/cron/jobs/<id>`, `/api/plugins/kanban/tasks/<id>`. Session ids, profile names and task ids can identify a user or their content. The class documentation and the spec both say nothing identifying is recorded, and `PRIVACY.md` lists only "the API path (for example `/api/status`)". Fixes #81.

## What Changes

- `http.route` records only the first two path segments of a relative request path, for example `/api/sessions` for `/api/sessions/<id>/messages` and `/api/status` for `/api/status`. Query string and fragment are still dropped, and absolute URLs still get no route.
- The HTTP telemetry spec states this rule and its scenarios.
- `PRIVACY.md` describes the truncated path.

## Impact

- Code: `lib/src/telemetry/http_telemetry_interceptor.dart`.
- Tests: `test/http_telemetry_interceptor_test.dart` gains parameterised-path cases.
- Docs: `PRIVACY.md`, `openspec/specs/telemetry/spec.md`.
- No change to the generated API client, no new route, no dependency.

## Non-goals

- Per-endpoint granularity. Routes under `/api/plugins/...` and `/api/mcp/...` collapse to two segments. Recovering them would need a route table that has to track the backend's OpenAPI spec.
- Redacting anything else. Other attributes are unchanged.
- Changing how telemetry is enabled (it stays opt-in and off by default).

## Security and privacy impact

Reduces what leaves the device when telemetry is enabled: path parameters (session ids, profile names, task ids, board slugs, server names) are no longer exported. Tokens, secure storage and the auth flow are untouched. `PRIVACY.md` is updated to match.

## Telemetry emitted

No new spans, log events or attributes. `http.route` on the existing HTTP span and log record changes from the full path to its first two segments.
