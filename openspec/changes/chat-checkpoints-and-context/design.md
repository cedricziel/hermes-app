# Design

All server facts below were read from the Hermes source at the pinned revision (`openapi/HERMES_REF`, `d923a5eb`) and checked against `openrpc/hermes-gateway.openrpc.json`. Paths are relative to the Hermes repository. Where a fact could not be read it says so.

## Server surface

### Rules that hold for every method here

- Gateway methods over `/api/ws`, called with the **runtime** `session_id` the chat already owns. Opening a view never creates or resumes a session (same rule as `session-usage`). An unknown id answers 4001 `session not found`.
- `profile` is accepted by every contract but **ignored** by the checkpoint methods (`tui_gateway/methods_tools.py` `@_rpc(..., live_session=True)`); the session decides the cwd and the checkpoint store. The app still sends it (as `session.usage` does) so a server that starts scoping it behaves.
- `method not found` (-32601) means "this server has no such feature": the row is not drawn. It is never an error banner.

### `rollback.list` (`methods_tools.py:1210`)

- Params: `{session_id, profile?}`.
- Result: `{enabled: bool, checkpoints: [{hash, timestamp, message}]}`, newest first, at most `checkpoints.max_snapshots` (20). `message` is the manager's `reason` renamed (the test at `tests/tui_gateway/test_tui_gateway_server.py:12410` pins it). Example:
  `{"enabled":true,"checkpoints":[{"hash":"aaa111…","timestamp":"2026-09-29T10:00:00+00:00","message":"before write_file: a.py"}]}`
- Disabled: `{"enabled":false,"checkpoints":[]}`. **Checkpoints are off by default** (`hermes_cli/config_defaults.py:499`, `checkpoints.enabled: false`); the `HERMES_TUI_CHECKPOINTS` environment variable overrides config for gateway sessions (`tui_gateway/checkpoints.py`).
- Not on the wire: file counts, insertions, deletions, short hash. The app derives a file count from the diff's `stat`, lazily.
- Reasons are free text: `before write_file`, `before patch`, `before terminal: <first 60 chars of the command>`, `pre-rollback snapshot (restoring to <8 chars>)`, sometimes with a trailing `[nested git repos not captured: …]`. The app maps the known prefixes to plain sentences and shows anything else as a neutral "Checkpoint". A terminal command is **never** displayed (it can hold a secret); the sentence is "Before a terminal command".
- Errors: 5020 (any exception, message is the exception text), 4001.

### `rollback.diff` (`methods_tools.py:1250`)

- Params: `{session_id, hash, profile?}`. `hash` may be a hash (4–64 hex) **or a 1-based index**; `_resolve_checkpoint_hash` (`tui_gateway/checkpoints.py:46`) tries `int(ref)` first, so a short all-digit hash is read as an index. The app always sends the full hash from `rollback.list`.
- Result: `{stat: string, diff: string, rendered?: string}`. `stat` is plain `git diff --stat`, untruncated. `diff` is plain `git diff --no-color` of **the checkpoint against the current working tree of the whole folder** (not only what this chat changed), **hard-cut to its first 4,000 characters with no marker** (`raw = r.get("diff","")[:4000]`). `rendered` is an ANSI rendering for a terminal; the app ignores it.
- Failures of the diff engine are swallowed: a bad hash, a busy store or a missing checkpoint returns an OK result with empty `stat` and `diff`, which looks like "no changes". The app therefore treats an empty answer for a checkpoint that was just listed as "Couldn't read the changes", not as "nothing changed", unless the list's own newest checkpoint was taken a moment ago (see states).
- Container backends (`terminal.backend` docker etc.): a real JSON-RPC error 5022 with the text `Checkpoints are not taken for terminal.backend=…: file paths belong to the container, not this host.` Shown as "Checkpoints don't cover this chat's workspace."
- Other errors: 4014 `hash required`, 5022 (including `Invalid checkpoint number. Use 1-N.`).

### `rollback.restore` (`methods_tools.py:1220`, engine `tools/checkpoint_manager.py:~1270`)

