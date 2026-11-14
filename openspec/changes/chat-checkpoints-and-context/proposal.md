# Proposal

## Why

Two things go wrong in a long agent chat, and the app answers neither today.

1. **The agent changed files and the user wants them back.** Hermes keeps checkpoints of the working folder and has a `/rollback` command, but the app has no way to see them, look at what a restore would change, or restore.
2. **The chat is getting too full.** The model's context fills up. Hermes compresses by itself at a threshold the app cannot see, and a user can compress by hand, but the only trace in the app is a token total in the "Session usage" card and a `/compress` slash command nobody discovers. Nothing says how full the context is or what fills it.

Both belong with the chat's Activity panel (`chat-activity`): reference information that is always there when wanted, and quiet otherwise.

## What Changes

**Context** (new capability `chat-context`)

- A one-line **Context** row in the Activity panel, under "For reference": a thin bar, a percentage and "about 124k of 200k". Hidden until the server has measured it. Quiet below 80%; it never adds a dot, a banner, a notification or a toast.
- Tapping it opens **Context details**: what fills the context by category (system prompt, tools, rules, skills, MCP servers, sub-agents, memory, conversation), from `session.context_breakdown`, with the numbers shown as text, not only as colour.
- **Compress conversation…** in those details, always available while the chat is idle, and offered once as a suggestion on the row when the context is 85% full or more and the chat is idle. A confirmation says what is lost, that it cannot be undone and that a helper model writes the summary. An optional "Focus on" field steers the summary. The outcome is shown as a line in the transcript ("Conversation compressed · 42 → 9 messages") and the chat is re-read from the server.
- The existing "Session usage" card keeps its place; the Context row reads from the same `SessionUsageController` snapshot (no second poll).

**File checkpoints** (new capability `chat-checkpoints`)

- A **File checkpoints** row in the Activity panel, under "For reference", only when the server reports checkpoints on (`rollback.list` answers `enabled: true`). A chat that changed files on a server where they are off gets the same row saying they are off and what turns them on.
- **Checkpoint list**: newest first, each with a plain sentence for why it was taken ("Before editing `a.py`", "Before a terminal command", "Before a restore"), a relative time, and a count of the files that differ from now.
- **Changes view**: the file list first (from the diff's `stat`), then one file at a time using the diff view the tool-call cards already draw (`ToolDiffBody`). Hermes cuts the diff at 4,000 characters without saying so; the app says so when it detects the cut.
- **Restore**, two kinds, each behind a confirmation that states exactly what changes:
  - *Restore this file*: one file goes back to the checkpoint. The chat is untouched. Allowed while the agent works.
  - *Restore all files*: every file in the checkpoint goes back **and Hermes removes the chat's last message and everything after it** (this is what the server does, whichever checkpoint is chosen). Only while the chat is idle. The removed message is put back in the composer, unsent.
- Hermes saves the current state as a new checkpoint before it restores. The app says so, labels that checkpoint "Before a restore", and shows it at the top of the list so the restore can be undone.

## Non-goals

- Pruning or clearing checkpoints (`POST /api/ops/checkpoints/prune`, `GET /api/ops/checkpoints`): the first runs a CLI prune in the background that may silently do nothing, the second lists store directories, not chats. Both are server maintenance, not a chat job. Recorded in design.md.
- Turning checkpoints on. The app runs nothing on the server and edits no config for this; it says what the server needs.
- Mapping a checkpoint to a message. Hermes keeps no link; the app does not guess one from timestamps.
- Showing the pre-compression messages in the transcript (`include_compacted=true`), partial compression (`here N`, `--keep N`) and previews. See Open questions in design.md.
- Auto-compression settings (`compression.threshold`, `auxiliary.compression`): the Helper models screen already owns the model slot; thresholds stay on the server.
- Per-file restores from a "restore all" in one step, and a "files only, keep the chat" restore for a whole checkpoint. The server has no such call.
- The Nous plan and top-up bars (`usage.bars`): billing, not context. Out of scope, noted for a billing change.

## Capabilities

### New Capabilities

- `chat-context`: the Context row, its details and manual compression.
- `chat-checkpoints`: the checkpoint list, changes view and restore.

### Modified Capabilities

- `chat-activity`: the two new rows and their tiers.

## Impact

- Gateway transport gains `rollbackList`, `rollbackDiff`, `rollbackRestore`, `compressSession` and `contextBreakdown`, all over the existing connection and `_commandRuntime` (runtime session confirmed, never resumed just to read). No new route, no server change.
- New `lib/src/chat/context/` and `lib/src/chat/checkpoints/` (repository with lenient parsing and sealed results, controller, plain-model widgets); `BoundActivityPanel` gains two sources; `ChatController` gains `contextIn(thread)` and `checkpointsIn(thread)` next to `usageIn`.
- `UsageSnapshot` also reads `context_source`; `status.update` kinds `compressing` and `compacted` get their own wording instead of falling through.
- Widgetbook use cases for every state; a workflow test.
- Ships as four PRs (tasks.md): contract and repositories; context and compression; checkpoints; wiring checks, workflow test and docs.

## Security and privacy

Diff text is file content from the user's own server. It is shown in the app only, held in memory for the open view, cleared when the view closes, on sign-out, on profile switch and under App Lock, and never goes into telemetry, logs, notifications, widgets, Spotlight or the surface snapshot. File names and checkpoint reasons (which can hold a command) are treated the same way. The "Focus on" text is sent in the request and not stored.
