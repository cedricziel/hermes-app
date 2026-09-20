## 1. Route template

- [x] 1.1 Add failing tests in `test/http_telemetry_interceptor_test.dart` for parameterised paths (sessions, profiles, kanban tasks and boards, nested `/api/mcp/servers/<name>/auth`, trailing slash, query and fragment)
- [x] 1.2 Record the first two path segments as `http.route` in `HttpTelemetryInterceptor` and update its class documentation
- [x] 1.3 Update the HTTP telemetry requirement in `openspec/specs/telemetry/spec.md`
- [x] 1.4 Update the request-path line in `PRIVACY.md`

## 2. Telemetry and skills

- [x] 2.1 No new telemetry: `http.route` on the existing span and log record is the only change
- [x] 2.2 No `.claude/skills` entry is affected

## 3. Verify

- [x] 3.1 `dart format .`, `flutter analyze` and `flutter test` pass
- [x] 3.2 No verify-in-app check needed: no UI, layout or connection behaviour changes