- Params: `{session_id, hash, file_path?, profile?}`. `file_path` must be relative and stay inside the cwd; it is matched as a **literal** pathspec (`GIT_LITERAL_PATHSPECS`), so `.` is not a way to say "everything"; the app only sends paths it read from `stat`.
- Result (open object): success `{"success":true,"restored_to":"abc12345","reason":"before write_file: a.py","directory":"/home/u/proj","history_removed":3}`; failure `{"success":false,"error":"…"}`. `directory` is an absolute server path and is not shown.
- **Most failures are an OK answer with `success:false` and an `error` string**, not a JSON-RPC error: `No checkpoints exist for this directory`, `Checkpoint '<h>' not found`, `File path escapes the working directory via traversal`, `Restore selection matched no files in checkpoint: …`, `Checkpoint contains nested git repositories that were not captured (<paths>); rollback was not performed`, `Restore failed: <git error>`, `checkpoint store is busy: <path>`, the container refusal above. The app keeps a fixed set of plain sentences for the ones it recognises by prefix and otherwise says "Hermes couldn't restore the files." without the raw text.
- JSON-RPC errors: 4014 `hash required`; **4009 busy for a full restore while the chat is running** (a file-scoped restore is allowed mid-turn); 4001; 5021 (message may be `checkpoint restored, but session history rewind failed: …`: **files are restored, the chat is not rewound**; the app says exactly that and re-reads the chat).
- **What a restore does** (all read from the engine):
  - *It saves the current state first*: `_take(..., "pre-rollback snapshot (restoring to <h>)")` runs before any file is touched and becomes the newest entry in the list. If the tree has not changed since the last checkpoint nothing new is saved, because the newest checkpoint already holds this state. So a restore can be undone by restoring that entry.
  - *It overwrites files with the checkpoint's version* (`git checkout <hash> -- …`). **It does not delete files created after the checkpoint** on this path (the RPC calls `restore` with `safe=False`; only the CLI and messaging `/rollback` use the safe mode that deletes Hermes-created files and skips user-edited ones). It **does overwrite hand edits** made after Hermes last wrote the file.
  - *Full restore also rewinds the conversation*: with no `file_path`, on success the handler calls `_rewind_active_session_history(session, len(user_indices) - 1)` under the history lock, removing the **last real user message and everything after it** from the live session and, for a stored session, from the durable transcript (`SessionDB.rewind_user_turn`; rows stay on disk with `active=0`). `history_removed` is the number of messages removed. **It is always exactly the last user turn, whichever checkpoint is restored**: restoring checkpoint 7 of 10 still removes one turn. A checkpoint has no link to a message or turn, only `{hash, timestamp, reason}`.
  - *A file-scoped restore never touches the chat.*
- Scope: the checkpoint chain belongs to the **working folder**, not the chat. Every chat in that folder sees and restores the same list. Checkpoints are made at most once per folder per turn, just before the first `write_file`, `patch` or destructive-looking `terminal` command of that turn; a turn with no file write makes none. `/` and `$HOME` are never checkpointed. Files over 10 MB, `node_modules`, build output, `.env*`, `*.log` and nested git repositories are not captured.
- Timeouts: each git call is 30 s (60 s for add and checkout); the RPC has no timeout of its own. The app gives restore and diff a 90 s limit and says "may have happened" when it lapses (below).
- Wrinkle (read, not run): `rollback.list` and `restore` use the session cwd exactly, while checkpoints are keyed by the nearest project-marker folder of the file written. A chat whose cwd is a sub-folder of the project root can see an empty list. The empty state words this as "No checkpoints yet for this chat's folder."

### `GET /api/ops/checkpoints` and `POST /api/ops/checkpoints/prune` (`hermes_cli/web_routers/ops.py:801-837`)

- GET: `{sessions:[{session, files, bytes}], total_bytes}`. Despite the name, `session` is a **store directory** (`store`, `legacy-<ts>`), not a chat. No per-folder or per-chat data.
- POST prune: `{ok:true, pid, name}` immediately; it starts `hermes checkpoints prune` in the background (retention 7 days, 500 MB, orphans deleted) with no stdin, so the orphan confirmation can abort and the call can do nothing while answering `ok:true`. With several profiles it requires an explicit `profile` (400 otherwise).
- **Not used by this change.** Both are server housekeeping with no result the app can show truthfully. Reconsidered when a Hermes release reports a prune result.

