# Tasks

One PR, `feat(memory): add learning settings, provider and reset to Memory`, about 500 changed lines with tests. Builds on `memory-overview`.

## 1. Data

- [x] 1.1 Record the config keys and defaults, the `GET /api/memory` answer and the `POST /api/memory/reset` answer from Hermes `71d34bad` as fixtures in `test/memory/`, with the revision noted (Hermes `d923a5eb`, the pinned `openapi/HERMES_REF`).
- [x] 1.2 Write failing settings-repository tests against `FakeHermesServer`: the five keys are read leniently with their defaults; a write sends `PUT /api/config?profile=` with only the changed leaf and the profile; a refusal and a transport failure are told apart. Then implement it on `getConfigApiConfigGet` and `updateConfigApiConfigPut`.
- [x] 1.3 Write failing tests for the provider status: `active: ""` is built-in; a named provider takes its name and description; `missing`, `needs_config` and `unavailable` are reported; a malformed answer is unreadable. Then implement it on `getMemoryStatusApiMemoryGet`.
- [x] 1.4 Write failing reset tests: each target sends its body and the explicit profile; `ok: true` is success; a refusal carries `detail`; a lost answer is uncertain and is never resent. Then implement it on `resetMemoryApiMemoryResetPost`.
- [x] 1.5 Write failing controller tests: optimistic change, revert to the last confirmed value on failure with the banner text, one write per key in flight with the latest value sent after it, unknown values kept as a choice, entries and settings read again after a reset, state cleared on sign-out and profile change. Then implement it.

## 2. Widgets

- [x] 2.1 Add Widgetbook use cases for `MemoryLearningSection` (defaults, all off, unknown interval, a write failed, config unreadable), `MemoryStorageSection` (built-in, named provider, missing provider banner, needs setup, read failed) and the reset alert, in both themes at phone and desktop width. Build them as plain-model widgets in `lib/src/memory/widgets/`.
- [x] 2.2 Write failing widget tests for the labels, value texts, caption, banner and the alert's actions and footnote. Then make them pass.

## 3. Screen

- [x] 3.1 Write a failing `PluginsScreen` test: opened with the Providers tab as initial tab, Providers is selected and the catalog is not requested; the default still opens on Installed. Then add the parameter.
- [x] 3.2 Write a failing `MemoryScreen` test: the sections are shown for the screen's profile, a switch round-trips, the provider row opens Plugins on Providers for that profile, Reset both asks, sends one request and re-reads. Then wire the sections and the alert into `MemoryScreen`.
- [x] 3.3 Write a failing test that the spans `memory.settings.fetch`, `memory.settings.write`, `memory.status.fetch` and `memory.reset`, the logs `memory.setting_changed` and `memory.reset_outcome`, and the breadcrumbs `memory.setting_toggled` and `memory.reset_confirmed` carry only their fixed attributes. Then add them.
- [x] 3.4 Update `CLAUDE.md`'s description of the Memory screen and Plugins (initial tab), and the `verify-in-app` skill if resetting the dev backend's memory needs a note.

## 4. Verify

- [x] 4.1 Run `/simplify` on the diff.
- [x] 4.2 Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze` and `flutter test`, all passing.
- [x] 4.3 (macOS, Hermes `d923a5eb`, 2026-10-24: each switch and value row wrote only `memory.user_profile_enabled`, `memory.write_approval`, `memory.nudge_interval` or `display.memory_notifications` in the default profile's `config.yaml`, the work profile's stayed unchanged; turning Ask before saving off made the next write in the already open chat save directly; Built-in opened Plugins on Providers; Reset about you deleted only the default `USER.md`) Use `verify-in-app` against `scripts/dev-backend.sh` with two profiles: each switch changes only its key in that profile's `config.yaml`, "Ask before saving" takes effect in an open chat, the provider row shows Built-in and opens Providers, and Reset about you deletes only that profile's USER.md.
