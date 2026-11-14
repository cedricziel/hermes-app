# Tasks

Two PRs, catalog first. Design record: `docs/design-briefs/skills-curator.md`. No OpenAPI change: the three routes and `curator-run` are already in the spec and the generated client (`getCuratorStatusApiCuratorGet`, `setCuratorPausedApiCuratorPausedPut`, `runCuratorApiCuratorRunPost`). Every behaviour task starts with a failing test.

## 1. PR 1 - `feat(skills): add the skill curator widgets to the catalog`

Plain-model widgets and their Widgetbook use cases only; no controller, no repository, no screen change.

- [ ] 1.1 Extract the "Show details" lines tile from `lib/src/server_care/widgets/update_step_list.dart` into `lib/src/widgets/output_lines_tile.dart` (`OutputLinesTile`: label, lines, cap with "N earlier lines not shown", footnote, blank mode), keep the Update page using it, and move `GroupedActionRow` to `lib/src/widgets/` if skills would import it from `server_care`. Existing tests stay green.
- [ ] 1.2 `CuratorSection` (`lib/src/skills/widgets/curator_section.dart`) from one model and callbacks: loading, refreshing, never run, ran, paused, off in config, unknown fields, offline, curator could not load, other failure, profile gone; the Pause switch (idle, saving, failed, lost answer); the Run now row (idle, running, finished, finished with no output, failed, stopped with no exit code, not started in its three forms, lost answer, progress lost, still running).
- [ ] 1.3 `CuratorRunConfirmation` (`lib/src/skills/widgets/curator_run_confirmation.dart`): prune only, may also merge and rewrite, unknown config, with the `CommandRow`; Cancel first and default; stacked buttons at the largest text size.
- [ ] 1.4 Widgetbook use cases in `widgetbook/skills_curator_use_cases.dart` for every state above, light and dark, phone and desktop width, largest text; a Mac and an Android variant of the confirmation. `test/widgetbook_test.dart` passes.
- [ ] 1.5 Widget tests for the details that code owns: the interval wording, the Last ran value and exact time, "Unknown" values, targets of 44 pt, 48 dp and 28 pt, semantics labels, the blank output mode.
- [ ] 1.6 Add the strings to `app_en.arb` and `app_de.arb` (skills area), run `flutter gen-l10n`; check the German use cases for overflow.
- [ ] 1.7 Run `/simplify`, `dart format`, `flutter analyze`, `flutter test`.

## 2. PR 2 - `feat(skills): see, pause and run the skill curator`

About 500 changed lines on top of PR 1.

- [ ] 2.1 Record fixtures from Hermes `d923a5eb` with `scripts/dev-backend.sh` (never `~/.hermes`): `GET /api/curator` (never run, ran, paused, `enabled` false), pause answers, the run answer, `curator-run` status (running, exit 0, exit 1 disabled, after a dashboard restart), the 400 unnamed-run refusal, the 500 spawn failure, the 500 for a deleted profile (`Failed to run curator: 404: Profile ...`), 404 profile-missing and 404 route-missing on GET and PUT, 500 `Curator unavailable`, 400 invalid profile. Put them in `test/skills/curator_fixtures.dart`.
- [ ] 2.2 Write failing parser tests (missing and ill-typed fields, truncated input never throws), then `CuratorStatus` and a `curator-run` entry in `CareAction` (server-care's `ActionStatus`, not a copy), and `HermesCuratorRepository` using `authController.api!.raw`.
- [ ] 2.3 Write failing repository tests against `FakeHermesServer`: explicit `profile` on every call, a route-missing 404 (or 405) hides, a `Profile '` 404 does not, 400 and 500 detail kept, the 500 with `404: Profile '` read as profile gone, the status polled with `lines=2000`, a lost answer never retried.
- [ ] 2.3a Write failing controller tests (pause rollback on lost answer within 10 s, one run at a time, poll until `running` false, profile switch drops the old result, progress lost after 10 s, stop after 15 minutes, Check status reads once, config read never delays the confirmation), then `CuratorController`.
- [ ] 2.4 Wire `CuratorSection` into `SkillsScreen` (Installed tab, hidden while a search or filter is active), read the installed skills again when a run ends, and blank the output lines under App Lock and while inactive on a phone. Add the spans, log event and breadcrumbs from the proposal with tests that none holds a name or line.
- [ ] 2.5 Add a workflow test (`test/workflows/`) for pause, then a confirmed run, and look at the screenshots; check the screen with `verify-in-app`.
- [ ] 2.6 Extend `test/real_backend_contract_test.dart` (skips without `HERMES_DEV_URL`): status shape, pause round trip, one run on a throwaway home.
- [ ] 2.7 Update `docs/architecture/` (skills section in settings-screens.md) and `docs/roadmap.md` item 4.8 in the PR; run `/simplify`, `dart format`, `flutter analyze`, `flutter test`.

## Not verified

- Run against a live backend: nothing here was executed, only read from source at `d923a5eb`.
- The exact lines `hermes curator run` prints, beyond the `print` calls in `hermes_cli/curator.py::_cmd_run`.
- The shape of `curator.consolidate` in `GET /api/config`; the code must fall back to the "unknown" wording.
- That an unknown profile on the GET and PUT answers 404 (read in `_resolve_profile_dir`, not run).
- The design (`docs/design-briefs/skills-curator.md`) was not drawn on a canvas or rendered; the catalog is its first visual check.