### `session.compress` (`tui_gateway/methods_session.py:2136`, `_compress_live` :2089)

- Params: `{session_id, profile?, focus_topic?}`. `focus_topic` is the raw `/compress` argument string, so it is also where `here N`, `--keep N`, `--preview` and `--dry-run` are parsed (`hermes_cli/partial_compress.py`). **The app sends a focus topic only after rejecting any text that starts with `-` or with `here`** so free text can never be read as a flag; it does not use the flags in this change.
- Result: `{status: "compressed"|"aborted", removed, before_messages, after_messages, before_tokens, after_tokens, summary, usage, info, messages}`. `summary` is `CompressionSummary {noop, aborted, refused_would_grow, fallback_used, headline, token_line, note}`; example headline `Compressed: 42 → 9 messages`, token line `Approx request size: ~120,000 → ~30,000 tokens`. Token counts are rough estimates. `messages` is the replacement transcript in a shape the app does not parse: it **re-reads the chat over REST** (`ThreadNeedsRefetch`, existing).
- Special results: fewer than 4 messages → `status:"compressed"` with `summary.noop:true` ("No changes from compression: N messages"); summary generation failed → `status:"aborted"` with `summary.aborted` and a reason note; the summary would be larger → `refused_would_grow`; a placeholder summary was used → `fallback_used`; another compression holds the lock → `{compressed:false, lock_held:true, message}`; a compute-host session may answer `{status:"pending", turn_isolation:true, message}` and refresh later.
- Errors: **4009** while a reply runs or another compress runs (`session busy — …`); 5032 agent not built yet; 5005 anything else.
- **While it runs the session is `running`.** A prompt sent meanwhile is queued by the server and drained afterwards; the app's own queue (`queue-messages`) already covers this and Send is not blocked by the app.
- **What is lost, kept and stored:**
  - A helper model writes one summary of the middle of the conversation. It is the `compression` auxiliary slot (`auxiliary.compression`), falling back to the main model, so it **costs tokens on that model** (timeout floor 300 s).
  - Kept: the system prompt, the first 3 messages, a token-bounded tail (default lean: about 2.5% of the window, at least 20 messages and at least one user message), and the to-do snapshot. Old tool results are pruned first without a model call. A focus topic makes the summarizer keep that topic and compress the rest harder.
  - `compression.in_place` defaults to **true**: the session id does not change, there is no parent link, and the replaced messages stay in the database marked `active=0, compacted=1`. With `in_place: false` (legacy) the session rotates to a child id; the app already follows that (`stored_session_id`, thread re-keying in `hermes_gateway_transport.dart`).
  - What the user sees afterwards: `GET /api/sessions/{id}/messages` defaults to `include_compacted=false`, so a re-read shows the **compressed view, the summary message in place of the middle**. `?include_compacted=true` (a query parameter in the OpenAPI) returns the full history including archived rows. `session.history` returns active rows only.
  - **It cannot be undone.** Nothing restores archived rows into the live context. `session.undo` removes the last user turn; it is not an undo of compression.

### `session.context_breakdown` (`methods_session.py:1479`)

- Params: `{session_id, profile?}`. Allowed while a reply runs; read-only, no provider call.
- Result: `{categories:[{id,label,color,tokens}], context_max, context_percent, context_used, context_source, context_estimated, estimated_total, model, context_files:[{label,path,chars,est_tokens,loaded,status}]}`. Category ids: `system_prompt`, `tool_definitions`, `rules`, `skills`, `mcp`, `subagent_definitions`, `memory`, `conversation`. Every one but `conversation` is dropped when 0; `conversation` is always present. All numbers are rough estimates (about four characters a token). `context_used` is anchored to provider-reported tokens when there is an anchor; `estimated_total` is the sum of categories and can differ from it. `color` is a CSS variable name; the app ignores it and uses its own palette.
- Before the agent is built: `categories:[]`, `estimated_total:0`, figures from the usage mirror. Error 5000 `Could not compute context breakdown`.
- `context_files` carries absolute paths of rule files on the server. The app shows only the label and token count, never the path.

### `session.usage` and live frames (already mapped)

