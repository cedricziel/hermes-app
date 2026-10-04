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
- Icons are Material Symbols Outlined from Google Fonts (`@import` in `tokens.css`), giving `[FONT_REMOTE]`, and,
  under `platform="apple"`, CupertinoIcons, which ship as a file (`design/web/src/fonts/`, see below). The text
  font is the system stack (SF on Apple, like the Flutter app).
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
  AccountFooter, ShellNavigation, ShellSidebar, SidebarAction, SidebarBrand, ThreadActionsButton, KanbanBulkBar,
  MenuAnchor, MacToolbarButton, MacToolbarSeparator, MacToolbarSearchField)
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
  header inherit. The hooks and the shared types live in `design/web/src/platform.ts` (`useRowDevice` resolves a
  list row's device, falling back to touch); `src/styles/apple.css` holds only the traffic lights. Platform CSS
  hangs off the component's own classes (`h-switch--apple`, `h-menu--ios`), never `[data-hermes-platform] .x`
  ancestor selectors, which leak across nested providers;
  the type ramp travels as inherited `--h-ramp-*` properties for the same reason. Previews show both looks side by
  side (`PlatformCompare`, `Apple*` stories).
- Shared on all platforms: light-mode `--h-success` #166534, `--h-warning` #92400e, `--h-muted` #6b6b74 (4.5:1);
  Kanban muted text uses `--h-muted-alpha` 0.7; busy bars (Kanban card, task panel) are static under
  `prefers-reduced-motion`, and so are both `Spinner`s; chat column max 680px.
- Shared controls (from the `design-sync/apple-chrome` branch, rebuilt on this model). Components use them
  instead of drawing their own:
  - `Switch`: the Apple 51x31 toggle, or the Material 3 switch. ScheduleJobRow, McpServerRow and the task
    panel's Notify rows use it.
  - `Spinner`: the activity indicator (eight spokes turning a step at a time), or the Material three-quarter ring.
    ToolCallCard, ThinkingIndicator, ConnectScreen, PluginRow, KanbanTaskPanel and the sidebar's "Show more"
    use it.
  - `SegmentedControl`: the sliding control (`AdaptiveTabBar`, the same on iOS and Mac), or Material tabs.
    ListDetailLayout's `tabs` draw one.
  - `Menu`: the iOS pull-down on touch, the Mac menu (22px rows, `shortcut`s, as `MacMenuRow` from #391), or
    the Material popup. `MenuAnchor` + `align` places it under its button. The sidebar, chat header, Kanban
    toolbar and task panel menus use it. Mac thread menus list the app's `macThreadMenuItems` (Rename…, Pin
    ⇧⌘P, Copy Transcript, Archive, Delete… ⌘⌫), without "Open in New Window".
  - `SwipeActions` and `ActionSheet`: the iOS row swipe (trailing destructive actions in system red over 30% of
    the row, a chat's leading Pin in orange) and the long-press sheet, both Apple touch only. They are static
    preview states: `swipeRevealed`/`actionSheetOpen` on ScheduleJobRow, McpServerRow and PluginRow (through
    the internal `RowActions`, mirroring `row_actions.dart`), `swipedThreadId`/`swipeSide`/`actionSheetThreadId`
    on ThreadSidebar. The sheet is an overlay over the nearest positioned ancestor, drawn after the row. A row
    in an inset group (ScheduleJobRow) hands its inset and corners to the swipe wrapper so the red action is
    clipped with the group.
  - Tokens `--h-apple-red`, `--h-apple-orange` and `--h-apple-elevated` (the sheet's Cancel) carry the Apple
    system colors per theme.
- Apple icons are the app's own: the CupertinoIcons font from the `cupertino_icons` package (MIT; the ttf and its
  LICENSE are copied into `design/web/src/fonts/` from `~/.pub-cache/hosted/pub.dev/cupertino_icons-<locked
version>/`), shipped through `extraFonts` in `config.json` (the converter writes `fonts/fonts.css` and imports
  it from `styles.css`). `Icon` maps a Material name to its glyph with `src/components/Icon/cupertinoIcons.ts`,
  generated by `node design/web/scripts/gen-cupertino-icons.mjs` from the `AppIconSet(Icons.x,
CupertinoIcons.y)` pairs in `lib/src/theme/app_icons.dart` and the Flutter SDK's codepoints (`which flutter`
  -> `packages/flutter/lib/src/cupertino/icons.dart`). Rerun it when `app_icons.dart` changes; it prints the sets
  it skipped (`toggleOn`/`toggleOff` are Material on both sides). A small hand table in `Icon.tsx`
  (`flutterNames`) maps Material Symbols names the app spells differently (`warning` -> `warning_amber`, `draft`
  -> `insert_drive_file`, `left_panel_*` -> `view_sidebar`, `person_add` -> `person_add_alt`). Unpaired names keep
  the Material glyph, as the app does. `apple="back"` (iOS back chevron) and `apple="checkmark"` (menu check) name
  glyphs outside AppIcons; `apple={false}` marks spots the app draws in Material everywhere (code block header,
  ExpansionTile chevrons in ToolCallCard and the task panel's Runs/History, the Mac back button).
- Not recreated: the Apple alert dialog and date pickers (the recreation has no dialogs), the swipe and long-press
  gestures themselves (only their static states; the profile row keeps its tune button), the Mac right-click
  menu of schedule, MCP and plugin rows, the sheet's detent gestures, status bar and home
  indicator safe areas, `Button` 44px (iOS) and 28px (Mac) heights, translucent bar blur (the Mac sidebar uses a
  slightly see-through fill), window dragging. The Mac sidebar's resize handle is a `sidebarWidth` prop.
- As in Flutter PR #376, touch thread rows have no inline "..."; their actions are the swipes and the long-press
  sheet. Mac and Material rows keep it.
- Shared form and list parts: `FormSection` (Layout; Flutter has no widget, it is the heading/fields/helper rhythm of the job, Kanban task and blueprint forms, and `DisclosureTile` for "Advanced"), `SelectField` (Controls; `DropdownButtonFormField` and the job form's model `InputDecorator`, Material on every platform as in the app, its menu follows the platform) and `ListRow` (Lists; Material `ListTile`, an inset grouped row on Apple with a muted disclosure chevron).

- `MacToolbar` is the app's Mac unified toolbar (#399, #396, #401): title over subtitle, 28px
  `MacToolbarButton`s, `MacToolbarSeparator`, `MacToolbarSearchField`, and the traffic-light clearance with the
  show-sidebar button while the sidebar is hidden. Pages on a Mac use it instead of their Material bar. The
  inspector toggle draws `sidebar_left`, since its Material name (`view_sidebar_outlined`) is shared with the
  sidebar toggle; the app draws `sidebar_right`.

## Follow-ups (base components the recreations asked for)

- Chip is 32px; Flutter's filter chips are about 38px. Pill-shaped tags (MCP, plugins) live in their rows' CSS.
- Tokens asked for: `--h-radius-row` (8px sidebar rows), `--h-on-secondary`, a subtle text shade darker
  than `--h-muted` (`--h-secondary` is used for it), a warning-tinted card.
- The Mac sidebar is the source list of Flutter #391: `ShellNavigation` draws 28px rows (Kanban captioned "All
  profiles"), `ThreadSidebar` sorts chats into Pinned / Today / Previous 7 days / Previous 30 days / Older from
  `ThreadItem.updatedAt` counted back from `now`, with folding headers (`defaultFoldedSections`), hover Archive and
  More (`hoveredThreadId`) and "Open in New Window" in the menu (`canOpenInNewWindow`). The sidebar's search field
  is not recreated.
- The Kanban toolbar and task panel menus have no outside-click or Escape dismissal (ThreadSidebar's
  `useDismiss` is private); export it next to `Menu` if a screen needs it.
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
- Only CupertinoIcons ships as a font file; the system font stack and Material Symbols Outlined come from the
  viewer's OS and Google Fonts. A new `cupertino_icons` version in `pubspec.lock` means copying its ttf again.
- Also check `lib/src/theme` (platform_chrome, type_scale, app_icons, breakpoints), `lib/src/widgets/adaptive_*` and
  `row_actions.dart` for new Apple rules; each needs a `platform` branch in the matching component.

## Known render warns

- KanbanTaskPanel's tall cells (Running, RunsOpen, Dark) are cut at the review sheet's cell height. The
  component is fine (the panel scrolls in the app); graded good with that noted.

- `[FONT_REMOTE]` for "SF Pro Text", "Roboto Mono", "Material Symbols Outlined": expected (system fonts and the
  Google Fonts icon import).
