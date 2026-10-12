## 1. Detail presentation

- [x] 1.1 Confirm existing PluginDetail and CatalogTab catalog cases cover unchanged content. No new visual component or case is needed.
- [x] 1.2 Start with failing compact macOS presentation tests for Installed and Catalog details. Reuse the existing content through the shared adaptive modal helper while preserving mobile sheets and wide panes.
- [x] 1.3 Verify selection cleanup on dismissal, disabled busy actions, and asynchronous install results after dismissal using real generated clients over FakeHermesServer.
- [x] 1.4 No new observability signals, generated API changes, or project skill updates are needed. Existing plugin action telemetry and content handling remain unchanged.

## 2. Verification

- [x] 2.1 Run scoped dart format, flutter analyze, focused plugin tests, and strict OpenSpec validation. Review the shared verify-in-app isolation rules and record native presentation as unverified unless an isolated fixture is available.

Planned change: `fix(plugins): use desktop dialogs for compact Mac details`, under 500 changed lines. Existing details components are reused. The PluginsScreen React counterpart needs a design port for the compact macOS presentation.

Verification evidence: two compact macOS tests failed on the existing BottomSheet presentation before the callers changed; the other ten focused cases passed. After migration, all 12 focused presentation tests and all 74 existing Installed/Catalog tests passed in the isolated checkout. Scoped formatting and focused analysis passed. The shared verify-in-app isolation instructions were reviewed; no native fixture was launched, so native presentation, keyboard interaction, and accessibility remain unverified. Initial macOS catalog test setup was corrected to use MacToolbarTabs before collecting behavioral failure evidence.