- `session.usage` result and push `{usage}` (`UsageSnapshot`): `context_used`, `context_max`, `context_percent` (clamped 0–100), `context_estimated`, `compressions`, plus `context_source` (`local_estimate`, `provider_usage`, `provider_usage_plus_estimate`), which the app does not read yet and will. The context fields are **absent** when `last_prompt_tokens` is 0, for example a resumed chat before its first turn in this server process. The push comes once a second during a turn, only when counters changed; `message.complete.usage` is final.
- `session.info` carries the same `usage` after each turn and after a compress. The app maps only `running` and `stored_session_id` from it today; this change also feeds its `usage` to the same controller.
- `status.update {kind}`: manual compress emits `compressing` then `ready`; automatic compaction arrives as `compacting` (already mapped to "Compacting the conversation…") and ends with `compacted`. This change gives `compressing` and `compacted` their own wording and treats `compacted` as "re-read the usage".
- **The compression threshold is not on the wire** (`compression.threshold` default 0.5, floored at 0.75 for windows under 512K, 0.85 for some models). The app cannot say "Hermes will compress at N%", and does not pretend to.
- `cost_usd` is decoded by the app but `_get_usage` does not emit it at this revision (could not find where it is set). Not used here.
- `usage.bars` is the Nous subscription and top-up balance (`tui_gateway/billing_view.py`), not context. Not used.
- `session.history` returns the durable transcript with ids; the chat already reads history over REST. Not used.

## Client architecture

Follows `session-usage` and `chat-activity`; nothing below needs a server change.

### Transport and repositories

- `ChatTransport` gains `checkpoints` and `context` capabilities implemented in `HermesGatewayTransport` next to `undoLastTurn` and `branchThread`, all through `_client()` and `_commandRuntime(...)` (a runtime id the chat owns; throws rather than resumes). A transport without them (mock chat, watch) returns the unsupported result.
- `CheckpointsRepository` (`lib/src/chat/checkpoints/`) wraps `rollback.*`, parses leniently (skip a row without a hash; a missing timestamp is unknown, never "now") and returns sealed results:
  - `CheckpointList` = `CheckpointsOff` | `CheckpointsOn(List<Checkpoint>)` | `CheckpointsUnsupported` (method-not-found) | `CheckpointsFailed(kind)`.
  - `CheckpointChanges` = `Changes(files, truncated)` | `NoChanges` | `ChangesUnreadable` | `ChangesRefused(container)` | `Failed(kind)`.
  - `CheckpointRestore` = `Restored(filesRestored?, historyRemoved)` | `RestoredHistoryNotRewound` (5021 text) | `RestoreRefused(reason)` | `Busy` | `MayHaveHappened` (timeout/lost answer) | `Failed(kind)`.
  - The kinds are a closed enum (`notFound`, `nestedRepositories`, `storeBusy`, `container`, `pathRejected`, `transport`, `other`); raw server text never leaves the repository.
- `ContextRepository` (`lib/src/chat/context/`) wraps `session.context_breakdown` and `session.compress`:
  - `ContextBreakdown` = `Breakdown(model, used, max, percent, estimated, categories)` | `BreakdownUnsupported` | `BreakdownFailed`.
  - `CompressionResult` = `Compressed(beforeMessages, afterMessages, beforeTokens, afterTokens, note, fallbackUsed)` | `NothingToCompress` | `CompressionAborted(note)` | `WouldNotShrink` | `CompressBusy` | `CompressLockHeld` | `CompressPending` | `CompressUnsupported` | `MayHaveHappened` | `Failed(kind)`.
  - Counts are bounded (0 to 10,000,000) and a `before < after` result is shown as returned, not corrected.
