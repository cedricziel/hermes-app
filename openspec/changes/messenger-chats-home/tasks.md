## 1. Reusable list presentation

- [x] 1.1 Extract reusable conversation-list content from `ThreadSidebar` without changing its existing behavior or chat ownership. Keep fixed sidebar framing separate from full-page presentation.
- [x] 1.2 Start with failing widget tests for compact Chats loading, empty, populated, search, and error/retry states. Add Widgetbook use cases for those states, recipient picker states, configured avatars, monogram and failed-image fallbacks, group avatar presentation, long profile names, long titles, large text, and light/dark themes before wiring the new presentation into screens.

- [x] 1.3 Start with failing avatar widget and repository tests for configured images, unsupported or failed reads, deterministic monograms, accessible names, and stale results after recipient/account changes. Reuse existing avatar presentation and authenticated profile-asset reads where supported, with server/account/profile-scoped in-memory state. Add row, chip, header, and group-avatar Widgetbook cases before screen wiring; introduce no asset writes or external image service.

## 2. Chats and conversation navigation

- [x] 2.0 Start with failing HTTP and gateway tests proving recipient selection, profile-page selection, history opening, send, and reconnect never POST /api/profiles/active or write profile configuration. Remove the default-changing side effects from chat selection, retain read-only default discovery, and bind chat state to profile plus session ID. Cover two profiles sharing a session ID, stale recipient responses, unavailable recipients, and another client changing the terminal default.

- [x] 2.1 Start with failing `chat_screen_test.dart` and `app_shell_test.dart` cases for ordinary compact launch, selecting a thread/search hit, and reaching available shell destinations. Wire Chats as compact home with title, menu, search, and New message, preserving current profile scope and capability gates.
- [x] 2.2 Start with failing tests for header Back, platform Back, protected editors, returning during generation, queued prompts, and draft restoration. Add compact detail navigation while retaining the existing controller and transport owner.
- [x] 2.3 Start with a failing New message flow test showing that composition and Back preserve the existing draft rules and never send implicitly. Wire a local profile recipient picker into New message on every Flutter platform; refresh profile-dependent model, starter, and microphone options before first send.
- [x] 2.4 Start with failing resize tests for list, selected detail, and new-message composition. Preserve tablet/desktop split views, macOS compact overlays, and existing sidebar controls without duplicate chat work.
- [x] 2.5 Start with failing deep-link, notification, and shared-content navigation regressions covering targeted launch, delayed targets, App Lock, protected editors, sign-out, and server/account replacement. Route accepted compact targets directly into detail through the existing queue; ensure Back reveals Chats.

- [x] 2.6 Start with failing integration widget tests showing the same profile avatar in conversation rows, recipient selection/chip, and chat headers on compact and wide layouts. Wire the reusable avatar into those surfaces; retain distinct group-avatar acceptance criteria for the separate Groups integration.

## 3. Delivery and verification

- [x] 3.1 Confirm that no new telemetry is needed, as specified in the proposal. Reuse existing diagnostics without adding content or identity attributes. Confirm generated REST and gateway contracts remain unchanged; no OpenAPI or client regeneration is required for this slice.
- [x] 3.2 Update affected project guidance and `.claude/skills/verify-in-app` plus the corresponding `.agents/skills/verify-in-app` entry if its compact drawer steps become stale. Document the Chats-first flow and check whether any repeated workflow needs a dedicated skill.
- [x] 3.3 Split delivery into coherent commits for local recipient selection, avatar components, conversation ownership, and Chats navigation. The original 500-line estimate does not cover the accepted avatar requirement and ownership regressions; keep those required behaviors together in the delivered feature. Keep all-agent aggregation, Agents management, preview rows, and Groups integration in separate follow-up changes.
- [x] 3.4 Run `openspec validate messenger-chats-home --strict`, `dart format`, `flutter analyze`, and `flutter test`. Complete verify-in-app with a fresh isolated backend/app profile: ordinary compact launch, select/Back, unsent draft, active reply, New message to a different profile with the terminal default unchanged, menu destinations, targeted launch, resize, avatar imagery/fallbacks and accessible identity, account-scoped image cleanup, and desktop parity. Inspect screenshots and tear down the throwaway instance before marking UI tasks complete.

## 4. Selector configuration states follow-up

- [x] 4.1 Add regression tests and Widgetbook cases for both recipient and model selectors: loading, missing selection, empty/incomplete configuration, unavailable recipient, error/retry, and ready. Cover independent recovery, draft/attachment preservation, stale results, supported legacy profile defaults, compact/wide layouts, large text, and side-by-side placement.
- [x] 4.2 Implement visible, accessible states for both composer selectors, actionable profile/model setup and refresh on return, and send gating when configuration is known to be unusable. Keep loading, empty, unsupported discovery, and failed requests distinct. Preserve local recipient ownership and existing backend contracts.
- [x] 4.3 Extend the verify skill for these states and exercise both controls against an isolated backend with incomplete and complete configuration. Verify setup recovery, Retry, model selection, and a successful send before marking this follow-up complete.
