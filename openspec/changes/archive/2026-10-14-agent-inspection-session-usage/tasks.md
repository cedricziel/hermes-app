## 1. Session usage data

- [x] 1.1 Write failing gateway tests for repeated ticks, final snapshots, missing metrics, malformed numbers, and wrong-session events, then implement scoped usage mapping and replace-only reduction.
- [x] 1.2 Write failing RPC tests for explicit profile and session, unsupported methods, reconnect, and stale fetch generations, then add disclosure-triggered usage fetch and freshness state.

## 2. Usage disclosure

- [x] 2.1 Write failing widget tests and add Widgetbook cases for complete, partial, estimated, stale, loading, and unsupported usage, then build the compact disclosure.
- [x] 2.2 Write a failing chat integration test for disclosure opening and profile switching, then wire the disclosure into the active conversation.
- [x] 2.3 Write failing telemetry tests for redaction and telemetry failure, then add the fetch span, fixed failure event, and open breadcrumb described in design.md.

## 3. Verification

- [x] 3.1 Check project verification guidance and add reusable usage scenarios in a feature scenario file. Keep the standalone module and owned-runtime integration in one coherent change; the neutral binding API is the prerequisite for later consumers.
- [x] 3.2 Run scoped format, analyzer, and regression tests. Evidence: the reentrant bind regression failed with one obsolete RPC before the guard fix; the final six-file test batch passed all 43 tests and the analyzer reported no issues across 19 paths.
- [ ] 3.3 Run the isolated verify-in-app loop covering live ticks, final usage, disconnected freshness, and unsupported backend behavior. Native verification was not performed in this implementation checkout.