- **File list from `stat`.** `parseStat(stat)` reads `git diff --stat` lines `path | N +++---` and the trailing `N files changed`; a rename `a => b` or `{a => b}` shows the new path; a binary line (`Bin 0 -> 12 bytes`) is a file with no text diff. `parseDiff(diff)` splits on `diff --git a/<p> b/<p>`; a hunk list per file feeds `ToolDiffBody` (which already colours `+`/`-`/`@@` and strips the terminal heading). A file in `stat` with no section in `diff`, or a diff of exactly 4,000 characters, marks the result `truncated`; those files show "Hermes cut this diff short" and still offer Restore this file. Paths with spaces or quotes (git's `"a\tb"` quoting) are kept verbatim for the request and shown unquoted; a path that cannot be parsed back is not offered for per-file restore.

### Controllers

- `CheckpointsController` (one per chat thread, created by `ChatController.checkpointsIn(thread)` like `usageIn`): holds the list, the open checkpoint's changes (in memory only), the restore operation and its result. Owner scope `(connection, runtimeSessionId, profile)` as `UsageScope`; late answers after a scope change are dropped; everything is cleared on sign-out, profile switch, thread change, connection change and App Lock. It loads the list when the Activity panel opens (not at chat open, not on every turn) and re-reads after a turn ends while the details are open, after a restore, and on resume.
- `ContextController`: shares `SessionUsageController`'s snapshot for the Row (`context_used/max/percent/estimated`) and loads `session.context_breakdown` only when the details open, after a turn, after `compacted` and after a compress. It owns the compress operation, a `CompressionSuggestion` decision (below) and the last compress outcome line.
- Both hold at most one in-flight request per kind, with a 10 s limit for reads (no effect on the socket, as `requestKeepingConnection`) and 90 s for diff, restore and compress; a lapse is `MayHaveHappened`, and the controller **re-reads** (list; usage; chat) instead of sending again.

### Where it appears (no new screen)

`BoundActivityPanel` gets two sources. Tiers (`activity_tier.dart`, `ActivityKind.context` and `.checkpoints`, both `reference`; a compress or restore in flight is shown as `working` for its duration only, as a plain "Compressing the conversation…" / "Restoring files…" line, and settles into a reference note):

| Item | Panel section | Tier |
|---|---|---|
| Context row (bar, %, "about 124k of 200k") | This session → first | For reference |
| Compression suggestion (85%+, idle, once) | Same row, expanded one line | For reference |
| Compressing… / Restoring… | Now | Working |
| File checkpoints row | This session | For reference |
| Outcome note ("Restored 3 files") | This session | For reference |

Nothing is Needs-you: neither feature blocks the agent. Neither adds the Activity button's waiting dot, a strip line, a notification, a badge, a widget or an App Intent.

Navigation inside the panel is a push: row → **Context details** (one page) and row → **Checkpoints** → **Changes** (file list) → **One file**. On a phone the panel is a detent sheet and the pages push inside it with a Back button; on iPad and wide Android/desktop the inspector docked at 760 pt pushes the same pages and shows Back; on a Mac the inspector does the same and View > Back (⌘[) goes back. Confirmations use `showAdaptiveSheet`: a bottom sheet on a phone, a dialog on a Mac and wide windows (never a Mac bottom sheet).

### Offering compression at the right moment

- The server compresses by itself at a threshold the app cannot see, so most chats never reach a point where the user must act. Manual compression exists for the cases where that fails or the user wants a fresh, small context.
- The **suggestion** appears on the Context row when all hold: `context_percent >= 85`, the chat is idle (not replying, no request waiting), `compressions` has not changed since the last dismissal, and it has not been shown for this fill. Dismissing ("Not now") or compressing records the `compressions` count and the percent; it shows again only after the context has dropped below 60% and refilled, or after a successful compress followed by a refill. State is in memory per thread. It never shows while the percent is unknown or `context_estimated` is true with `context_source == local_estimate` and the percent is below 95 (a guess does not earn a prompt).
- **No push of any kind**: no dot on the Activity button, no strip, no notification, no sound, no haptic.
- **"Compress conversation…"** also lives in the details page always (idle chats), and in the Mac menu bar as Chat > Compress Conversation… (disabled unless idle; `MacCommand.compress`). The `/compress` slash command keeps working as it does and is unchanged.
- The confirmation (adaptive sheet/dialog) says, in this order: what happens ("Older messages are replaced by a short summary. Recent messages and your instructions stay."), what it costs ("A helper model writes the summary and uses tokens on your account."), what it cannot do ("This can't be undone."), and what the user sees ("The chat reloads and shows the summary where the older messages were."). Optional "Focus on" (Advanced, one line): "Keep details about…". Buttons: Cancel (default), Compress. Not red: it loses detail but not user data; the server keeps the archived rows.
- After it: a transcript line (a `LocalNotice` message kind the transcript already has for command output) "Conversation compressed · 42 → 9 messages · about 120k → 30k tokens"; counts only. `NothingToCompress` says "There isn't enough to compress yet." `WouldNotShrink` says "Compressing wouldn't make this chat smaller." `CompressionAborted` says "Hermes couldn't write the summary, so nothing changed." with the server's reason shown only as a fixed category. `fallbackUsed` adds "Hermes couldn't summarize the older messages, so it dropped them."

### Restore flow and its words

- Checkpoint row action menu: "See changes", "Restore all files…". Changes view per-file: "Restore this file…".
- *Restore this file* confirmation: title "Restore this file?", body "`<file name>` goes back to how it was <relative time>, before <reason>. Changes you made to it since will be overwritten. Hermes saves the current version first, so you can go back. Your chat isn't changed." Buttons Cancel (default), Restore file. Allowed while the agent works, with the extra line "Hermes is working in this folder right now. It may change the file again."
- *Restore all files* confirmation (only when idle; while replying the action is disabled with "Wait for the reply to finish."), the exact server behaviour, in plain words: title "Restore all files?", body "Files in this folder go back to how they were <time>, before <reason>: N files differ now. Changes you made to them since will be overwritten. Files Hermes created after that stay where they are. Hermes saves the current state first. **This also removes your last message and Hermes' answers after it from this chat.** The chat doesn't track which message a checkpoint belongs to, so only your last message is removed, whichever checkpoint you pick. Other chats in this folder aren't changed, but they see the restored files." Buttons Cancel (default), destructive "Restore all files". N comes from `stat` and reads "some" when the changes could not be read.
- On success: a transcript line "Restored N files · removed your last message"; a result note in the panel ("Hermes saved the previous state as the top checkpoint, “Before a restore”."); the chat is re-read; **the removed message text goes into the composer unsent** (the app held it when the confirmation opened, from the chat's last user message; only if the composer is empty, else it is appended under the draft like a deep-link prompt).
- **Undoing a restore.** The top checkpoint "Before a restore" is a normal checkpoint. Restoring all files from it also removes another last message (server behaviour), so its confirmation shows the same warning and the app does not make it a one-tap "Undo". Restoring one file from it is the safe, chat-free undo. Recommended follow-up, not in this change: a "files only" restore that loops per-file restores from `stat`.
- `RestoredHistoryNotRewound` (5021): "Files were restored, but the chat couldn't be rewound. Your messages are unchanged." and the chat is re-read.
- `MayHaveHappened`: "Hermes didn't answer. The files may have been restored." The controller re-lists and re-reads the chat; it never resends.

### State and failure handling

- Loading: skeleton rows with a label ("Loading checkpoints…", "Reading the changes…"). Empty list on: "No checkpoints yet for this chat's folder. Hermes makes one just before it first edits a file in a turn." Off: "File checkpoints are off on your Hermes server. To use them, turn on `checkpoints.enabled` in its config." (the key is shown, no link to edit anything). Unsupported: row absent. Container refusal: "Checkpoints don't cover this chat's workspace." Old server (no `rollback.*`; or no `session.compress`/`context_breakdown`): row absent, `/compress` still works as before, no error. Offline/disconnected: values stay, marked "Not up to date", actions disabled.
- Partial failure: breakdown unreadable but usage known → Row and bar stay, details show the total and "Couldn't read what fills the context. Try again."
- Permission denied: not a case here (the gateway has no per-method permission); an HTTP 401 follows the normal sign-in rules.
- A profile switch, new chat, thread switch, sign-out or connection change cancels pending reads, drops their answers, and clears diffs and breakdowns. A restore or compress in flight when the app is backgrounded is not cancelled and is re-read on resume. Because the controllers are per thread, leaving the screen does not cancel an in-flight restore; its result lands in the thread's panel.
- App Lock: the rows show only counts ("N checkpoints"), without reasons, file names or diffs; details and diffs are not reachable while locked and are dropped when the lock covers the app; the compress and restore buttons are disabled.
- Conversation windows and the quick panel: no rows (no `checkpoints`/`context` controllers passed), as with the Bot screen card. The Mac menu item acts on the key window only when it has the controllers.

### Telemetry (fixed words, counts and outcomes only; never text, names, ids, URLs, paths, commands, file names, diff text or the focus text)

- Spans: `chat.checkpoints.list` (`outcome`: ok, off, unsupported, failed; `count` bucket), `chat.checkpoints.diff` (`outcome`, `files` bucket, `truncated`), `chat.checkpoints.restore` (`scope`: file, all; `outcome`; `history_removed` bucket), `chat.context.breakdown` (`outcome`), `chat.context.compress` (`outcome`, `focused` bool, `fallback_used`, `before`/`after` message-count buckets, `source`: manual).
- Breadcrumbs: `chat.checkpoints.opened`, `chat.checkpoints.restore_confirmed` (`scope`), `chat.context.opened` (`from`: row, suggestion, menu), `chat.context.suggestion` (`action`: shown, dismissed, accepted), `chat.context.compress_confirmed`.
- Log events once per failure streak: `chat.checkpoints.read_failed`, `chat.context.read_failed` (`kind`). Buckets: 0, 1, 2–5, 6–20, 21+.

### Secrets

No secret is handled. Diffs can contain secrets from the user's files; they follow "Security and privacy" in proposal.md: memory only, no logs, no screenshots-in-telemetry, cleared under App Lock and on close.

### Accessibility

- Rows and buttons 44 pt / 48 dp; text scales to the largest accessibility size and the row wraps to two lines instead of truncating the percentage.
- The meter is not colour-only: the percentage and "about 124k of 200k" are text, and the state word ("Nearly full") appears at 80% and above. The bar has a label "Context, 62 percent used, estimated". Category bars list name and number; the stacked bar is decorative (`ExcludeSemantics`) when the list is present.
- Diff lines carry `+`/`-` characters (already), so meaning is not colour only; a file's diff has a heading "Changes in `<file>`, 12 added, 3 removed". Reduced motion: no animated bar fills.
- A restore or compress result is announced once by outcome words ("Restored 3 files", "Conversation compressed"), never with file names. Focus returns to the row that opened the page.
- Destructive buttons keep their semantic role and the confirmation's default focus is Cancel.

### Decision records

1. **Rows, not a screen.** Both are reference info for the open chat; the Activity panel is where "For reference" lives and nothing here waits for the user.
2. **The restore choices mirror the server**, even though it is clumsy, because the app cannot change it: a checkpoint cannot be tied to a turn, and a full restore always drops one turn. We say so rather than pretend "undo this turn".
3. **No prune.** See Non-goals.
4. **Compress through `session.compress`, not the slash command**, so the result is structured, the busy state is known, and a lost answer can be re-read. The slash command remains.

## Open questions (with recommendation)

1. *Show the archived pre-compression messages?* The REST route can return them (`include_compacted=true`). Recommend: not in this change; the summary is the truth for the model and Hermes' own dashboard shows the compressed view. Revisit with "Earlier messages" if users ask.
2. *Partial compression (`here N`, `--keep N`) and `--preview`?* Recommend later; the focus field covers the common need, and the preview's cost (does it call the summarizer?) is unverified.
3. *Does `session.compress` run on the helper model's price?* Yes, the `compression` auxiliary slot, else the main model; the confirmation says "uses tokens on your account" without a number, because the app cannot know it.
4. *Is 85% right for the suggestion?* The server's own terminal UI turns the meter red above 80 and critical at 95; Hermes auto-compresses at 50 to 85%. Recommend 85. A blocked automatic compression is detectable only by parsing a warning's text, which the app does not do.
5. *Files-only restore for a whole checkpoint.* Needs N per-file calls, each making its own pre-restore checkpoint (and so pushing older ones out of the 20). Recommend a follow-up that restores by file list and a single note, after seeing real use.
6. *Should "Restore all files" be offered for checkpoints other than the newest?* The chat rewind is the same single turn either way, which is wrong for older ones. Recommend offering it for every checkpoint but wording the warning as above, and keeping per-file restore as the primary action. If testers find it misleading, restrict it to the newest non-"Before a restore" checkpoint.
7. *`rollback.diff` has no per-file parameter and cuts at 4,000 characters.* Large changes can show only the first files' diffs. Recommend living with it and saying so; a REST route for a full diff would be a Hermes change.
8. *Folder vs chat scope.* Checkpoints are shared by all chats of a folder. Recommend one sentence in the confirmation (included) and no per-chat filter.
