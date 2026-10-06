# Hermes app: how to build with this library

These components recreate the Hermes Flutter app (a client for a self-hosted Hermes Agent: chat, Kanban, scheduled jobs, MCP servers, plugins). The look is near-monochrome zinc grays, a near-black (light) or near-white (dark) primary instead of a brand hue, 1px borders instead of shadows, and one 14px radius for cards.

## Setup

Wrap every screen in `HermesProvider`. It sets the `--h-*` tokens, the system font and the page background. Without it components fall back to light tokens but text renders in the browser default font on a transparent background.

```jsx
const {
  HermesProvider,
  AppShell,
  ThreadSidebar,
  ChatHeader,
  WelcomeView,
  ChatComposer,
  ModelPill,
} = window.HermesUI;

<HermesProvider theme="light" fill>
  {" "}
  {/* theme="dark" for the dark palette */}
  ...
</HermesProvider>;
```

A nested `<HermesProvider theme="dark">` switches only its subtree.

**Platform.** The app follows Apple's Human Interface Guidelines on iOS, iPadOS and macOS and stays Material on Android, Windows and Linux. `<HermesProvider platform="apple">` (default `"material"`) switches every component that has a `platform` prop; pass `platform` on one component to override. Apple pieces: 44px bars and tap targets, the 51x31 toggle, a chevron back button, a "+" in the bar instead of a floating button, segmented controls instead of underline tabs, inset grouped list rows, iOS pull-down and compact Mac menus, eight-spoke spinners, swipe actions and long-press action sheets on touch rows, detent sheets. Where touch and pointer differ, `layout="phone"` means touch (iPhone, iPad in Split View) and `layout="desktop"` means Mac; a full-screen iPad uses `layout="desktop"` with `device="touch"` on its `AppShell`, which the sidebar and header inside inherit. `typeRamp` (iOS: body 17, subheadline 15, footnote 13, caption 12) follows the platform; pass `typeRamp="default"` for a Mac screen. Nothing changes unless `platform="apple"` is set. Icons are Material Symbols (`<Icon name="schedule" />`, snake_case names as in Flutter's `Icons.*`; `filled` for the solid glyph). Under `platform="apple"` the same names draw the CupertinoIcons glyph the app pairs with them (`schedule` a clock, `more_vert` the horizontal ellipsis, `delete` a trash can); a name the app has no pair for stays Material. `apple="back"` names a Cupertino glyph outright, `apple={false}` keeps Material on Apple.

## Styling idiom

No utility classes. Use the components for controls and cards, and never draw a control the library has: `Switch` (on/off), `Spinner` (anything loading), `SegmentedControl` (tabs over one view), `Menu` inside a `MenuAnchor` with `align="start" | "end"` (any popup or overflow menu), `SwipeActions` and `ActionSheet` (iOS row swipes and the long-press sheet; list rows also take `swipeRevealed` and `actionSheetOpen`). For screen parts: `Tag` (pill facts on rows and details), `Banner` (an inline success/warning/error outcome), `SwitchRow` and `RadioRow` (labelled settings), `SectionHeader` (group headings), `FactList` (what Hermes will run), `Sheet` (a bottom sheet or dialog over a dimmed screen), `SegmentedButton` (one choice of a few inside a form). Each follows the platform by itself; for your own layout glue use plain CSS (flex/grid, inline styles) with the tokens below. Never hardcode hex colors: every color must be a token so dark mode works.

| Purpose  | Tokens                                                                                                                                              |
| -------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| Surfaces | `--h-bg`, `--h-surface`, `--h-surface-high` (tinted fill), `--h-sidebar`                                                                            |
| Text     | `--h-fg`, `--h-muted` (timestamps, hints), `--h-link`                                                                                               |
| Lines    | `--h-border` (1px card/divider), `--h-border-subtle`                                                                                                |
| Accent   | `--h-primary` / `--h-on-primary` (the single primary action), `--h-secondary`                                                                       |
| Status   | `--h-error`, `--h-success`, `--h-warning`                                                                                                           |
| States   | `--h-hover`, `--h-pressed`, `--h-scrim`, `--h-shadow` (menus only)                                                                                  |
| Apple    | `--h-apple-red`, `--h-apple-orange` (swipe actions), `--h-apple-elevated` (action sheet Cancel)                                                     |
| Radii    | `--h-radius` 14px (cards), `--h-radius-lg` 20px (composer), `--h-radius-sm` 10px (buttons, fields), `--h-radius-xs` 6px (badges), `--h-radius-pill` |
| Fonts    | `--h-font`, `--h-font-mono`                                                                                                                         |

