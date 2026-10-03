# Claude Design sync notes

- The app is Flutter, so Claude Design can't use its widgets directly. `design/web/` (`@hermes-app/ui`) is a
  hand-made React recreation of the theme (`lib/src/theme/hermes_theme.dart`) and key widgets, and the sync
  runs the package shape against it. It drifts from the Flutter code unless someone updates it: a Flutter UI
  change does not reach Claude Design until the matching component in `design/web/src/components/` changes.
- Build: `cd design/web && npm ci && npm run build` (esbuild bundles `src/index.ts` and the CSS each component
  imports into `dist/index.{js,css}`; tsc emits the `.d.ts`). Then from the repo root:
  `node .ds-sync/package-build.mjs --config .design-sync/config.json --node-modules design/web/node_modules --entry design/web/dist/index.js --out ./ds-bundle`.
- Groups come from `design/web/docs/<Name>.md`, which hold only `category` frontmatter. The `.prompt.md` is
  synthesized from the JSDoc and props, so JSDoc on components and props is the design agent's documentation.
- `guidelinesGlob` points at a path that doesn't exist on purpose: the default (`docs/*.md`) would ship the
  category stubs as guidelines.
- Icons are Material Symbols Outlined from Google Fonts (`@import` in `tokens.css`), giving `[FONT_REMOTE]`. The
  font is the system stack (SF on Apple, like the Flutter app); no font files ship.
- Playwright must match the cached chromium build: chromium-1243 -> `playwright@1.63.0` in `.ds-sync/`.
- The worktree's shell guard rejects commands that contain the substring "git" (e.g. `.gitignore`, github URLs)
  in compound commands; use the Edit/Write tools or a node script for those.
- Flutter reference screenshots: `flutter test test/workflows/` writes `build/workflow_screenshots/`; they use
  Roboto (test harness), our previews use the system font.

- Helper exports that are not standalone components (InputCardFrame, InputCardNote, ToolCallStatusIcon,
  AccountFooter, ShellNavigation, ShellSidebar, SidebarAction, SidebarBrand, ThreadActionsButton, KanbanBulkBar)
  are excluded from cards via `componentSrcMap: null`; they stay in the bundle. A new PascalCase export shows up
  as `[DOCS_UNMAPPED]`: give it a `docs/<Name>.md` category stub, or exclude it the same way.
- Almost every card uses `cardMode: "column"`: the real column card is about 840px wide, so full-screen
  previews are sized 800x560 or smaller. Anything wider gets cropped on the right.
- Authoring was done in parallel by agents using a scratch screenshot harness that bundles one preview
  against `design/web/src` without touching `ds-bundle/`. It isn't committed; the converter's
  `package-capture.mjs` is the gate.

## Follow-ups (base components the recreations asked for)

- Switch: ScheduleJobRow and McpServerRow each carry their own Material 3 switch CSS.
- Spinner: ToolCallCard, ConnectScreen and PluginRow each draw their own ring.
- Popup menu: ThreadSidebar, ChatHeader and KanbanToolbar each style their own menu.
- Chip is 32px; Flutter's filter chips are about 38px. Pill-shaped tags (MCP, plugins) live in their rows' CSS.
- Tokens asked for: `--h-radius-row` (8px sidebar rows), `--h-on-secondary`, a subtle text shade darker
  than `--h-muted` (`--h-secondary` is used for it), a warning-tinted card.

## Known gaps in the recreations

- Markdown in AssistantMessage: no tables, blockquotes, nested lists or syntax highlighting.
- ToolCallCard shows JSON input as pretty-printed text, not the app's collapsible tree.
- Not recreated: thread rename/delete dialogs, the "Always allow" confirmation, UnsupportedRequestCard, the
  Kanban phone drop strip and the task panel's edit/assign/priority dialogs (callback props only).

## Re-sync risks

- Everything here is a hand copy of Flutter UI. Check `git log lib/src/theme lib/src/chat/widgets
lib/src/kanban/widgets lib/src/shell lib/src/screens lib/src/mcp lib/src/plugins lib/src/schedules` since the
  last sync and update the matching components before re-syncing, or Claude Design keeps the old look.
- Preview content is static fixture data written for the previews, not loaded from `widgetbook/fixtures.dart`.
- Fonts are not shipped: the system font stack and Material Symbols come from the viewer's OS and Google Fonts.

## Known render warns

- KanbanTaskPanel's tall cells (Running, RunsOpen, Dark) are cut at the review sheet's cell height. The
  component is fine (the panel scrolls in the app); graded good with that noted.

- `[FONT_REMOTE]` for "SF Pro Text", "Roboto Mono", "Material Symbols Outlined": expected (system fonts and the
  Google Fonts icon import).
