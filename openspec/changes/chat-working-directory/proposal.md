# Proposal

## Why

Hermes is a coding agent: every chat runs in a working directory on the Hermes server, and its tools read, write and run commands there. The app never chooses or shows that directory. A chat started from the phone is created with no `cwd`, so Hermes picks its own default (the profile's configured `terminal.cwd`, else the dashboard's launch directory), and for source `hermes_app` it stores that default on the chat. The user has no way to know which repository the agent is about to edit, and no way to point it at another one. The Hermes web dashboard and desktop app both offer a workspace picker; the app does not.

## What Changes

- A chat shows where it runs: the folder name, its path "on your server", the git branch and, when the folder belongs to a Hermes project, the project name. In an open chat this is a line under the header title; on a new chat it is a row above the composer, so the folder is visible before the first message is sent.
- Starting a chat lets the user pick the folder first: the server's default, a project's folders, recently used repositories the server knows, "Browse folders on your server", or "Type a path" with completions. Picking is one tap from the list for the common case; typing is the fallback.
- An existing chat can be moved to another folder (`session.workspace.move`) after a confirmation that says what happens: later messages use the new folder, earlier messages and files stay where they are. It is offered only while no reply is running and only on a server that has the method.
- After the server creates the session the app compares the folder Hermes reports with the one asked for. Hermes silently falls back to its default when a path does not exist, so a difference is shown ("Hermes started in … instead") rather than assumed fine.
- The chat list's folder grouping (`chat-folder-grouping`) and the header use one label, and a moved chat regroups.
- On a server without the workspace routes the feature hides its controls and keeps showing the folder where the chat rows already carry it.

Not in this change:

- Creating, renaming, archiving or deleting projects; adding or removing a project's folders; making a project active (`projects.create`, `update`, `add_folder`, `remove_folder`, `set_primary`, `archive`, `delete`, `set_active`). A first version sees and chooses; managing projects is a later change.
- Grouping the chat list by project (`projects.tree`, `projects.project_sessions`, `/api/profiles/projects/tree`, `/api/profiles/sessions/sidebar`) and reacting to `projects.changed`. The picker reads the project list fresh each time it opens.
- Creating folders on the server (`POST /api/files/mkdir`), reading or previewing files, `project.facts` (detected manifests and verify commands), and a device file picker. Paths are on the server; the app never offers the phone's file system.
- `session.cwd.set` (needs a live runtime session and refuses a running one) and moving files or creating git worktrees: neither is part of `session.workspace.move`.
- Remembering the last folder on the device. "Recent" comes from the server.
- Choosing a folder for chats started by the quick panel, Ask Hermes, the watch, Siri, a notification or `hermes://new`; they keep the server's default.
- Changing the profile model: the folder is per chat, and profile still scopes the lists.

## Capabilities

### New Capabilities

- `chat-working-directory`: showing a chat's working directory, branch and project; choosing a folder for a new chat; moving an existing chat; mismatch notice; old server, App Lock, sign-out and profile behaviour.

### Modified Capabilities

- `chat-folder-grouping`: the header and the folder section use the same label, a moved chat regroups without losing selection.

## Impact

- Code: a new `lib/src/workspaces/` (repository, models, picker controller, project matching), `ChatThread` (working directory, branch), `ChatTransport.send` and `HermesGatewayTransport` (`cwd`, `cwd_explicit` on `session.create`, `moveWorkspace`, the reported `info.cwd`), `ChatController` (draft choice, mismatch notice, move), widgets under `lib/src/workspaces/widgets/` and their Widgetbook use cases, `ChatScreen` (new-chat row, header line, Mac and phone presentation).
- Backend: no new route and no server change. REST `GET /api/chat/workspaces` and `GET /api/fs/list` (generated client, untyped responses, parsed leniently), gateway `session.create` (`cwd`, `cwd_explicit`), `session.workspace.move`, `complete.path`, and the existing `GET /api/sessions` fields `cwd`, `git_branch`, `git_repo_root`. Needs a Hermes with the projects database and `session.workspace.move` (the pinned `d923a5eb` has them); older servers get the hidden-controls behaviour.
- Delivery: four PRs (see tasks.md).
- Security and privacy: paths are not secrets but can be revealing (home directory names, client project names). They are held in memory only: never in preferences, notifications, widgets, the surface snapshot, Spotlight, Handoff, the watch or telemetry. The picker only asks the server for folder names the dashboard's own web UI would show; `GET /api/fs/list` already withholds secret file names. Moving a chat changes where an agent that can run commands acts, so it always asks first.
- Observability: breadcrumbs `workspace.picker.opened` (`surface`), `workspace.chosen` (`source`: default, project, repo, browse, typed), `workspace.move.confirmed`; a span `workspace.move` and a log event `workspace.move_outcome` (`outcome`: moved, refused, unsupported, error); a log event `workspace.cwd_mismatch` (`outcome`: fell_back); a span `workspace.list` for the workspaces read (`outcome`, counts of projects and repos). No path, folder, project or profile name, branch or id in any of them.
