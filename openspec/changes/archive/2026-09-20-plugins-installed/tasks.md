## 1. Repository and models

- [x] 1.1 Write failing tests in `test/hermes_plugin_manager_repository_test.dart` (against `FakeHermesServer`) for reading `GET /api/dashboard/plugins/hub`: full row, row without a name skipped, missing fields defaulted, unknown or missing `runtime_status` read as inactive, non-object body read as no plugins, `path` not exposed on the model, 404 reported as "not supported"
- [x] 1.2 Add `lib/src/plugins/installed_plugin.dart` (`InstalledPlugin`, `PluginStatus`) and `lib/src/plugins/hermes_plugin_manager_repository.dart` with `load()` over `getPluginsHubApiDashboardPluginsHubGet`, until 1.1 passes
- [x] 1.3 Write failing tests for the five writes: enable, disable, update (with and without `unchanged`), remove, hide (body `{"hidden": true|false}`); a 400 with `detail` gives that message; a 400 without `detail`, a 500 and a network error give none; a plugin name with a space and `#` reaches the right route; a nested name containing `/` (design, open question) either reaches the right route or the test documents the encoding the server needs
- [x] 1.4 Add the write methods and `PluginActionResult` to the repository, until 1.3 passes; resolve the nested-name question here and update the design's open question with the answer

## 2. Controller

- [x] 2.1 Write failing tests for `PluginsController`: first load shows loading then rows; pull-to-refresh keeps rows while running; refresh failure after a load keeps rows and reports "Could not refresh plugins"; first-load failure reports "Could not load plugins"; 404 reports unsupported; a write marks the plugin busy, reloads on success and leaves the list untouched on refusal; the selected plugin disappearing clears the selection
- [x] 2.2 Add `lib/src/plugins/plugins_controller.dart` until 2.1 passes

## 3. Screen and details

- [x] 3.1 Write failing widget tests in `test/plugins_screen_test.dart` (pattern of `profiles_screen_test.dart`, helpers from `test/support/`): progress then rows, empty text, Retry after a failed first load, unsupported text with no Retry, row chips and tags (Enabled, Disabled, Inactive, Bundled, Needs login, Removed with reason), rows in server order
- [x] 3.2 Add `lib/src/plugins/plugins_screen.dart` (list, pull-to-refresh, states) until 3.1 passes
- [x] 3.3 Write failing widget tests for the details: bottom sheet below 900 px and side pane with a highlighted row at 900 px or wider; switch reflects status and sends enable or disable; refusal shows the server's `detail` and leaves the switch; Update only when `can_update_git` and its three outcomes (updated, already up to date, refused); Remove only when `can_remove`, confirm dialog names the plugin, cancel sends nothing, confirm closes the details; hide switch sends `hidden`; login block shows and copies `auth_command` to the clipboard, no copy button without a command, absent when `auth_required` is false; details close when the plugin disappears from a reload
- [x] 3.4 Add `lib/src/plugins/plugin_detail.dart` and wire it into the screen until 3.3 passes

## 4. Entry point

- [x] 4.1 Write failing tests: the sidebar shows a Plugins row after Profiles and Bots when the chat has a dashboard connection, opens the screen, and is absent in the demo chat
- [x] 4.2 Add the row to `thread_sidebar.dart` (`onOpenPlugins`), `_openPlugins` and the repository to `chat_screen.dart`, until 4.1 passes

## 5. Telemetry

- [x] 5.1 Write failing tests that a recording `AppEventLogger` gets `plugins.<action>.<outcome>` with only `plugin.name` for each of enable, disable, update (`ok`, `unchanged`, `error`), remove and hide, and that a refusal body is never in the attributes
- [x] 5.2 Add `Provider<AppEventLogger>.value(telemetry.events())` in `lib/main.dart`; read it in the screen with `noopAppEventLogger` as fallback and log from the controller's write path, until 5.1 passes

## 6. Backend contract

- [x] 6.1 Extend `test/real_backend_contract_test.dart` (skips without `HERMES_DEV_URL`): the hub returns a `plugins` list whose rows carry the fields the spec names with the expected types and bundled rows cannot be removed; a disable then enable round trip on a bundled plugin shows the new `runtime_status` on the next hub read (this also confirms the state is not served stale); the visibility call round-trips `user_hidden`; an unknown and a nested name are refused with the server's reason; run it against `scripts/dev-backend.sh`
- [x] 6.2 No OpenAPI change is needed: all six routes are already in `openapi/hermes-agent.openapi.json` and the generated client. Confirm nothing under `openapi/`, `scripts/` or `packages/hermes_api/` changes in this branch

## 7. Docs and skills

- [x] 7.1 Mention the Plugins screen in the Architecture section of `CLAUDE.md` next to the Profiles and Bots screens (one sentence), and check `.claude/skills/verify-in-app/SKILL.md` and `store-screenshots/SKILL.md` for anything the new sidebar row makes stale (the drawer screenshot gains a row; retake only if the skill says the drawer is captured)
- [x] 7.2 Copy `mockups/plugins.html` from this change folder into the PR description as a reference, not into `lib/`

## 8. Verify

- [x] 8.1 `dart format .`, `flutter analyze`, `flutter test`
- [x] 8.2 Check the screen against a real backend: the contract tests ran against `scripts/dev-backend.sh` (Hermes 0.21.1), and the real hub payload was rendered in a throwaway widget test at phone width (list, sheet, dark) and wide width, then compared with the mockups. The running app was not driven: the Plugins screen sits behind a sidebar tap and the session cannot click
- [x] 8.3 Stage files by name (building the macOS app rewrites tracked `ios/` and `macos/` files: `git restore` those), commit as `feat(plugins): …`, one commit per group above where it stands alone
