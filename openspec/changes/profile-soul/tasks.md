# Tasks

One PR of about 500 changed lines, `feat(profile-soul): edit a profile's SOUL.md`. Every behaviour task starts with a failing test. No OpenAPI change: both routes and `ProfileSoulUpdate` are already in the generated client.

## 1. PR 1: Personality screen

- [ ] 1.1 Record fixtures from Hermes `d923a5eb` with `scripts/dev-backend.sh` (never the real `~/.hermes`): GET with text, absent file, empty file, BOM file, invalid UTF-8 file; PUT ok, 404 profile, 400 bad name, 422 missing content, 401. Note what the real 422 and plain 500 bodies look like. Add a check to `test/real_backend_contract_test.dart` (read only, never a PUT against a shared profile).
- [ ] 1.2 Write failing `SoulRepository` tests against `FakeHermesServer` with the real generated client: path carries the name and no query; parsing is lenient; `exists`/empty distinction; `unsupported` for 404 "Not Found" but `profileGone` for "Profile ... does not exist."; 200 without `ok: true` is unconfirmed; timeout is `lostAnswer`. Then implement it in `lib/src/profiles/soul/`.
- [ ] 1.3 Write failing `SoulController` tests: baseline after load and save; Save sends nothing until confirmed; the second read before PUT; changed on server sends nothing; Replace anyway sends once; check failure sends nothing; lost answer resends nothing and Check resolves it both ways; dirty state; read-only above 500,000 characters; dropped on sign-out, server change and App Lock; late answers after close ignored. Then implement it.
- [ ] 1.4 Add the ARB strings (en and de, `profiles` area) for every state, question and note in the spec; run `flutter gen-l10n`.
- [ ] 1.5 Build plain-model widgets in `lib/src/profiles/soul/widgets/` (editor with count and notes, save question, changed-on-server question, status line) with Widgetbook use cases in `widgetbook/` before the screen: every state in the proposal's Design pass, both themes, phone and desktop width, largest text. `flutter test test/widgetbook_test.dart` passes.
- [ ] 1.6 Write failing screen and navigation tests, then wire `SoulScreen`: sidebar row after Memory (drawer, More section), `ProfileSection` entry and Mac Profiles section, 404 hides the entries, the screen is bound to the profile it was opened for.
- [ ] 1.7 Write a failing test that the spans, log event and breadcrumbs carry only the fixed fields (text and profile name set to marker strings, neither appears). Then add them.
- [ ] 1.8 Add a workflow test (`test/workflows/`) for edit, save question, conflict and save; look at the screenshots.
- [ ] 1.9 Update `docs/architecture/app-shell.md` (Personality entries) and `docs/roadmap.md`'s item 4.8 status in the PR.
- [ ] 1.10 Run `/simplify`, `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test`, and the `verify-in-app` loop against a throwaway backend.

## Not verified

- Real 422 and unhandled-500 bodies, BOM and lone-surrogate behaviour (1.1 records them).
- Whether a server older than `d923a5eb` has the routes: the app relies on the 404 `Not Found`.
- How Hermes treats a distribution-owned SOUL.md in the prompt: not visible to the app.
