## 1. Contracts and catalog

- [x] 1.1 Start with failing RPC tests for rich profile rows, missing optional previews, unsupported contracts, metadata CAS conflicts, partial saves, and fresh-profile creation without messaging channel copying; add typed roster parsing and read-only capability probes.
- [ ] 1.2 Extract shared authenticated gateway ownership as a pure refactor; preserve existing request timeout, event subscription, auth refresh, and opt-in tracing behavior with representative existing tests.
- [ ] 1.3 Start with failing widget tests for plain-model roster tiles and editor states; add Widgetbook loading/empty/error/populated, long title, partial save, and conflict cases in both themes and phone/desktop widths before wiring screens.

## 2. Roster integration

- [ ] 2.1 Start with failing shell tests for supported/unsupported/transient Bot Mode states; wire Bots as a primary destination with searchable roster and explicit add-existing-profile behavior, retaining Profiles and Messaging management.
- [ ] 2.2 Start with failing editor flow tests for create, configure failure after create, cancel, revision conflict, and model confirmation; implement fresh creation and minimal identity/model/SOUL editing with unsaved input retained.
- [x] 2.3 Verify metadata read-modify-CAS preserves unknown fields and inspect requested applied sections independently; keep secrets server-side and provider mirroring explicit. Add no content telemetry, and reuse existing method/status tracing only.

## 3. Verification

- [ ] 3.1 Add isolated-backend contract checks against the pinned source baseline; no new REST routes are planned, so OpenAPI regeneration is unnecessary unless implementation discovers a needed REST extension (then update the source spec and run the generator).
- [ ] 3.2 Update README/CLAUDE.md and any stale project skills; record recurring Bot Mode contract verification in a project skill if useful. Keep `feat(bots)` near 500 changed lines, splitting advanced lifecycle work before coding if needed.
- [ ] 3.3 Run `dart format`, `flutter analyze`, `flutter test`, Widgetbook and management workflow screenshots, inspect images, and complete verify-in-app with an isolated Hermes home before marking UI/connection tasks done.