Type classes: `h-headline-sm`, `h-title-lg`, `h-title-md`, `h-title-sm`, `h-body-lg`, `h-body-md`, `h-body-sm`, `h-label-lg`, `h-label-md`, `h-label-sm`, `h-mono`, `h-muted`, and `h-divider` for an `<hr>`.

Layout rules from the app: list and detail side by side from 900px wide (`ListDetailLayout`), or from 700px on a full-screen iPad in either orientation (Split View halves stay narrow); Kanban columns from 720px; phone layouts have no bottom bar: a top app bar whose menu button opens the sidebar as a drawer (`AppShell layout="phone" drawerOpen`), and the drawer stays on phones under Apple too. Desktop sidebar is 280px; on a Mac (`platform="apple"`, `layout="desktop"`) it runs under the traffic lights, hides and resizes (220 to 360px). The chat column (messages and composer) is at most 680px wide and centered on every platform. One filled `Button` per view; secondary actions are `outlined`, dismissive ones `text`.

## Where the truth lives

Read `styles.css` and its imports (tokens and every component's CSS) before styling, and each component's `.prompt.md` and `.d.ts` for props. Screens are composed, not drawn: chat = `AppShell` + `ThreadSidebar` + `ChatHeader` + messages (`UserMessage`, `AssistantMessage`, `ReasoningBlock`, `ToolCallGroup`/`ToolCallCard`, `ApprovalCard`, `ClarifyCard`, `ThinkingIndicator`) + `ChatComposer` with a `ModelPill`; Kanban = `KanbanToolbar` + `KanbanColumn` of `KanbanCard`s + `KanbanTaskPanel`; settings-style lists = `ListDetailLayout` with `McpServerRow`, `PluginRow`, `ScheduleJobRow`, `ProfileTile`; empty or failed screens = `StateMessage`.

Whole screens to start from (group Screens, each with `layout="phone" | "desktop"` and its empty, loading and failed states): `McpServersScreen`, `McpCatalogScreen`, `McpAddServerScreen`, `McpSignInScreen`, `McpJsonEditorScreen`, `PluginsScreen`. Their panes stand alone too: `McpServerDetail`, `McpInstallPanel`, `McpCommandReview`, `PluginDetail`.

Forms and plain lists: a form screen is a column of `FormSection`s (heading, fields, helper or error; `collapsible` for "Advanced") holding `TextField`, `SelectField` (any dropdown or picker field), `Chip` rows and a `ModelPill`; any plain list (boards, workers, settings rows) is `ListRow`s, which form an inset grouped list by themselves under `platform="apple"`.

On a Mac (`platform="apple"`, `layout="desktop"`) a page's top bar is a `MacToolbar`: title over subtitle, `MacToolbarButton`s, a `MacToolbarSeparator` between groups, and a `MacToolbarSearchField` where the page searches.

Screen cards show whole app screens from plain data; start a mock of one of them from its card: `ChatScreen` (a chat's messages alone: `ChatThread`), `ConnectScreen`, `AppLockScreen`, `ImageViewerScreen`.

## Example

```jsx
<HermesProvider fill>
  <div
    style={{
      maxWidth: 720,
      margin: "0 auto",
      padding: 24,
      display: "flex",
      flexDirection: "column",
      gap: 16,
    }}
  >
    <div className="h-title-md">Nightly backup</div>
    <Card>
      <div className="h-body-md h-muted">Runs every day at 03:00.</div>
      <div style={{ display: "flex", gap: 8, marginTop: 12 }}>
        <Badge tone="error">Failed</Badge>
        <Badge>acme</Badge>
      </div>
    </Card>
    <div style={{ display: "flex", gap: 8 }}>
      <Button icon="play_arrow">Run now</Button>
      <Button variant="outlined">Edit</Button>
    </div>
  </div>
</HermesProvider>
```

Settings-style screens have whole-screen cards (group Screens) to start from: `ProfilesScreen` (on a Mac, `MacProfilesPage`), `MessagingScreen`, `MessagingSetupScreen`, `TelegramPairingScreen`, `SkillsScreen`, `SkillDetailScreen`, `SkillEditorScreen`, `HubSkillScreen` and `HelperModelsScreen`. Each takes plain data, a `state` for loading and failure, `layout="phone" | "desktop"` and `platform`; their rows are `SkillRow`, `HubSkillRow`, `MessagingPlatformRow` and `ModelSlotRow`.
