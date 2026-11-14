## 1. Contracts and catalog

- [x] 1.1 Start with failing RPC tests for rich profile rows, missing optional previews, unsupported contracts, metadata CAS conflicts, partial saves, and fresh-profile creation without messaging channel copying; add typed roster parsing and read-only capability probes.
- [x] 1.2 Extract shared authenticated gateway ownership as a pure refactor; preserve existing request timeout, event subscription, auth refresh, and opt-in tracing behavior with representative existing tests.
  Evidence: `AppShell` owns one `HermesGatewayTransport` (`lib/src/shell/app_shell.dart`, `initState`) and hands its `request` to `BotModeRosterRepository`, `BotModeChatRepository` and `HermesGroupsRepository`; the `GatewayRequester` interface (`lib/src/chat/chat_transport.dart`) is the shared contract. Landed with the `bot-mode-groups` work; the transport's timeout, event and tracing behavior stays covered by `test/gateway/`.
- [ ] 1.3 Start with failing widget tests for plain-model roster tiles and editor states; add Widgetbook loading/empty/error/populated, long title, partial save, and conflict cases in both themes and phone/desktop widths before wiring screens.
  Remaining: `test/bot_mode_roster_screen_test.dart` and `widgetbook/bot_mode_roster_use_cases.dart` cover roster loading, empty, unavailable, error, populated and long-title states and the creation and edit fields (saving, retry). The editor's partial-save and revision-conflict banners are built inline in `bot_mode_roster_screen.dart` (the edit dialog), so they have no plain-model widget, no Widgetbook case and no widget test.

## 2. Roster integration

- [ ] 2.1 Start with failing shell tests for supported/unsupported/transient Bot Mode states; wire Bots as a primary destination with searchable roster and explicit add-existing-profile behavior, retaining Profiles and Messaging management.
  Remaining: the Bots destination is wired (`_Destination.bots` in `app_shell.dart`, shown whenever the app has a gateway) and the screen tests cover search, add-existing-profile, the unavailable state and a Retry on error. No test builds the shell and checks the Bots destination across supported, unsupported and transient-failure states, and a transient failure after a successful load is not tested.
- [ ] 2.2 Start with failing editor flow tests for create, configure failure after create, cancel, revision conflict, and model confirmation; implement fresh creation and minimal identity/model/SOUL editing with unsaved input retained.
  Remaining: creation, configure failure after create (retry without recreating), duplicate-submit prevention and model-load failure are tested in `test/bot_creation_test.dart`, and the edit save in `test/bot_mode_roster_screen_test.dart`. The screen implements revision conflict and expensive-model confirmation, but no flow test exercises either, and no test cancels the editor with unsaved input.
- [x] 2.3 Verify metadata read-modify-CAS preserves unknown fields and inspect requested applied sections independently; keep secrets server-side and provider mirroring explicit. Add no content telemetry, and reuse existing method/status tracing only.

## 3. Verification

- [ ] 3.1 Add isolated-backend contract checks against the pinned source baseline; no new REST routes are planned, so OpenAPI regeneration is unnecessary unless implementation discovers a needed REST extension (then update the source spec and run the generator).
  Remaining: `test/bot_mode_chat_contract_test.dart` already runs `profiles.create`, `profiles.configure` with a revision CAS and `BotModeRosterRepository.load` against an isolated backend (skipped without `HERMES_DEV_URL`). It does not check a CAS conflict, a partial save, `profiles.describe`, or that `clone_channels: false` kept messaging channels out of the new profile. Needs a throwaway Hermes (not on PATH in the delivery environment).
- [x] 3.2 Update README/CLAUDE.md and any stale project skills; record recurring Bot Mode contract verification in a project skill if useful. Keep `feat(bots)` near 500 changed lines, splitting advanced lifecycle work before coding if needed.
- [ ] 3.3 Run `dart format`, `flutter analyze`, `flutter test`, Widgetbook and management workflow screenshots, inspect images, and complete verify-in-app with an isolated Hermes home before marking UI/connection tasks done.

## Status

Partly done (checked 2026-11-14 against `lib/src/bot_mode/`, `lib/src/shell/`, `test/`, `widgetbook/`, `docs/architecture/bot-mode.md` and `openrpc/` at the Hermes ref in `openapi/HERMES_REF`; the Hermes source itself was not reachable, so server claims rest on `openrpc/hermes-gateway.openrpc.json`). The roster, fresh creation and identity/model/SOUL editing ship. The server supports everything the change needs: `profiles.list`, `profiles.describe`, `profiles.create` and `profiles.configure` are in the pinned contract, so nothing here is blocked on Hermes.

Left to build: 1.3 (editor conflict and partial-save widget and Widgetbook states), 2.1 (shell tests for supported, unsupported and transient states), 2.2 (conflict, model-confirmation and cancel flow tests), 3.1 (roster contract checks against an isolated backend).

Left to run, not code: 3.3 (format, analyze, test, Widgetbook and workflow screenshots, `verify-in-app` with an isolated Hermes home). It needs `hermes` on PATH; the delivery environment has none, so it was not run. Once 1.3, 2.1, 2.2 and 3.1 are done, move 3.3 under a `## Not verified on a device` section and archive.
