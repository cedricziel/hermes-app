# Tasks

Design status (done): canvas published, local render reviewed, https://claude.ai/artifact/PPwKxdh8zKokvagfxS3Gho (private; ask its owner for access; 26 boards, one parametric page; the brief's "Local render review" lists what was and was not checked). The brief and design.md say "canvas published, local render reviewed" and keep the not-checked list (aligned in the data-layer PR). Delivery, in order: data layer (2.1, 2.2), controller and telemetry (2.3, 2.4), catalog widgets (section 1), then the screen (2.5 to 2.8); each its own stacked PR. No OpenAPI change: all four routes are in `openapi/hermes-agent.openapi.json` and the generated methods exist.

## 1. PR 1 - `feat(messaging): add the WhatsApp link widgets to the catalog`

Widgets only, per `docs/design-briefs/whatsapp-onboarding.md`. No controller, repository or screen change.

- [ ] 1.1 Choose a QR package under the repo's pub.dev rule and say why in the PR.
- [ ] 1.2 Build plain-model widgets in `lib/src/messaging/widgets/`: `WhatsAppSetupForm`, `PairingStageCard`, `HandsetQrNotice`, `QrCodeCard` (with the hidden state and the countdown), `ScanSteps`, `LinkedAccountCard` (new and already linked), `PairingEnd` (error, expired, superseded, gone, old server, profile deleted) and `WhatsAppPairingView`. Reuse the kit the brief names; no payload in semantics. Include the "Paused" line and the desktop hidden state ("Shows again when the app is unlocked and in front."). Follow the brief's "Local render review": mode sentences in the footer, the numbers field labelled by its section header, a 4-module quiet zone with an outline in both themes and fixed white/black, stacked buttons in the Finish dialog, and `GroupedRow` with `wrapWhenStacked` for the account rows.
- [ ] 1.3 Add Widgetbook use cases in `widgetbook/` for every state in the brief, in both themes, at phone and desktop width and at the largest text size, with an invented payload. `flutter test test/widgetbook_test.dart` passes.
- [ ] 1.4 Add the English strings to `lib/l10n/arb/app_en.arb` and `app_de.arb` under the messaging area, run `flutter gen-l10n`, and check German at the largest text size.
- [ ] 1.5 Add the widgets to `docs/architecture/settings-screens.md` (add a Messaging widgets paragraph), and correct the brief where a use case showed it wrong.

## 2. PR 2 - `feat(messaging): link WhatsApp by QR code`

About 500 changed lines with tests.

- [x] 2.1 Record fixtures from Hermes `d923a5eb` with `scripts/dev-backend.sh` (never `~/.hermes`; note the revision): start (installing, waiting with a QR, already linked), status in each state, 410 expired, 404, apply (restart started, restart failed, 409, 400), cancel of a known and an unknown id, and the platform list after a save. Where the server has no Node, stub the bridge and say so in the fixture file. Evidence: `test/messaging/whatsapp/whatsapp_fixtures.dart` and design.md "Recorded answers"; the bridge was not started (it would reach WhatsApp), so the QR and install states are from source.
- [x] 2.2 Write failing repository tests against `FakeHermesServer` with the real generated client: start body (`mode`, `allowed_users`, `profile`), apply with `profile` in query and body, `detail` for 400, 404 (profile, route-missing, record gone), 409, 410 and 500, unknown status read as working, connection loss kept apart from a refusal. Then add the group to `HermesMessagingRepository`. Evidence: `test/messaging/whatsapp/whatsapp_pairing_repository_test.dart` (written first, failed to compile), then the group in `HermesMessagingRepository`; the tests pass; the server's `error` and `detail` text is kept in an opaque holder for the screen (follow-up fix), and the contract checks (status and cancel of an unknown id, which tell a missing record from a missing route) are skipped without `HERMES_DEV_URL`.
- [ ] 2.3 Write failing controller tests: poll every 2 s, pause in the background and while App Lock is locked, resume on return once unlocked with the "paused" line, stop on a final state, cancel once on leave, no resend after a lost start or apply, 10 s limit on a lost start, apply and Check, Check outcomes, `allowed_users` validation, back disabled while apply is in flight. Then implement it.
- [ ] 2.4 Write a failing test that the QR payload and pairing id reach no span, log, breadcrumb, preference or clipboard, including the request span path (see design "Decisions"). Then add the spans, log events and breadcrumbs the proposal names.
- [ ] 2.5 Wire the "Link WhatsApp" button into the WhatsApp setup form and the pairing screen over the PR 1 widgets, with the Finish confirmation (Cancel default) and the saved banner on the Messaging list. Hide the code on App Lock, when the lifecycle leaves `resumed` and when a desktop window loses focus; handsets need the tap again. Polling follows the spec: it runs only while the app is in front and unlocked, and a line says it was paused once it resumes. Tell a profile-detail 404 from a route-missing one.
- [ ] 2.6 Add a workflow test for the phone and desktop flows and look at the screenshots. Update `docs/architecture/settings-screens.md` (the Messaging widgets paragraph), `openspec/specs/profiles-and-bots/spec.md` by sync on archive, and `docs/roadmap.md` status.
- [ ] 2.7 Extend `test/real_backend_contract_test.dart` (skips without `HERMES_DEV_URL`) with start, status and cancel only; never apply. (The status-of-an-unknown-id check is already in from the data-layer PR; start would spawn the bridge, so it is not run against a shared backend.)
- [ ] 2.8 Run `/simplify`, `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test`, and the `verify-in-app` loop on macOS.

## Not verified

- Baileys' QR rotation interval and the bridge's failure texts.
- A real scan: it needs a phone with WhatsApp; the unit tests stub the bridge.
- Windows servers.
- Whether the HTTP span interceptor templates paths (task 2.4 decides).

## Follow-ups outside this change

- Android `FLAG_SECURE` for the QR: not part of this change, no native work here. Roadmap candidate.
