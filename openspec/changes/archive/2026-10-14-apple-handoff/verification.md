# Apple Handoff verification

Verified on 2026-10-05:

- Activity, coordinator, connection-flow, exact-profile restoration, and gateway regression tests pass. The final restoration/coordinator/gateway run passed 169 tests.
- `flutter analyze --no-pub` reports no issues. Formatting and `openspec validate apple-handoff --strict` pass.
- The macOS Debug build and iOS Debug simulator build pass. The macOS Runner tests pass, including startup inbox replacement, unrelated activities, and native failure retention.
- Widgetbook passed 1,852 cases across themes and widths. Workflow screenshots cover connection and retry controls.
- The initial full Flutter run had two timing-sensitive failures while native builds were running. Both pass independently. Two subsequent full runs without build contention passed all 5,129 tests with 99 skipped, including a run after integrating the latest main branch. Analysis of that combined branch reports no issues, and nine script tests pass.
- GitHub catalog and watch-core checks passed. The required Ubuntu checks and backend contract job failed before executing any steps because no hosted runner acquired them; retries remained queued. The maintainer requested merge and will perform physical-device checks after the next release. The OpenSpec change remains active.
- The macOS app opened an invented saved chat and displayed its `default` profile and history against the isolated dashboard on port 63300. Task-owned app and backend processes were stopped afterward.
- Four existing real-backend history/profile contract checks passed against Hermes 0.21.4, revision `35fdb4608aa8af455d2597664cff1754a3722cd1`. This is the tested replacement for the repository's pinned compatibility baseline; backend APIs and generated client files are unchanged.
- Payloads contain only dashboard URL, profile, thread ID, and version. No new telemetry, credential storage, or persisted continuation target was added.

Still outstanding: two-way physical-device Handoff delivery with matching signing teams, including cold/warm launch, authentication, lock, profile collisions, dashboard mismatch, missing chats, reconnect, and active replies. Simulator compilation and channel tests do not prove cross-device delivery. The iOS Debug target currently uses the release bundle identifier, so testing requires an isolated installation with valid signing. Task 4.3 remains unchecked.
