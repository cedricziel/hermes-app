## 1. Define activity identity and native delivery

- [x] 1.1 Start with failing Dart tests for versioned payload validation, the size limit, explicit profile ownership, canonical URL comparison, forbidden URL components, and unsupported-platform behavior; implement the activity value and no-op platform boundary.
- [x] 1.2 Start with failing bridge tests for launch-time retention, listener-before-take draining, replacement by a newer receipt, and publish/clear operations; implement `hermes_app/handoff` in Dart and Swift with strong activity retention and matching release and development activity declarations.
- [x] 1.3 Start with failing native lifecycle tests where the Runner harness supports them, and a reproducible physical-device failure check otherwise; wire iOS scene cold and warm continuation and macOS app-delegate reception without breaking superclass forwarding, auth channels, or share delivery. Include native continuation failure reporting and required Xcode source references.

## 2. Prepare visible states before integration

- [x] 2.1 Start with failing widget tests for the connection prompt and restoration failure controls; add Widgetbook cases for an unconfigured device, another dashboard, a long URL, Cancel, unavailable chat, retryable connection failure, and development override mismatch. Verify light and dark themes at phone and desktop widths before screen wiring.

## 3. Restore and advertise chats

- [x] 3.1 Start with failing coordinator tests for cold startup, login, loaded and unlocked app-lock state, shell recreation, newer targets, sign-out, cancellation, and delayed completion; add the in-memory coordinator above auth routing and generation-based cancellation.
- [x] 3.2 Start with failing integration tests using `FakeHermesServer` and the real generated client for same-server restoration, duplicate thread IDs across profiles, a target outside the loaded page, missing profile or chat, denied access, and network retry. Wire `ChatOpenRequests` and existing profile-aware restoration; surface completion and retry outcomes without creating sessions or sending prompts.
- [x] 3.3 Start with failing connection-flow tests for Connect, Cancel, an unconfigured device, an accepted target across server setup and sign-in, and a fixed `HERMES_SERVER_URL`; wire the catalogued prompt to existing server-change and prefilled setup behavior. Confirm no request reaches a different dashboard before Connect.
- [x] 3.4 Start with failing eligibility tests for visible saved chats, unresolved profiles, unsaved chats, hosted groups, route coverage, deletion, app lock, auth readiness, and backgrounding with app lock off; wire publish and clear only when identity or eligibility changes. Suppress unrelated advertisement while restoration is pending.
- [x] 3.5 Start with a failing gateway regression test showing that a restored running chat attaches through `session.resume` without `prompt.submit` or `session.interrupt`; reuse existing follow-up transport. Confirm drafts and local queues stay on the source and existing bot-context hydration does not create or rebind a bot.

## 4. Document and verify

- [x] 4.1 Document Handoff setup and limitations in the README, and add cold and warm continuation, lock, failure, development activity types, and signing checks to `.claude/skills/verify-in-app/SKILL.md`. Keep device and backend checks on an isolated Hermes home with invented chats and test credentials. Extend the existing verification skill rather than introducing a duplicate workflow.
- [x] 4.2 Confirm no new Handoff telemetry or credential storage, no changed backend routes, and no generated client edits. Validate restoration against the Hermes compatibility baseline named in the spec. Keep implementation reviewable as `feat(handoff): continue saved chats across Apple devices`, targeting roughly 500 implementation lines with small coherent commits.
- [ ] 4.3 Run `openspec validate apple-handoff --strict`, `dart format`, `flutter analyze`, and `flutter test`; build iOS and macOS and run Widgetbook and workflow screenshot checks. Complete verify-in-app against an isolated backend, then two-way physical-device Handoff checks with matching signing teams for cold and warm launch, sign-in, lock, profile collisions, server mismatch, missing chat, reconnect, and active replies. Record unavailable device checks as outstanding rather than marking verification complete; clean up only task-owned instances.
