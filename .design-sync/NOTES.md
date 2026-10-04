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
  In a claude.ai/code cloud container the browsers live in `/opt/pw-browsers` (chromium-1194), which needs
  `playwright@1.56.1` instead; check `ls /opt/pw-browsers ~/.cache/ms-playwright` before installing.
- Cloud containers can't reach Google Fonts, so captured sheets show Material Symbols as ligature text
  ("chat_bubble" etc.). That's the sandbox, not the preview: grade layout and tokens, and say so in the grade note.
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

## Apple platform look (HIG audit, Flutter PRs #367 to #386)

- Components that differ on iOS and macOS take `platform: "apple" | "material"`, default `material`, also set for a
  whole subtree by `HermesProvider platform` (a nested provider without `platform` keeps its parent's). A component's
  own `platform` prop reaches everything it renders (`PlatformScope`). `layout="phone" | "desktop"` where touch and
  Mac differ again; a full-screen iPad is `layout="desktop"` with `device="touch"` on `AppShell`, which its sidebar and
  header inherit. The hooks and the shared types live in `design/web/src/platform.ts`; shared Apple CSS (toggle,
  spinner, traffic lights) in `src/styles/apple.css`. Platform CSS hangs off the component's own classes (spinners
  carry `h-apple-spinner`), never `[data-hermes-platform] .x` ancestor selectors, which leak across nested providers;
  the type ramp travels as inherited `--h-ramp-*` properties for the same reason. Previews show both looks side by
  side (`PlatformCompare`, `Apple*` stories).
- Shared on all platforms: light-mode `--h-success` #166534, `--h-warning` #92400e, `--h-muted` #6b6b74 (4.5:1);
  Kanban muted text uses `--h-muted-alpha` 0.7; busy bars (Kanban card, task panel) are static under
  `prefers-reduced-motion`, and so is the Apple spinner; chat column max 680px.
- Apple icon approach: the app ships CupertinoIcons, which are not available here. `Icon` under apple uses Material
  Symbols Rounded at weight 300 (second Google Fonts `@import` in `tokens.css`, another `[FONT_REMOTE]`) and a small
  name swap table (`more_vert` to the horizontal ellipsis, `arrow_back` to a chevron, `send` to an up arrow, ...). It
  is an approximation, not SF Symbols: shapes differ, and nothing was drawn as inline SVG.
- Not recreated: the Apple alert dialog and date pickers (the recreation has no dialogs), swipe actions and long-press
  action sheets (touch thread rows keep a 44px "..." and the profile row its tune button, so every action stays
  reachable; right-click also opens a thread row's menu), the sheet's detent gestures, status bar and home
  indicator safe areas, `Button` 44px (iOS) and 28px (Mac) heights, translucent bar blur (the Mac sidebar uses a
  slightly see-through fill), window dragging. The Mac sidebar's resize handle is a `sidebarWidth` prop.
- Flutter PR #376 drops the inline "..." on touch rows in favour of swipe and long press; the recreation keeps the
  button because it has neither gesture.

## Follow-ups (base components the recreations asked for)

- Switch: ScheduleJobRow and McpServerRow each carry their own Material 3 switch CSS.
- Spinner: ToolCallCard, ConnectScreen and PluginRow each draw their own ring.
- Popup menu: ThreadSidebar, ChatHeader and KanbanToolbar each style their own menu.
- Chip is 32px; Flutter's filter chips are about 38px. Pill-shaped tags (MCP, plugins) live in their rows' CSS.
- Tokens asked for: `--h-radius-row` (8px sidebar rows), `--h-on-secondary`, a subtle text shade darker
  than `--h-muted` (`--h-secondary` is used for it), a warning-tinted card.
- Branch `design-sync/apple-chrome` (unmerged, written before #387 landed) has pieces #387 lacks, to port onto
  its `apple` / `material` model: the real CupertinoIcons font (MIT, from the `cupertino_icons` package) with a
  generator that maps `lib/src/theme/app_icons.dart` (`design/web/scripts/gen-cupertino-icons.mjs`) instead of
  the Material Symbols Rounded approximation; shared `Switch`, `Spinner`, `SegmentedControl` and `Menu`
  components that cover the three items above; `SwipeActions` and `ActionSheet` for the iOS swipe and
  long-press row actions, which today are only a visible "…" button.
- Every app screen should have a story in both catalogs: a Widgetbook use case per Flutter screen, then a
  screen-sized component and preview here built from the existing components. Today only ConnectScreen,
  AppShell and the list/detail layout are screen-sized.
- Before a re-sync or a port, check `gh pr list` for open PRs touching `design/web/` or `.design-sync/`
  (#387 was once ported twice in parallel).

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
- Fonts are not shipped: the system font stack and Material Symbols (Outlined and Rounded) come from the viewer's OS
  and Google Fonts.
- Also check `lib/src/theme` (platform_chrome, type_scale, app_icons, breakpoints), `lib/src/widgets/adaptive_*` and
  `row_actions.dart` for new Apple rules; each needs a `platform` branch in the matching component.

## Known render warns

- KanbanTaskPanel's tall cells (Running, RunsOpen, Dark) are cut at the review sheet's cell height. The
  component is fine (the panel scrolls in the app); graded good with that noted.

- `[FONT_REMOTE]` for "SF Pro Text", "Roboto Mono", "Material Symbols Outlined": expected (system fonts and the
  Google Fonts icon import).
