## Why

Hermes Agent bundles an optional Kanban plugin (`plugins/kanban`): a multi-agent task board with a REST API under `/api/plugins/kanban/` and a WebSocket event stream. The app had no notion of it. This change adds it to the app when the server has it on, at parity with the web dashboard.

This change was imported from the former `docs/superpowers/` directory (design dated 2026-09-20) and is only partly implemented. It was delivered as a stack of PRs, per the design's delivery plan:

1. Detection and navigation shell: #64 (`feat(kanban): detect the Kanban plugin and add a Chat/Kanban navigation shell`), shipped.
2. Board and live events: #65 (`feat(kanban): show the board and keep it live`), shipped.
3. Task detail, create and edit, comments, dependencies: #66 (`feat(kanban): open, create and edit tasks`), shipped.
4. Triage, bulk changes, dispatcher, orchestration: #68 (`feat(kanban): triage helpers, bulk changes, dispatcher and orchestration`), shipped.
5. Boards, runs, attachments: not shipped. #74 (`feat(kanban): manage boards`) and #76 (`feat(kanban): runs, worker log and attachments on a task`) are open.

The unshipped tasks are marked `- [ ]` in `tasks.md`. This change stays under `openspec/changes/archive/` as a design record, even though it is not complete: it is not moved back to `openspec/changes/`, and finishing it does not need a new change. The shipped behaviour is described by `openspec/specs/kanban/`. The design's mockups (`2026-09-20-kanban-mockups.html`) were not imported; git history keeps them.

## What Changes

- Detect the plugin with `GET /api/dashboard/plugins`, on connect and on app resume, and show it as a top-level Kanban destination next to Chat, only while it is on.
- Show the board and keep it current from the plugin's `/events` WebSocket.
- Work with tasks: detail, create, edit, move, assign, comment, dependencies, archive, delete.
- Triage actions, bulk actions, the dispatcher and orchestration.
- Multiple boards, runs and attachments (open PRs, see above).

## Impact

- New `lib/src/kanban/` (repository, plugin detection, board controller, screens and widgets) and `lib/src/shell/app_shell.dart` for the Chat/Kanban navigation.
- The plugin's responses have no schema in the OpenAPI spec, so they are parsed by hand and tolerate missing fields, as the profiles and bots repositories do. No change to the generated client (`packages/hermes_api`).
- The events socket reuses the chat gateway's connector and authentication (`ticket` when the dashboard is gated, else the page's session token).
- Security and privacy: no new credential handling. Reads and writes go through the existing authenticated client. The design names no telemetry.

## Non-goals

The design lists none explicitly. The PRs that implement its later parts leave out, on purpose:

- Board export and import (#74): the plugin works on paths on the server, so they have no meaning for a remote client.
- Uploading and downloading attachments (#76): they need a file picker and an authenticated download path, which would add platform dependencies. Listing and removing attachments are in that PR. The design does not say how uploads and downloads should work.
