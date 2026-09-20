## 1. Models and repository

- [ ] 1.1 Write failing tests in `test/hermes_plugin_manager_repository_test.dart` for `loadProviders()`: a full `providers` object (memory provider in use, options with status, description and setup, context engine in use and options); options without a name skipped; status `ready`, `needs_config` and anything else; missing or malformed fields defaulted; a body without a `providers` object read as built-in with no options; 404 reported as `PluginsUnsupported`
- [ ] 1.2 Add `lib/src/plugins/provider_settings.dart` (`ProviderSettings`, `MemoryProviderOption`, `ProviderStatus`, `ExternalDependency`, `ContextEngineOption`) and `loadProviders()` to the repository, until 1.1 passes
- [ ] 1.3 Write failing tests for `saveProviders({memoryProvider, contextEngine})`: only the given fields are in the body, an empty string is sent as such, a 400 `detail` becomes the message, other failures give no message
- [ ] 1.4 Add `saveProviders` (returning `PluginActionResult`) to the repository, until 1.3 passes

## 2. Controller

- [ ] 2.1 Write failing tests for `ProvidersController`: first load then settings with the choices set to what the server reports; failure and unsupported states with retry; a failed refresh keeps the settings; `dirty` and the fields to send follow the choices; saving sends only what changed, reloads and clears the draft on success, keeps the draft on refusal; a refresh replaces the draft; the current engine is added when the list lacks it; events `plugins.providers.save.ok` and `.error` with only the changed fields
- [ ] 2.2 Add `lib/src/plugins/providers_controller.dart` until 2.1 passes

## 3. Providers tab

- [ ] 3.1 Write failing widget tests in `test/plugins_providers_screen_test.dart`: three tabs and no provider request until Providers is opened, and not again on returning; progress, failed-with-Retry, unsupported states; Built-in first and selected when the server reports an empty provider; the provider in use selected; status chips; a not-ready provider cannot be selected but the one in use can stay; "What it needs" lists env names, tools with their install command and packages, and says setup is on the server; copying puts only the command on the clipboard; a provider that names nothing says so; the context engine list, the current engine added when missing, and the empty-list note; Save disabled until a choice changes, sends only the changed field (empty string for Built-in), shows the saved text and reloads, shows the server's reason and keeps the choices on refusal, and says "Could not save provider settings" on a network failure; refresh replaces unsaved choices and its failure text
- [ ] 3.2 Add `lib/src/plugins/providers_tab.dart` and the third tab in `plugins_screen.dart`, until 3.1 passes and every earlier plugin test still passes

## 4. Telemetry wiring

- [ ] 4.1 Pass the `AppEventLogger` the screen already reads to the providers controller (its tests are in 2.1) and add a screen-level check that a save reaches the logger

## 5. Backend contract

- [ ] 5.1 Extend `test/real_backend_contract_test.dart`: `loadProviders()` returns the memory options with a status for each and a context engine name; saving the memory provider a server reports as in use, unchanged, is accepted; picking a provider that is not ready is refused with a reason mentioning it is not ready. Do not switch the backend's provider. Run against `scripts/dev-backend.sh`
- [ ] 5.2 Confirm nothing under `openapi/`, `scripts/` or `packages/hermes_api/` changes

## 6. Docs

- [ ] 6.1 Extend the `Plugins` paragraph in `CLAUDE.md` for the third tab; check `.claude/skills/` for anything stale

## 7. Verify

- [ ] 7.1 `dart format .`, `flutter analyze`, `flutter test`
- [ ] 7.2 Render the real provider payload (from the dev backend) in a throwaway widget test at phone and wide widths, compare with the archived mockups, delete the test
- [ ] 7.3 Stage files by name, commit as `feat(plugins): …`, open the PR
