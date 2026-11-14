# Tasks

Five PRs. Each is reviewable alone and leaves the app working; nothing is drawn until PR 2 and PR 3 wire their rows. PR 2, 3 and 4 all edit `ActivityKind` and `BoundActivityPanel`: merge them in order. Depends on `chat-activity-panel` (already merged) and builds on `session-usage` and the branch feature's `undoLastTurn`/`branchThread` transport helpers.

## PR 1 `feat(chat): checkpoint and compression repositories` (~500 lines, no UI)

- [ ] 1.1 Record fixtures from the Hermes source tests and a real backend: `rollback.list` (on, off, empty), `rollback.diff` (normal, cut at 4,000, empty-failure), `rollback.restore` (success with `history_removed`, each `success:false` error, 4009, 5021), `session.compress` (compressed, noop, aborted, refused_would_grow, fallback_used, lock_held, pending, 4009), `session.context_breakdown` (eight categories, empty before agent build). Add them under `test/fixtures/` and to `test/real_backend_contract_test.dart` (skips without `HERMES_DEV_URL`; a scripted-model chat with `checkpoints.enabled` on).
- [ ] 1.2 Write failing tests for `parseStat`, `parseDiff` (renames, binary, quoted paths, spaces, exactly-4,000 cut, file in stat but not in diff) and for lenient row parsing (missing hash skipped, unknown reason, missing timestamp).
- [ ] 1.3 Implement `CheckpointsRepository` and `ContextRepository` with the sealed results in design.md, over new `ChatTransport` methods in `HermesGatewayTransport` (reads and the breakdown through the owned-session path extended from `session.usage`; `_commandRuntime` only for an explicit tap, restore or compress; method-not-found to `Unsupported`, 90 s limits, 4001 handling as in `branchThread`); a transport without them answers unsupported. Verify 1.2 passes.
- [ ] 1.4 Read `context_source` in `UsageSnapshot`; feed `session.info`'s `usage` and `status.update` kinds `compressing`/`compacted` through the event mapper (new wording, usage re-read; this changes visible status text, and a test shows wait-tier behaviour is unchanged); extend `test/gateway/gateway_contract_test.dart` and `event_mapper_test.dart`.

## PR 2 `feat(chat): context meter and compression` (~600 lines)

- [ ] 2.1 Claude Design pass for Context row, Context details and the compress confirmation from `docs/design-briefs/chat-checkpoints-and-context.md`.
- [ ] 2.2 Catalog first: plain-model `ContextRow` (unknown, 12%, 62%, 82%, 97%, estimated, stale, suggestion shown, compressing), `ContextDetails` (eight categories, loading, breakdown failed, unsupported, long labels), `CompressConfirmation` (default, with Focus open, busy), `CompressionOutcomeNote` (each result). Phone and desktop, both themes, Apple and Material, largest text size. `flutter test test/widgetbook_test.dart` passes.
- [ ] 2.3 Write failing tests for `ContextController`: shares the usage snapshot; one breakdown read per trigger (open, turn end, compaction, compress); late answers dropped on scope change; every `CompressionResult` outcome; lost answer re-reads and never resends; suggestion rules (85, idle, estimate, dismissed, refill below 60, per thread, cleared by App Lock); focus text refused when it starts with `-` or `here`.
- [ ] 2.4 Implement `ContextController`, `ChatController.contextIn(thread)`, `ActivityKind.context`, the Activity panel row and details page, the confirmation and the outcome line (a local-only row with a per-thread overlay that survives the re-read), and Chat > Compress Conversation… (`MacCommand.compress`, idle only). Verify 2.3 passes.
- [ ] 2.5 Telemetry spans, breadcrumbs and failure-streak log from design.md with a test that no attribute holds text, a path or the focus.

## PR 3 `feat(chat): file checkpoint list and changes` (~800 lines)

- [ ] 3.1 Claude Design pass for the checkpoint page, changes view, one-file view, the two confirmations and the off/empty/unreadable states.
- [ ] 3.2 Catalog first: `CheckpointRow` and `CheckpointList` (several, one, empty, off, loading skeleton, failed, stale), `ChangedFilesList` (3 files, 40 files, renamed, binary, cut short), `FileDiffView` over `ToolDiffBody` (short, long horizontal scroll, cut short, binary), `RestoreFileConfirmation` (idle, agent working), `RestoreAllConfirmation` (N known, N unknown, destructive), result notes. Phone and desktop, both themes, largest text size. Catalog test passes.
- [ ] 3.3 Write failing tests for the read half of `CheckpointsController`: loads on panel open and after turn end/restore/resume only; stored chat without a runtime shows "Tap to check" and resumes only on tap; off-with-edits vs off-without-edits; diff read only for an opened checkpoint; diff cache cleared on close, thread, profile, connection, sign-out and App Lock; full hash always sent.
- [ ] 3.4 Implement the read half, `ChatController.checkpointsIn(thread)`, `ActivityKind.checkpoints`, the list, changes and one-file pages (read-only; no restore buttons yet). Reuse `ToolDiffBody` for the single-file view without the tool card frame. Verify 3.3 passes.
- [ ] 3.5 Telemetry for list and diff with the no-content test.

## PR 4 `feat(chat): restore files from a checkpoint` (~700 lines)

- [ ] 4.1 Catalog use cases for the two confirmations and results were built in 3.2; wire them here.
- [ ] 4.2 Write failing tests for restore: restore-all disabled while replying; 4009, 5021, 4001, container refusal, nested repositories, stale checkpoint, name that cannot be restored alone; lost answer (re-list and re-read, no resend); `history_removed` 0 and > 0; the removed prompt chosen with `isPrompt` and placed in the composer under an existing draft; send queue held; "Before a restore" present or missing after re-list; not cancelled on backgrounding or switching chats.
- [ ] 4.3 Implement the restore half and the composer hand-back; verify 4.2 passes.
- [ ] 4.4 Telemetry for restore and a test that fails if a file name, path, hash, reason or command reaches any record.

## PR 5 `test(chat): checkpoint and context workflow, docs` (~300 lines)

- [ ] 5.1 Workflow test (`test/workflows/`) for the whole flow on phone and desktop, light and dark: panel opens, Context row, details, suggestion at 86%, compress, outcome line; checkpoints list, changes, one file, restore one file, restore all, composer hand-back; an old server shows neither row. Look at the screenshots.
- [ ] 5.2 Add to the existing App Lock, sign-out, profile-switch and conversation-window tests that neither row leaks or appears.
- [ ] 5.3 Update `CLAUDE.md` (Chat section: both features, the server facts that surprised us), `openspec/specs` through archive, and the `verify-in-app` skill with how to run a backend with `checkpoints.enabled`.

## Verification on a device (listed apart)

- [ ] V.1 Real backend with `HERMES_TUI_CHECKPOINTS=1`, a scripted chat that edits files in two turns: confirm list, reasons, `stat` and a diff longer than 4,000 characters, file restore, full restore (files and last message gone, composer filled), the "Before a restore" entry, and that a second chat in the same folder sees the same list.
- [ ] V.2 Same backend: a chat with enough context to pass 85% (long scripted turns or a small-window model) – suggestion once, compress, outcome line, chat reload, `include_compacted` default view, usage drop.
- [ ] V.3 Turn checkpoints off: row absent without edits, "off" with edits. Old server (before `rollback.*`): nothing drawn.
- [ ] V.4 iPhone with VoiceOver and the largest text size; Mac with keyboard only; Android with TalkBack; App Lock on while a diff is open.
