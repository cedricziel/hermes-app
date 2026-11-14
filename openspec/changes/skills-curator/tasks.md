# Tasks

One PR of about 500 changed lines. No OpenAPI change: the three routes and `curator-run` are already in the spec and the generated client (`getCuratorStatusApiCuratorGet`, `setCuratorPausedApiCuratorPausedPut`, `runCuratorApiCuratorRunPost`). Every behaviour task starts with a failing test.

## 1. PR 1 - `feat(skills): see, pause and run the skill curator`

- [ ] 1.1 Record fixtures from Hermes `d923a5eb` with `scripts/dev-backend.sh` (never `~/.hermes`): `GET /api/curator` (never run, ran, paused, `enabled` false), pause answers, the run answer, `curator-run` status (running, exit 0, exit 1 disabled, after a dashboard restart), the 400 unnamed-run refusal, the 500 spawn failure. Put them in `test/skills/curator_fixtures.dart`.
- [ ] 1.2 Write failing parser tests (missing and ill-typed fields, truncated input never throws), then `CuratorStatus` and a `curator-run` entry in `CareAction` (server-care's `ActionStatus`, not a copy), and `HermesCuratorRepository` using `authController.api!.raw`.
- [ ] 1.3 Write failing repository tests against `FakeHermesServer`: explicit `profile` on every call, 404 hides, 400 and 500 detail kept, a lost answer never retried.
- [ ] 1.4 Add Widgetbook use cases first (component-catalog skill): `CuratorSection` (loading, never run, ran, paused, off, offline), `CuratorRunConfirmation` (both wordings, Cancel default, large text), `CuratorRunProgress` (running, finished, failed, lost answer). Phone and desktop, light and dark.
- [ ] 1.4a Write failing controller tests (pause rollback on lost answer, one run at a time, poll until `running` false, profile switch), then `CuratorController`.
- [ ] 1.5 Wire the section into `SkillsScreen`; add the spans, log event and breadcrumbs from the proposal with tests that none holds a name or line.
- [ ] 1.6 Add the strings to `app_en.arb` and `app_de.arb` (skills area), run `flutter gen-l10n`.
- [ ] 1.7 Add a workflow test (`test/workflows/`) for pause, then a confirmed run, and look at the screenshots.
- [ ] 1.8 Extend `test/real_backend_contract_test.dart` (skips without `HERMES_DEV_URL`): status shape, pause round trip, one run on a throwaway home.
- [ ] 1.9 Update `docs/architecture/` (skills section in settings-screens.md) and `docs/roadmap.md` item 4.8 in the PR; run `/simplify`, `dart format`, `flutter analyze`, `flutter test`.

## Not verified

- Run against a live backend: nothing here was executed, only read from source at `d923a5eb`.
- The exact lines `hermes curator run` prints, beyond the `print` calls in `hermes_cli/curator.py::_cmd_run`.
- The shape of `curator.consolidate` in `GET /api/config`; the code must fall back to the "unknown" wording.
- That an unknown profile on the GET and PUT answers 404 (read in `_resolve_profile_dir`, not run).
