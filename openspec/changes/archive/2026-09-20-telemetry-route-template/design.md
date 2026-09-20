## Context

The interceptor only sees the concrete request path (`/api/sessions/abc123/messages`), not the route template the generated client built it from. Path parameters are arbitrary strings (a profile name looks like any static segment), so they cannot be recognised by shape.

## Decision

Keep the first two path segments and drop the rest.

- It never leaks a parameter as long as no route puts a parameter in the first two segments. In the backend's OpenAPI spec every parameter sits at the third segment or later, and the first two are static (`/api/sessions`, `/api/profiles`).
- Replacing "variable-looking" segments with `{id}` was rejected: names such as `work-laptop` or `github` look static, so it would leak by design.
- Matching against a table of route templates was rejected: the table has to be kept in step with the spec, and an out-of-date table fails open.
- Cost: nested static routes collapse (`/api/plugins/kanban/tasks` and `/api/plugins/kanban/board` are both `/api/plugins`). Status and duration are still recorded per method.

Empty segments are skipped, so `/api/sessions/` and `/api/sessions` give the same route, and `/` stays `/`.

## Platforms and invariants

All platforms, same Dart code. No native, entitlement or manifest change. Touches the telemetry invariant: it stays opt-in and the interceptor still cannot throw into the request path.
