# Other Hermes KPIs

- **Adoption:** App Store Connect first-time downloads, redownloads, installs, and retention, each named as Apple's metric and time period. Downloads and installs are not active people.
- **Reliability:** In SignalDB Errors or `query_ir` over logs, count error records by `exception.type`, service version, and environment. Compare error counts with session counts only if the same population and window are actually covered. Check current crash-reporting implementation before describing what error messages or stacks contain; `CLAUDE.md` and `PRIVACY.md` disagree.
- **Network performance:** Use Catalog/Traces or `query_ir` for request count, failed request share, and p95 duration, grouped by `http.route`, method, version, and environment. The app records only the first two route segments. A request or gateway event count measures operations, not users.
- **Sign-in:** Count `auth.sign_in.started`, `.succeeded`, `.failed`, and `.cancelled` in logs for the same window; success rate is succeeded / started when the events are complete. Session refresh and expiry, gateway RPC/event failures, and error codes are further diagnostic signals.

Telemetry is off in builds without `OTEL_EXPORTER_OTLP_ENDPOINT`; release configuration is in `fastlane/Fastfile` and `lib/src/telemetry/telemetry_config.dart`. Absence of data may mean no instrumented build or no matching events. Use `openspec/specs/telemetry/spec.md` to check emitted events and attributes before asserting a KPI is available.
