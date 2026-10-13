## 1. Catalog installation presentation

- [x] 1.1 Reuse existing catalog and installation panel cases. No new visual component or catalog case is required; record the React McpCatalogScreen design-port follow-up.
- [x] 1.2 Start with a failing compact macOS route test, then use the shared adaptive modal helper without changing mobile options or existing panel callbacks.
- [x] 1.3 Verify mobile and wide presentations, dismissal, successful/refused installations, pending completion, and local server-build polling cleanup through real generated clients over FakeHermesServer.
- [x] 1.4 No new observability signals, generated API changes, or project skill updates are required. Existing credential and telemetry behavior remains unchanged.

## 2. Verification

- [x] 2.1 Run scoped dart format, flutter analyze, focused and relevant existing MCP tests, and strict OpenSpec validation. Review verify-in-app isolation requirements and record native presentation as unverified unless an isolated fixture is available.

Planned change: `fix(mcp): use desktop dialogs for compact catalog details`, under 500 changed lines. Publication planning must say "needs a design port" for the React McpCatalogScreen counterpart.

Verification evidence: the compact macOS route test failed on the existing BottomSheet presentation while the other seven focused cases passed, after correcting test dismissal timing and its installed-row caption finder. The minimal helper migration then passed all eight focused tests and all 62 existing MCP catalog/install tests. Scoped formatting and focused analysis passed. Existing filter-label hit-test warnings remain in the unchanged catalog test file; they were not suppressed. No native or real-backend fixture was launched. The shared verify-in-app isolation instructions were reviewed; native presentation, keyboard interaction, accessibility, and persistent platform storage remain unverified.
