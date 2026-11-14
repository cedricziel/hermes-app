# Tasks

Two PRs: the catalog PR first (`feat(profile-soul): Personality widgets in the catalog`, about 250 changed lines), then the screen PR (`feat(profile-soul): edit a profile's SOUL.md`, about 400). The design is in `docs/design-briefs/profile-soul.md`. Status: Design: brief reviewed, canvas pending (publish quota, resumes after 2026-11-15 00:00 UTC). No build starts before the canvas exists. Every behaviour task starts with a failing test. No OpenAPI change: both routes and `ProfileSoulUpdate` are already in the generated client.

## 1. PR 1: Catalog (widgets as plain-model use cases)

- [ ] 1.0 Wait for the finished Design canvas (https://claude.ai/artifact/P2oqCBdLmdviWpGWmZmRjB is incomplete); bring it and the brief in line before any task below starts.
- [ ] 1.1 Add the ARB strings (en and de, `profiles` area) for every state, question and note in the brief; run `flutter gen-l10n`.
- [ ] 1.2 Add `AppIcons.personality` (Material `face_outlined`, Cupertino `person_crop_circle`) and its entry in the icon use case.
- [ ] 1.3 Build `SoulEditor` (multiline field with hint, read-only mode, count line, 20,000-character note, hardened input) in `lib/src/profiles/soul/widgets/`, with a filled field while editable and transparent while read-only, and use cases for empty, not set yet, loaded, long, over 20,000, read-only, largest text, German; both themes, phone and desktop width.
- [ ] 1.4 Build `SoulStatusLine`, `SoulSaveActions` and `SoulChangedSheet` with use cases for each state in the brief (saved, not saved, error, saving, lost answer, checking, check failed, changed on the server with the server's text closed and open, file gone on the server).
- [ ] 1.4a Make `AppBanner` stack its action under the text at the largest text size and in German (text at full width), with use cases.
- [ ] 1.5 Add the Save and Discard questions as use cases of `showConfirmDialog` (normal, empty text, long profile name, Android with Cancel first and no filled default).
- [ ] 1.6 `flutter test test/widgetbook_test.dart` passes; update `docs/architecture/settings-screens.md` with the new widgets.

## 2. PR 2: Personality screen

- [ ] 2.1 Record fixtures from Hermes `d923a5eb` with `scripts/dev-backend.sh` (never the real `~/.hermes`): GET with text, absent file, empty file, BOM file, invalid UTF-8 file; PUT ok, 404 profile, 400 bad name, 422 missing content, 401. Note what the real 422 and plain 500 bodies look like. Add a check to `test/real_backend_contract_test.dart` (read only, never a PUT against a shared profile).
- [ ] 2.2 Write failing `SoulRepository` tests against `FakeHermesServer` with the real generated client: path carries the name and no query; parsing is lenient; `exists`/empty distinction; `profileGone` for a 404 detail starting "Profile '", `unsupported` for any other 404 or a 405; 200 without `ok: true` is unconfirmed; timeout is `lostAnswer`. Then implement it in `lib/src/profiles/soul/`.
- [ ] 2.3 Write failing `SoulController` tests: baseline after load and save; Save sends nothing until confirmed; the second read before PUT; changed on server sends nothing; Replace anyway sends once; check failure sends nothing; lost answer resends nothing and Check resolves it three ways (saved, never landed, changed); a failed read shows no editor; editor read-only while busy; dirty state; a text over 500,000 characters stays editable and savable; dropped on sign-out, server change and App Lock; late answers after close ignored; the check read and the PUT each time out after 10 s on a fake clock (a check timeout sends nothing and says so, a PUT timeout is the lost answer); Save after an unconfirmed save that landed reports Saved without a PUT; Check compares with the sent text, also after edits (equal to sent with `exists: true`: Saved and later edits stay dirty; a missing file with empty sent text is not Saved; equal to the old baseline: "earlier text" without a definite failure, and the next Save's question carries the pending-save line; else conflict); App Lock while a check or PUT is in flight discards the outcome and reloads the server's text after the unlock. Then implement it.
- [ ] 2.4 Write failing screen and navigation tests, then wire `SoulScreen` from the catalog widgets: sidebar row after Memory (drawer, More section), `ProfileSection` entry and Mac Profiles section, Discard question on back, Revert and Mac profile or section change, 404 hides the entries, the screen is bound to the profile it was opened for.
- [ ] 2.4a Add `MacCommand.save` (File > Save, ⌘S, `menuLayout`) offered by the Personality pane through `MacCommandScope`, enabled only while dirty and idle; test in `test/macos/mac_menu_bar_test.dart`.
- [ ] 2.5 Write a failing test that the spans, log event and breadcrumbs carry only the fixed fields (text and profile name set to marker strings, neither appears). Then add them.
- [ ] 2.6 Add a workflow test (`test/workflows/`) for edit, save question, conflict and save; look at the screenshots.
- [ ] 2.7 Update `docs/architecture/app-shell.md` (Personality entries) and `docs/roadmap.md`'s item 4.8 status in the PR.
- [ ] 2.8 Run `/simplify`, `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test`, and the `verify-in-app` loop against a throwaway backend.

## Not verified

- Real 422 and unhandled-500 bodies, BOM and lone-surrogate behaviour (2.1 records them).
- Whether a server older than `d923a5eb` has the routes: the app relies on a route-missing 404 or 405.
- How Hermes treats a distribution-owned SOUL.md in the prompt: not visible to the app.
