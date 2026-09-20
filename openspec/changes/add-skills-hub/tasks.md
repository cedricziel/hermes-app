## 1. Hub repository

- [ ] 1.1 Failing tests against `FakeHermesServer` for the hub repository: official, sources (featured, installed), search (`timed_out`, `installed`), preview, scan (unknown policy becomes block, findings without a name skipped), install/uninstall/update returning a job name, job status with 404
- [ ] 1.2 Implement the hub half of the skills repository over `authController.api!.raw`, with lenient parsing

## 2. Job runner

- [ ] 2.1 Failing tests with a fake clock: success on exit code 0, failure on another code, unknown after repeated read failures or 404, ignores a status with a different pid, cap on total time, one job at a time
- [ ] 2.2 Implement `SkillJob` (start, poll, log tail, state)

## 3. Hub controller

- [ ] 3.1 Failing tests: debounced search that drops stale replies, featured and official when the search is empty, installed markers refresh after a job, install refused without a scan for that identifier, refused on block and unknown policy, `ask` needs confirmation
- [ ] 3.2 Implement the hub controller and hook it into the Skills controller so a finished job reloads the installed list

## 4. Discover tab and hub page

- [ ] 4.1 Failing widget tests: Discover loading, featured and official cards, search results, source chips, timed-out note with Retry, error with Retry, "not supported" on 404, Installed cards open the installed detail
- [ ] 4.2 Implement the Discover tab and add the tab bar to the Skills page
- [ ] 4.3 Failing widget tests: hub page shows files and rendered `SKILL.md`, scan verdict and findings, scan failure hides Install, Install button by policy (allow, ask with confirmation listing findings, block with reason)
- [ ] 4.4 Implement the hub skill page and the confirmation

## 5. Job sheet, uninstall and update

- [ ] 5.1 Failing widget tests: sheet shows log tail and result, closing it keeps the job running with the page indicator, other install actions disabled while running
- [ ] 5.2 Implement the sheet and the in-page indicator
- [ ] 5.3 Failing tests then implementation: Uninstall on hub skills only with confirmation, and "Check for updates" on the Installed footer shown only when hub skills exist

## 6. Contract, telemetry, docs

- [ ] 6.1 Add search, official, sources, preview, scan and action-status shape checks to `test/real_backend_contract_test.dart`; install and uninstall against the dev backend behind an env flag like the other side-effecting tests, since they need network
- [ ] 6.2 Add the spans named in the proposal using `safely`, with no identifiers, search text or logs; test that a telemetry failure does not break an install
- [ ] 6.3 Update `.claude/skills/verify-in-app` and `CLAUDE.md` if they name the sidebar pages or the dev backend flags

## 7. Verify

- [ ] 7.1 `dart format .`, `flutter analyze`, `flutter test`
- [ ] 7.2 verify-in-app against the dev backend: search, preview with scan, install an allowed skill, see a blocked or ask skill behave, uninstall, update, on a wide and a narrow window
