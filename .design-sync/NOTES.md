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
- `AlertDialog` (Surfaces) is the app's `AppAlertDialog`/`showConfirmDialog`: the Cupertino alert on Apple (270px, 14px
  corners, `--h-apple-scrim` barrier, `--h-apple-separator` hairlines, default bold, destructive red) and an M3 alert
  on Material (a `Sheet` dialog with `fitContent`). `Sheet` and `AlertDialog` share focus handling (`src/modalFocus.ts`).
- Not recreated: the date pickers (`Sheet` draws the Material bottom sheet and dialog only), the swipe and long-press
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

- Chip is 32px; Flutter's filter chips are about 38px. Since the clean restyle no settings row draws `Tag`s; status reads as muted text, a caption or a warning line.
- Tokens asked for: `--h-radius-row` (8px sidebar rows), `--h-on-secondary`, a subtle text shade darker
  than `--h-muted` (`--h-secondary` is used for it), a warning-tinted card.
- The Mac sidebar is the source list of Flutter #391: `ShellNavigation` draws 28px rows (Kanban captioned "All
  profiles"), `ThreadSidebar` sorts chats into Pinned / Today / Previous 7 days / Previous 30 days / Older from
  `ThreadItem.updatedAt` counted back from `now`, with folding headers (`defaultFoldedSections`), hover Archive and
  More (`hoveredThreadId`) and "Open in New Window" in the menu (`canOpenInNewWindow`). As in #399, New Chat and
  search are in the chat's `MacToolbar` (`ChatHeader` on a Mac), not the sidebar.
- The Mac main window (#399, #402, #434), as preview state: `ThreadSidebar search` (`ThreadSidebarSearch`: query,
  scope, status, hits with `>>>`/`<<<` marked snippets, recent) shows the Mac search results (internal
  `SidebarSearch.tsx`) or, on touch and Material, the "Search chats" field and its hits; `grouping="folder"`
  sorts by `ThreadItem.folderPath` on every platform, and since #434 Apple touch lists recency sections too while
  Material puts a "Chats" heading over its flat list, each with the "Group by" menu on the first header
  (`SectionedThreadList` in `MacSourceList.tsx`). `ShellNavigation profiles` draws the profile switcher and
  `AccountFooter` becomes the Mac account footer (internal `MacAccount.tsx`); the Settings list `AppShell
  settingsOpen` shows is the public `SettingsDialog` (`AppShell`/`ChatScreen` take `settingsValues`, and `ChatScreen`
  forwards `onDismissSettings`); the Mac sidebar has no "More". `AppShell compact` + `sidebarOverlayOpen` is the
  compact window (sidebar over the page, `ShellChrome.closeOverlay`), and `ChatHeader` reads `compact` from it.
  `ShellDestination` gained `bots` and `profiles` (`MacProfilesPage` in the shell). `Menu` items gained `heading`
  and `detail`.
- Mac follow-ups #444 and #445: Sign Out asks first (`AppShell`/`ChatScreen` `signOutConfirmOpen`, the internal
  `SignOutAlert` in `MacAccount.tsx`, an Apple `AlertDialog`); `MacProfilesPage` counts every section per profile,
  Messaging (#445) and Plugins (#497) included (`OtherProfile` cell); a chat opened in its own window leaves the main window
  (welcome view, empty composer) and its draft moves to `ConversationWindowScreen`'s composer (`CarriedOverDraft`
  cell). The Hermes menu's Connection Details and Sign Out… are native menu bar items with no card.
- The Kanban toolbar and task panel menus have no outside-click or Escape dismissal (ThreadSidebar's
  `useDismiss` is private); export it next to `Menu` if a screen needs it.
- Every app screen should have a story in both catalogs: a Widgetbook use case per Flutter screen, then a
  screen-sized component and preview here built from the existing components. The Kanban and Schedules
  screens have theirs (see above).
