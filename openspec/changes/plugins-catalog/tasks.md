## 1. Catalog model and repository

- [x] 1.1 Write failing tests in `test/hermes_plugin_manager_repository_test.dart` for `loadCatalog()`: a full entry, an entry without a name skipped, missing fields defaulted, `sha_short` falling back to the first seven characters of `sha`, list fields that are not lists of strings read as empty, a body that is not the envelope read as empty, 404 reported as `PluginsUnsupported`
- [x] 1.2 Add `lib/src/plugins/catalog_entry.dart` (`CatalogEntry`, `CatalogTier`) and `loadCatalog()` to the repository, until 1.1 passes
- [x] 1.3 Write failing tests for the installs: a catalog install sends `catalog_name`, an empty `identifier`, `enable` and `force` false; a source install sends the trimmed `identifier`, no `catalog_name`, and `enable` and `force` as given; the success answer's `plugin_name`, `warnings` and `missing_env` are read (non-string items dropped); a 400 `detail` becomes `message`; a 400 without a usable `detail`, a 500 and a network error give no message; a receive timeout is `timedOut` and not an error
- [x] 1.4 Add `PluginInstallResult`, `installFromCatalog` and `installFromSource` to the repository, until 1.3 passes

## 2. Catalog controller

- [x] 2.1 Write failing tests for `CatalogController`: first load then entries; failure and unsupported states with retry; a refresh keeps rows and reports failure; search narrows by name, description and maintainer ignoring case, and clears; selection follows a reload and clears when the entry is gone; an install marks the entry busy, reloads the catalog and calls `onInstalled` on success and on timeout, and does neither on refusal; a second install of a busy entry is ignored
- [x] 2.2 Add `lib/src/plugins/catalog_controller.dart` until 2.1 passes

## 3. Tabs and the catalog list

- [x] 3.1 Write failing widget tests in `test/plugins_catalog_screen_test.dart`: two tabs with Installed selected and no catalog request on open; the request on first opening Catalog and not again on returning; search text and list kept across a tab switch; progress, empty, failed-with-Retry, unsupported states; row content (name, maintainer, two-line description, commit chip, Official tag, Install button, Installed chip, Update available chip); search and "No plugins match"; pull to refresh and its failure text
- [x] 3.2 Move part 1's list into `_InstalledTab`, add the tab row to `plugins_screen.dart`, and add `lib/src/plugins/catalog_tab.dart` with keep-alive pages, until 3.1 passes and every part 1 test still passes

## 4. Entry details

- [x] 4.1 Write failing widget tests: bottom sheet below 900 px and pane at 900 px or wider with a highlighted row; name, tier, maintainer, whole description, commit, `requires_hermes`, platforms; tools, hooks, middleware and env groups shown only when non-empty; docs link opens only for `http` and `https` (inject the launcher); the sheet closes when a reload no longer lists the entry
- [x] 4.2 Add `lib/src/plugins/catalog_detail.dart` and wire it into the tab, until 4.1 passes

## 5. Installing from the catalog

- [x] 5.1 Write failing widget tests: Install from a row and from the details sends the right body; the switch off sends `enable` false; the control shows progress and ignores a second tap; success says "Installed <name>" and reloads both lists; warnings are shown; `missing_env` opens a "Set these on the server" dialog with the names and no value; a refusal shows the server's `detail` and changes nothing; a timeout says the server is still installing and reloads both lists; a network failure says "Could not install this plugin"
- [x] 5.2 Add `lib/src/plugins/install_report.dart` (`reportInstall`) and the install controls, until 5.1 passes

## 6. Installing from a Git URL

- [x] 6.1 Write failing widget tests: the button opens the dialog with the notice visible, the checkbox unticked, the enable switch on, Advanced collapsed with force off, and Install disabled; Install stays disabled with text but no tick and with a tick but blank text; Install sends the trimmed identifier with no `catalog_name`, and `force` true after turning it on; the outcome (warnings, refusal, missing env) is reported as for a catalog install; the dialog closes whatever the outcome; the typed text is in no telemetry event and no snackbar
- [x] 6.2 Add `lib/src/plugins/git_install_dialog.dart` and the button in the Catalog tab, until 6.1 passes

## 7. Telemetry

- [x] 7.1 Write failing tests: `plugins.install.ok` and `plugins.install.error` with only `plugin.name` for a catalog install, `plugins.install.timeout` for a timeout, and `plugins.install_custom.<outcome>` with no attributes for a Git URL install, whose typed text appears nowhere in the events
- [x] 7.2 Log from `CatalogController` through the existing `AppEventLogger`, until 7.1 passes

## 8. Backend contract

- [x] 8.1 Extend `test/real_backend_contract_test.dart`: the catalog loads with entries carrying the fields the spec names (including a known entry's `capabilities` lists and a `tier` of `official` or `community`); installing a name that is not in the catalog is refused with a reason; installing an unusable identifier is refused with a reason. Do not install a real plugin against the backend. Run it against `scripts/dev-backend.sh`
- [x] 8.2 Confirm nothing under `openapi/`, `scripts/` or `packages/hermes_api/` changes in this branch

## 9. Docs

- [x] 9.1 Update the `Plugins` paragraph in `CLAUDE.md` (tabs, catalog, installs, the install timeout note) and check `.claude/skills/` for anything the change makes stale

## 10. Verify

- [x] 10.1 `dart format .`, `flutter analyze`, `flutter test`
- [x] 10.2 Render the real catalog payload (captured from the dev backend) in a throwaway widget test at phone and wide widths, the catalog tab, an entry's details and the Git URL dialog, compare with the archived mockups, and delete the test; the running app cannot be clicked from a session
- [x] 10.3 Stage files by name, commit as `feat(plugins): …`, open the PR
