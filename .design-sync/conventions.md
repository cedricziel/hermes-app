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

A nested `<HermesProvider theme="dark">` switches only its subtree. Icons are Material Symbols (`<Icon name="schedule" />`, snake_case names as in Flutter's `Icons.*`; `filled` for the solid glyph).

## Styling idiom

No utility classes. Use the components for controls and cards; for your own layout glue use plain CSS (flex/grid, inline styles) with the tokens below. Never hardcode hex colors: every color must be a token so dark mode works.

| Purpose  | Tokens                                                                                                                                              |
| -------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| Surfaces | `--h-bg`, `--h-surface`, `--h-surface-high` (tinted fill), `--h-sidebar`                                                                            |
| Text     | `--h-fg`, `--h-muted` (timestamps, hints), `--h-link`                                                                                               |
| Lines    | `--h-border` (1px card/divider), `--h-border-subtle`                                                                                                |
| Accent   | `--h-primary` / `--h-on-primary` (the single primary action), `--h-secondary`                                                                       |
| Status   | `--h-error`, `--h-success`, `--h-warning`                                                                                                           |
| States   | `--h-hover`, `--h-pressed`, `--h-scrim`, `--h-shadow` (menus only)                                                                                  |
| Radii    | `--h-radius` 14px (cards), `--h-radius-lg` 20px (composer), `--h-radius-sm` 10px (buttons, fields), `--h-radius-xs` 6px (badges), `--h-radius-pill` |
| Fonts    | `--h-font`, `--h-font-mono`                                                                                                                         |

Type classes: `h-headline-sm`, `h-title-lg`, `h-title-md`, `h-title-sm`, `h-body-lg`, `h-body-md`, `h-body-sm`, `h-label-lg`, `h-label-md`, `h-label-sm`, `h-mono`, `h-muted`, and `h-divider` for an `<hr>`.

Layout rules from the app: list and detail side by side from 900px wide (`ListDetailLayout`), Kanban columns from 720px; phone layouts have no bottom bar: a top app bar whose menu button opens the sidebar as a drawer (`AppShell layout="phone" drawerOpen`). Desktop sidebar is 280px. One filled `Button` per view; secondary actions are `outlined`, dismissive ones `text`.

## Where the truth lives

Read `styles.css` and its imports (tokens and every component's CSS) before styling, and each component's `.prompt.md` and `.d.ts` for props. Screens are composed, not drawn: chat = `AppShell` + `ThreadSidebar` + `ChatHeader` + messages (`UserMessage`, `AssistantMessage`, `ReasoningBlock`, `ToolCallGroup`/`ToolCallCard`, `ApprovalCard`, `ClarifyCard`, `ThinkingIndicator`) + `ChatComposer` with a `ModelPill`; Kanban = `KanbanToolbar` + `KanbanColumn` of `KanbanCard`s + `KanbanTaskPanel`; settings-style lists = `ListDetailLayout` with `McpServerRow`, `PluginRow`, `ScheduleJobRow`, `ProfileTile`; empty or failed screens = `StateMessage`.

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
