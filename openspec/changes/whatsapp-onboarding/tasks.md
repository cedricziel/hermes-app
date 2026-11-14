# Tasks

One PR of about 500 changed lines with tests. No OpenAPI change: all four routes are in `openapi/hermes-agent.openapi.json` and the generated methods exist.

## 1. PR 1 - `feat(messaging): link WhatsApp by QR code`

- [ ] 1.1 Record fixtures from Hermes `d923a5eb` with `scripts/dev-backend.sh` (never `~/.hermes`; note the revision): start (installing, waiting with a QR, already linked), status in each state, 410 expired, 404, apply (restart started, restart failed, 409, 400), cancel of a known and an unknown id. Where the server has no Node, stub the bridge and say so in the fixture file.
- [ ] 1.2 Write failing repository tests against `FakeHermesServer` with the real generated client: start body (`mode`, `allowed_users`, `profile`), apply with `profile` in query and body, `detail` for 400, 404 (profile, route-missing, record gone), 409, 410 and 500, unknown status read as working, connection loss kept apart from a refusal. Then add the group to `HermesMessagingRepository`.
- [ ] 1.3 Write failing controller tests: poll every 2 s, pause in the background, stop on a final state, cancel once on leave, no resend after a lost start or apply, Check after a lost apply, `allowed_users` validation. Then implement it.
- [ ] 1.4 Write a failing test that the QR payload and pairing id reach no span, log, breadcrumb, preference or clipboard, including the request span path (see design "Decisions"). Then add the spans, log events and breadcrumbs the proposal names.
- [ ] 1.5 Choose a QR package under the repo's pub.dev rule and say why in the PR. Build plain-model widgets in `lib/src/messaging/widgets/` (setup, preparing, handset notice, QR, linked, failed, finish result) with Widgetbook use cases in both themes, phone and desktop width, largest text, hidden and shown code. `flutter test test/widgetbook_test.dart` passes.
- [ ] 1.6 Wire the "Link WhatsApp" button into the WhatsApp setup form and the pairing screen, with the Finish confirmation (Cancel default). Hide the code on App Lock and when the lifecycle leaves `resumed`; handsets need the tap again. Tell a profile-detail 404 from a route-missing one.
- [ ] 1.7 Add the strings to `lib/l10n/arb/app_en.arb` and `app_de.arb` under the messaging area, run `flutter gen-l10n`.
- [ ] 1.8 Add a workflow test for the phone and desktop flows and look at the screenshots. Update `docs/architecture/settings-screens.md` (or the messaging section), `openspec/specs/profiles-and-bots/spec.md` by sync on archive, and `docs/roadmap.md` status.
- [ ] 1.9 Extend `test/real_backend_contract_test.dart` (skips without `HERMES_DEV_URL`) with start, status and cancel only; never apply.
- [ ] 1.10 Run `/simplify`, `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test`, and the `verify-in-app` loop on macOS.

## Not verified

- Baileys' QR rotation interval and the bridge's failure texts.
- A real scan: it needs a phone with WhatsApp; the unit tests stub the bridge.
- Windows servers.
- Whether the HTTP span interceptor templates paths (task 1.4 decides).
