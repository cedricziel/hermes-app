## Context

Hermes Agent bundles an optional Kanban plugin (`plugins/kanban`): a multi-agent task board with a REST API under `/api/plugins/kanban/` and a WebSocket event stream. This adds it to the app when the server has it on. The design had HTML mockups (phone and wide layouts); they are not kept in the tree.

## Goals / Non-Goals

**Goals:**

- Parity with the web dashboard: board, task detail and edit, comments, dependencies, triage actions, bulk actions, dispatcher, orchestration, multiple boards, runs, attachments.

**Non-Goals:** the design states none. See the proposal for what the later PRs leave out.

## Decisions

**Detection.** `GET /api/dashboard/plugins` returns only plugins that are enabled and not hidden, so an entry named `kanban` means on. Checked on connect and on app resume. Failure or a missing route reads as off.

**Navigation.** Chat and Kanban are top-level destinations (bottom bar on phones, rail on wide screens). There is no tab bar at all while the plugin is off. Profiles and Bots stay in the chat sidebar.

**Live updates.** `WS /api/plugins/kanban/events?since=<id>&board=<slug>`, authenticated like the chat gateway (`ticket` when the dashboard is gated, else the page's session token). Each frame is `{"events": [...], "cursor": n}`. An event only says the board changed, so the app refetches the board (debounced) and reconnects from the last cursor.

**Responses have no schema in the spec**, so they are parsed by hand and tolerate missing fields, as the profiles and bots repositories do.

**Delivery (stacked PRs, one release).**

1. Detection and navigation shell
2. Board (read) and live events
3. Task detail, create and edit, comments, dependencies
4. Triage, bulk, dispatcher, orchestration
5. Boards, runs, attachments

## Platforms and invariants

- Platforms: the navigation switches between a bottom bar (phones) and a rail (wide screens), so it applies to every platform the app runs on. The design names no native entitlement, manifest or Xcode project change.
- Invariants touched:
  - API layering: the plugin's routes have no response schema in the spec, so they are parsed by hand, the exception the project context allows for routes without a schema. Requests go through the authenticated client.
  - Auth: the events socket authenticates like the chat gateway, with the ws ticket or the session token, never a cookie.
  - The design does not mention telemetry.

## Risks / Trade-offs

The design states none. Facts recorded elsewhere: a request the plugin refuses (for example moving a task to `ready` while a parent is open) shows the plugin's message as is (#66); and the whole feature is only reachable while the plugin is on, so the shared chat code changed only by generalising the gateway connector (#65).
