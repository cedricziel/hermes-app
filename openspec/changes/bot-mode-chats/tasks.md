## 1. Identity and catalog

- [x] 1.1 Start with failing RPC tests for exact lookup, compression tips, failed/uncertain absence, serialized creation, title materialization, pending title, and competing title adoption; implement the canonical repository on the shared gateway.
- [x] 1.2 Start with failing transport tests for two profiles sharing a stored session ID and reconnect after socket replacement; add owner-qualified maps and retain profile on every resume without changing the CLI default.
- [x] 1.3 Start with failing plain-widget tests for bot title/context and mention suggestions; add Widgetbook cases for empty conversation, long identity, ambiguous handles, disabled protocol, attributed handoff, busy/queued failure, and retry before screen integration.

## 2. Bot chat integration

- [x] 2.1 Start with failing open-request flows for switching bots while lookup is in flight and returning after app restart; wire canonical chat opening into the existing renderer and bot roster while preserving stored/runtime identity.
- [x] 2.2 Start with failing lifecycle tests for canonical rename prevention, explicit retirement, New Chat, and `/new` or `/reset` compaction; apply bot-specific controls without changing ordinary sessions.
- [x] 2.3 Start with failing messaging tests for selected teammate handles, unknown tokens, attribution, queued receipts, and ambiguous delivery; wire the mention picker and render backend local `message_agent` outcomes without injecting SOUL protocol or resending handoffs.
- [x] 2.4 Retain existing opt-in method/status tracing only; verify no conversation identity or content is added to telemetry. Reuse generated REST history/pin/archive calls; regenerate OpenAPI/client only if a new REST contract proves necessary.

## 3. Verification

- [ ] 3.1 Add isolated real-backend conformance for canonical creation/materialization, compression lineage, local bot delivery and resume; include multiple profile names and a competing creator without accessing real user profiles.
- [ ] 3.2 Update README/CLAUDE.md and stale project skills with canonical chat behavior; keep `feat(bots)` near 500 changed lines through existing renderer reuse, splitting optional presentation additions before implementation.
- [ ] 3.3 Run `dart format`, `flutter analyze`, `flutter test`, the component catalog and bot chat workflow screenshots; inspect images and complete verify-in-app for profile ownership, resume, handoff and retirement before marking UI/connection tasks done.
