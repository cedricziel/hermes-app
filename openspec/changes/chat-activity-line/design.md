# Design

## Context

After `chat-activity-needs-you`, `ChatThreadView`'s strip holds only Working cards: `SessionStatusCard` (status waits, control state, reclaim already moved, resume progress), `TodoPlanCard`, `ProcessOutputCard`s and `MoaProgressCard`s. The Activity panel from `chat-activity-panel` already lists them under Now and Plan. `MacChatToolbar` takes a `subtitle` string built by `ChatScreen` (profile · model); conversation windows build theirs the same way.

## Goals / Non-Goals

**Goals:**

- One `WorkingSummary` (newest sentence, counters) computed once and drawn by the line or the Mac subtitle.
- Remove the strip and its parameters from `ChatThreadView`, so the three hosts pass activity only to the panel source and the dock.

**Non-Goals:**

- Changing what the panel shows for Working items.

## Decisions

- **Newest sentence.** `WorkingSummary` keeps the latest non-empty sentence by arrival across sources: a `status.update` text; "Running <n> processes"/"Process running" from process output (no command text is reported by `agent.terminal.output` beyond its chunks, so no command is invented); "Asking <n> models"/"Combining answers" from mixture-of-agents; "Restoring the chat…" from resume progress; the goal's own text from control state. When the newest source clears, the next newest still active takes over. Alternative: a fixed priority order. Rejected: "newest" matches what just happened and what the design shows.
- **Fixed height.** The line is 32 pt on Apple, 36 dp on Material, single-line `Text` with ellipsis, counters as chips on the trailing side; it is inserted and removed with a short size transition so the transcript does not jump on every sentence change.
- **Mac subtitle.** `MacChatToolbar` gets `status: WorkingSummary?`; it draws "profile · model" and, when present, " · " plus a small progress indicator and the sentence, in a `Row` where the status part is `Flexible` with ellipsis so profile and model keep their width.
- **Removing the strip.** `ChatThreadView` loses `notices`, `sessionState`, `sessionUsage`, `connectorOperations`, `connectionOperations`, `billingVerification`, `todoPlan`, `acknowledgement`, `sideResults`, `moaProgress`, `processOutputs` and their callbacks; they move to the panel source built in `chat_thread_bindings.dart`. Strip-only wrappers (the 280 pt scroll box, `_connectorCards`) are deleted.

Platforms: iOS, Android, macOS, Windows, Linux. No native, entitlement, manifest or Xcode change.

Invariants touched: telemetry only through `chat.activity.opened` gaining `source: line`, recorded where the line's tap opens the panel; fixed values, no status text.

## Risks / Trade-offs

- [Fast status changes make the line flicker] → The sentence changes in place without resizing; only appearance and disappearance animate.
- [A long goal text dominates the Mac subtitle] → The status part truncates first; full text is in the inspector.
- [Removing many `ChatThreadView` parameters touches three hosts] → They already go through `chat_thread_bindings.dart`; one place changes.
