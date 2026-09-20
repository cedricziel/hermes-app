## 1. Hub repository

- [x] 1.1 Failing tests against `FakeHermesServer` for the hub repository: official, sources (featured, installed), search (`timed_out`, `installed`), preview, scan (unknown policy becomes block, findings without a name skipped), install/uninstall/update returning a job name, job status with 404
- [x] 1.2 Implement the hub half of the skills repository over `authController.api!.raw`, with lenient parsing

## 2. Job runner

- [x] 2.1 Failing tests with a fake clock: success on exit code 0, failure on another code, unknown after repeated read failures or 404, ignores a status with a different pid, cap on total time, one job at a time
- [x] 2.2 Implement `SkillJob` (start, poll, log tail, state)

## 3. Hub controller

- [x] 3.1 Failing tests: debounced search that drops stale replies, featured and official when the search is empty, installed markers refresh after a job, install refused without a scan for that identifier, refused on block and unknown policy, `ask` needs confirmation
- [x] 3.2 Implement the hub controller and hook it into the Skills controller so a finished job reloads the installed list

## 4. Discover tab and hub page

- [x] 4.1 Failing widget tests: Discover loading, featured and official cards, search results, source chips, timed-out note with Retry, error with Retry, "not supported" on 404, Installed cards open the installed detail
- [x] 4.2 Implement the Discover tab and add the tab bar to the Skills page
- [x] 4.3 Failing widget tests: hub page shows files and rendered `SKILL.md`, scan verdict and findings, scan failure hides Install, Install button by policy (allow, ask with confirmation listing findings, block with reason)
- [x] 4.4 Implement the hub skill page and the confirmation

## 5. Job sheet, uninstall and update

- [x] 5.1 Failing widget tests: sheet shows log tail and result, closing it keeps the job running with the page indicator, other install actions disabled while running
- [x] 5.2 Implement the sheet and the in-page indicator
- [x] 5.3 Failing tests then implementation: Uninstall on hub skills only with confirmation, and "Check for updates" on the Installed footer shown only when hub skills exist

## 6. Contract, telemetry, docs

- [x] 6.1 Add official, sources, preview and scan shape checks to `test/real_backend_contract_test.dart`. Search, install and uninstall are not run against a real backend: they need the network and change what is installed
- [x] 6.2 Add the `skills.job` app event named in the proposal, with no identifiers, search text or logs; test that a telemetry failure does not break an install
- [x] 6.3 No change needed to `.claude/skills/verify-in-app` or `CLAUDE.md`

## 7. Verify

- [x] 7.1 `dart format .`, `flutter analyze`, `flutter test`
- [x] 7.2 Check the hub routes against the dev backend and render the Discover tab, the hub page and the job sheet to an image; the running app cannot be clicked through to the sidebar
