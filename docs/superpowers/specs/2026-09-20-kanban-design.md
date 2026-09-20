# Kanban plugin support — design

Hermes Agent bundles an optional Kanban plugin (`plugins/kanban`): a multi-agent
task board with a REST API under `/api/plugins/kanban/` and a WebSocket event
stream. This adds it to the app when the server has it on.

Mockups: [`2026-09-20-kanban-mockups.html`](2026-09-20-kanban-mockups.html)
(open in a browser).

## Decisions

- **Scope:** parity with the web dashboard — board, task detail/edit, comments,
  dependencies, triage actions, bulk actions, dispatcher, orchestration,
  multiple boards, runs, attachments.
- **Detection:** `GET /api/dashboard/plugins` returns only plugins that are
  enabled and not hidden, so an entry named `kanban` means on. Checked on
  connect and on app resume. Failure or a missing route reads as off.
- **Navigation:** Chat and Kanban as top-level destinations (bottom bar on
  phones, rail on wide screens). No tab bar at all while the plugin is off.
  Profiles and Bots stay in the chat sidebar.
- **Live updates:** `WS /api/plugins/kanban/events?since=<id>&board=<slug>`,
  authenticated like the chat gateway (`ticket` when the dashboard is gated,
  else the page's session token). Each frame is
  `{"events": [...], "cursor": n}`; an event only says the board changed, so
  the app refetches the board (debounced) and reconnects from the last cursor.
- **Responses have no schema in the spec**, so they are parsed by hand and
  tolerate missing fields, as the profiles and bots repositories do.

## Delivery (stacked PRs, one release)

1. Detection + navigation shell
2. Board (read) + live events
3. Task detail, create/edit, comments, dependencies
4. Triage, bulk, dispatcher, orchestration
5. Boards, runs, attachments