- Before a re-sync or a port, check `gh pr list` for open PRs touching `design/web/` or `.design-sync/`
  (#387 was once ported twice in parallel).

## Screen cards (chat and onboarding)

- `ChatScreen`: AppShell + ThreadSidebar + ChatHeader + `ChatThread` (or WelcomeView) + ChatComposer, on phone and
  desktop, Apple (iPhone, Mac window, iPad via `device`) and Material; `state` covers loading and failed, which
  drop the sidebar as the app does. `ChatThread` (Chat group) draws a chat's turns from plain `ChatTurn` data,
  anchored to the latest turn. Gaps: the loading phone bar shows the "Hermes" title and info button (the app's
  has only the menu button); no clarify answer, attachment drop or queued-prompt cells.
- `ConversationWindowScreen`: the Mac conversation window of #398 (`lib/src/windows/`), one chat with no sidebar.
  Its toolbar is a `MacToolbar` with `leadingInset` 86 before the title (the window's own `ConversationWindowToolbar` leaves the
  traffic lights' 78px plus 8px and has no sidebar button): Show in Main Window, Pin (`MacToolbarButton apple="pin"`,
  `pin_fill` and selected while pinned), Share, and "…" with `macThreadMenuItems` minus Pin. States: loaded, the
  menu open, streaming, loading (only Show in Main Window enabled) and failed ("Could not open this chat", Close
  Window). Not drawn: the share picker and the window closing once its chat is archived or deleted.
- `ConnectScreen` stays the setup and sign-in card (the app's ServerSetupScreen and LoginScreen); its preview has
  every Widgetbook state. The splash is a bare spinner, so it has no card.
- `AppLockScreen` (the AppLockGate cover) and `ImageViewerScreen` (black in both themes). The app's image viewer
  title takes the app bar theme's onSurface color, which is dark on black in light mode; the card draws it white.

## Board and schedules screen cards

- `KanbanScreen`: phone (status chips over one list, FAB, menu button), desktop columns, selection mode with the bulk
  bar, the task sheet or dialog (`openTask` takes `KanbanTaskPanel` props), loading, error, unavailable, and the Mac
  window from #396 (its `KanbanMacToolbar` is internal; the 380px inspector is docked from 760px of board width and
  covers the board from the right below that, through a container query). Not drawn: the phone drop strip and a drag
  in progress.
- `KanbanBoardsScreen`, `KanbanWorkersScreen`, `KanbanCreateScreen`, `SchedulesScreen`, `ScheduleJobDetail`,
  `JobFormScreen`, `BlueprintGalleryScreen` and `BlueprintFormScreen` follow the clean settings look; see "Clean
  settings restyle" below. The import, export, rename and inspect dialogs are callbacks only.
- Small additions to shared parts for these: `KanbanToolbar` `showSearch`, `showMore`, `onOpenMenu` and
  `onMoreAction`; `KanbanColumn` `showHandles`; `ListDetailLayout` `onOpenMenu`; `FactList` `mono`.

- Chat follow-ups #463 and #495: the latest reply's actions are Copy, Try again and Edit prompt (`AssistantMessage`
  `onEdit`, `ChatThread onEdit`, `ChatScreen`/`ConversationWindowScreen` `onEditPrompt`); what the background review
  saved is `AssistantMessage reviewNotes` (`ChatTurn.reviewNotes`), the app's `ReviewSummaryNote`: a 16px bookmark
  (`bookmark_added`, the app's `AppIcons.memory`) and the entries joined with " · " in 13px muted text, under the
  actions. The app hides Edit prompt while an undo is in flight; that transient state is not drawn.

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
- The settings pages follow `lib/src/widgets/grouped_*.dart`, `settings_scaffold.dart` and
  `settings_search_field.dart`: a change there (metrics, a new row slot) needs the matching change in
  `src/components/Grouped*`, `SettingsScaffold` and `src/grouped.css`, or every settings card drifts at once.

## Known render warns

- KanbanTaskPanel's tall cells (Running, RunsOpen, Dark) are cut at the review sheet's cell height. The
  component is fine (the panel scrolls in the app); graded good with that noted.

- `[FONT_REMOTE]` for "SF Pro Text", "Roboto Mono", "Material Symbols Outlined": expected (system fonts and the
  Google Fonts icon import).

## Clean settings restyle (#540–#550, Flutter #511–#539)

- Foundation (#540): `GroupedListView`, `GroupedSection`, `GroupedRow`, `GroupedSwitchRow`, `GroupedChoiceRow`,
  `GroupedValueRow`, `GroupedMenuRow`, `GroupedTextFieldRow`, `GroupedSegmentedRow`, `GroupedDialog`,
  `SettingsScaffold`, `SettingsSearchField` and `PillSegmentedControl` recreate `lib/src/widgets/grouped_*.dart`,
  `settings_scaffold.dart`, `settings_search_field.dart` and `adaptive_tab_bar.dart`. `GroupedTile`, `GroupedFooter`
  and `GroupedDialogNote` are exported helpers without cards (`componentSrcMap: null`).
  - Three looks from `platform` + `device` (`useGroupedChrome`): ios = apple+touch, mac = apple+mac, material.
    `SettingsScaffold`, `GroupedListView`, `GroupedSection` and `GroupedDialog` pass their device down through
    `DeviceScope` (a ShellChromeContext override), so Menus inside follow it. Mac cells pass `device="mac"` once.
  - Metrics are `--hg-*` custom properties on `h-gm--ios|mac|material` in `src/grouped.css`; divider indents are
    section modifier classes (`text`, `leading`, `tile`, `choice`); a `choice` section is a named radiogroup.
    The section card does not clip, so a row's menu can leave it; menus inside a scrolling `GroupedListView` are
    still clipped by the scroll container (previews leave room under the row).
  - Shared additions: `Switch small`, `SegmentedControl size`, `IconButton size={44}`, `MacToolbar leading` and an
    element subtitle, `MacToolbarSearchField hint` (Escape clears without closing a dialog), `MenuAnchor` stops
    mousedown, `GroupedRow expanded` and `checkboxChecked`, token `--h-apple-blue` (the iOS/Mac check; the one
    non-monochrome accent). `GroupedTile` is `aria-hidden`.
  - Internal: `screen.tsx` (`ScreenState` loading/failed/empty, `screenDevice`, `ScreenSplit`), `styles/settings-state.css`,
    `rowButton.tsx` (a row's small trailing button: iOS tinted pill, Mac bordered push button, Material outlined
    pill), `GroupedRow/GroupedMenuButtonRow.tsx` (row with a trailing "…" menu), `src/mcp.ts`.
- Screens on it (each takes `platform` + `device` instead of `layout`, inherited from `AppShell`, else touch):
  - Plugins, Skills, Helper models (#547): `PluginsScreen` draws its own 400px list/detail split inside the
    scaffold body (no detail slot in `SettingsScaffold`); catalog search sits in the list on phone/Material and in
    the Mac toolbar. `PluginRow` (muted On/Off/Inactive, version meta, "Bundled · …", "Needs login" warning; catalog
    rows Official, Installed / Update available or Install), `PluginDetail` (header over sections), `SkillRow`
    (switch row "description · source · used N times"), `HubSkillRow` ("Trust · description", no tags),
    `SkillsScreen` (profile subtitle menu, search and filter in the bar, category groups with brand casing, "Hub
    skills" update row), `ModelSlotRow` (value row: "Main model", "Provider default", "Off" or the short model),
    `HelperModelsScreen` (footer names the main model; Mac puts it in the subtitle; MoA group with Preset).
  - Messaging (#542): one group of `MessagingPlatformRow`s with a bot tile; intro is the footer; Mac subtitle
    "N of M on"; off without credentials shows Set Up (iOS value + chevron, Material outlined pill, Mac "Set Up…").
  - MCP (#546): `McpServerRow`/`McpCatalogRow` are tile rows with a muted facts line and a "Sign in needed" warning;
    the servers list and catalog put a 380px list beside the detail or install pane; Add and Save are the bar's
    `formAction`; catalog search and filter are the bar's `search`.
  - Profiles and Kanban lists (#545): `ProfileTile` (initials tile, description or path, "model · N skills"
    caption; Apple check / Material "Active"; on iOS "Change default model" is in the long-press sheet:
    `actionSheetOpen`/`actionSheetProfile`), `ProfilesScreen` (+ when `onNewProfile`), `MacProfilesPage` detail as
    grouped sections, `KanbanBoardsScreen`/`KanbanWorkersScreen` (`GroupedMenuButtonRow`), `KanbanCreateScreen`
    (grouped form, Cancel and Create in the bar).
  - Schedules and forms (#549): `SchedulesScreen` (scope as subtitle menu on phone, This profile / All profiles
    segmented control on Mac; filter menu, Refresh and "+" in the bar; `ScheduleFilterBar` retired),
    `ScheduleJobRow` (switch row; failure on the error line, undelivered on the warning line; keeps `RowActions`;
    must sit in a `GroupedSection`), `ScheduleJobDetail` (grouped; `onBack` gives the pushed phone page; Mac header
    with "…", Edit, Run now), `JobFormScreen` with `SchedulePicker` as its "When" group, `BlueprintGalleryScreen`
    (`BlueprintCard` is a `GroupedRow`), `BlueprintFormScreen`.
  - New cards (#543, #548, #550): `SettingsDialog`, `AppearanceDialog`, `NotificationsDialog`, `AppLockDialog`,
    `AboutDialog` (compositions of `GroupedDialog`); `ModelPicker` (Material sheet on phone, 440px dialog on desktop,
    on every platform as the app; search above 8 models; one choice group per provider; effort pills under the
    list); `BotsScreen`, `CreateGroupDialog` (Material dialog on every platform, as the app) and
    `BotGroupChatScreen` (room bar, status card, pending actions, transcript cards and composer; not `ChatThread`).
- Not on it yet (as in Flutter): `MessagingSetupScreen`, `TelegramPairingScreen`, `SkillDetailScreen`,
  `SkillEditorScreen`, `HubSkillScreen`, `McpInstallPanel` and `McpCommandReview` keep the internal `ScreenFrame`
  (`src/screenFrame.tsx`: `ListDetailLayout` list layout, 640/720px column, `device="mac"` on apple + desktop).
- Gaps:
  - Material floating labels are always floated; the GroupedDialog Mac panel has no window chrome; the Mac pop-up
    value is a plain bordered button; the Mac Save/Create push button uses the primary fill.
  - Busy `formAction`s announce "Add"/"Save" (no "Adding…"/"Saving…"); `SettingsBarAction` has no `selected`, so a
    filter button isn't marked while a filter is on; the iOS segmented control spans the full width (the app's is
    compact and centred); `GroupedRow` has no monospace title, so PluginDetail's command rows and MCP tool names are
    hand-drawn or plain.
  - Subtitles and captions are cut to one line; `GroupedSwitchRow` dims only the switch when disabled.
  - Rows without swipe or right-click: Kanban board and worker rows, the Mac schedule pane's "…".
  - A swiped `PluginRow` paints `.h-swipe__row` from PluginRow.css; a `SwipeActions` fix would serve McpServerRow
    and ScheduleJobRow too. `.h-bots-add` duplicates Messaging's Set Up button.
  - `ModelPicker`'s 560px dialog height cap isn't enforced; Bots: no per-kind status counts, no @mention
    suggestions, activity entries without their payload.
  - Not drawn: remove/discard confirmations and snack bars, the import/export/rename dialogs, Providers' "What it
    needs" is a hand-drawn disclosure.
  - Mac menus with any checkable item reserve the check column for every item (native macOS behaviour); Flutter's
    compact `AdaptivePopupMenuButton` doesn't yet, so the app's job "…" menu is still misaligned (#555).
  - `CreateGroupDialog` keeps one size on every platform; in Flutter the search and rows inside it follow the Mac
    metrics, so the app mixes sizes there (#555).
  - `GroupedValueRow` (and `GroupedMenuRow`) on Apple keep the title up to 60% of the row and let the value give way
    (iOS value capped at 45%, Mac pop-up at 260px, as `grouped_form.dart`); `SegmentedButton` gives a segment that
    needs more room for its label and check the extra width.
