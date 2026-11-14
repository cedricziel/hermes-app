# Design

## Context

Read from the code at `origin/main`. Working items already live only in the Activity panel (`BoundActivityPanel`: Now holds the Bot screen card, the session status card and live mixture-of-agents progress; Plan the `TodoPlanCard`). Two differences from the spec: `BoundActivityPanel` lists process output cards under This session although the spec puts process output in Now, and nothing outside the panel says that Hermes is busy. `MacChatToolbar` takes a `subtitle` string built by `ChatScreen._toolbarSubtitle()` (profile · model); `ConversationWindowScreen._subtitle()` builds its own the same way for `ConversationWindowToolbar`, a different widget. The chat header is `ChatHeader` (not on macOS, where `MacChatToolbar` is the header) and `ChatThreadView` already draws `BotChatBanner` below it. `chat-activity-needs-you` deletes the strip, so after it nothing sits between header and transcript.

Backend contract: none new. The sources are the frames the app already consumes (`status.update`, `session.control.update`, `todo.updated`, `agent.terminal.output`, `moa.*`, `session.resume_progress` in `openrpc/hermes-gateway.openrpc.json` at the commit in `openrpc/HERMES_REF`).

## Goals / Non-Goals

**Goals:**

- One `WorkingSummary` (newest sentence, counters) computed once and drawn by the line or the Mac subtitle.
- Something between the header and the transcript only while Hermes is working, and never taller than one touch target.

**Non-Goals:**

- Changing what the panel shows for Working items beyond moving process output to Now.

## Decisions

- **Newest sentence.** `WorkingSummary` keeps the latest non-empty sentence by arrival across sources: a `status.update` text; "Running <n> processes" or "Process running" from process output (`agent.terminal.output` reports chunks, not a command, so no command text is invented); "Asking <n> models" or "Combining answers" from mixture-of-agents; "Restoring the chat…" from resume progress; the goal's text from control state. When the newest source clears, the next newest still active takes over. A plan with an open task and no other sentence reads "Working on the plan". Alternative: a fixed priority order. Rejected: "newest" matches what just happened.
- **Sources that never feed the line.** Needs-you items (docked above the composer), For reference items and the Bot screen card. The Bot screen is a standing display, not a turn's activity, and has no sentence.
- **Touch target, not a thin strip (correction).** The first proposal fixed the line at 32 pt and 36 dp. It is a tappable control, so the settled target rule applies: 44 pt on Apple, 48 dp on Material and desktop Material. Single-line `Text` with end ellipsis, counter chips at the trailing side, constant height while the sentence changes; it appears and disappears with a short size transition (none with reduced motion) so the transcript does not jump on every sentence change.
- **At most two counters, goal text only (corrections from the design pass).** Three chips left about 60 pt for the sentence at 390 pt, and "Goal: … (turn 3 of 20)" lost its tail. The line shows the two counters that changed last (the rest are in the panel), and the goal sentence is the goal's text alone (the turn count stays in the panel).
- **Largest text size.** The height follows the text scale and stays constant at a given scale. From a text scale of 1.5 the line has two rows, the sentence over the (at most two) chips, so neither is cut to nothing. Text size is never capped.
- **Placement and the inspector.** On phones `ChatThreadView`'s `header` is null (`chat_screen_layout.dart`), so the line is the first child of the thread view's column, under the header's divider where there is one, above `BotChatBanner`. While the inspector is docked or drawn beside the chat it lists the same items, so the line is hidden then (docked beside the chat, or drawn over it below 760 pt); on a phone the sheet covers the chat and the line stays under it.
- **Accessibility.** The line is one button, not a live region: sentence changes are not announced. Its name is "Hermes is working: <sentence>, plan 2 of 5, 1 process running. Opens activity." (counters only when known). The progress indicator is decorative and static under reduced motion. Status is the words plus the indicator, never colour alone.
- **Stamping (arrival order).** The state classes carry no arrival time, so the controller gives each source a stamp for `WorkingSentence.at` and `WorkingCounter.at`: a monotonic per-source int (not a `DateTime`). A stamp is taken only when that source's sentence or counter value actually changes (a changed goal text, not every `session.control.update`, heartbeat or loop tick), and a source keeps its stamp until it clears. Sentence to source: `status` is the newest `status.update` text; `goal` is the goal's text, and the loop and heartbeat texts are their own sources with their own stamps; `processes` is the count of process cards where `!closed`, zero meaning no sentence; `combiningAnswers` is a live mixture-of-agents card whose phase is "Aggregating", `askingModels` any other live card (its total as the count, when reported); `restoring` is `resume != null` and not done. A counter that repeats the sentence is dropped by `WorkingSummary` (processes under the processes sentence, references under the asking and combining sentences).
- **Constant height, also without counters.** From a text scale of 1.5 the line keeps its blank chip row when no counter is known. That is on purpose: the height must not change while counters come and go.
- **macOS subtitle.** `MacToolbarSubtitle` is passed to `MacChatToolbar` and `ConversationWindowToolbar` through their `subtitleBuilder`, which wraps the drawn subtitle and runs only while `subtitle` is not null, so PR 2 passes a non-null `subtitle` ("profile · model") while working. `MacToolbarSubtitle` draws "profile · model" and, while working, " · <sentence>" after a 12 pt spinner glyph. The status part `Flexible`-truncates first so profile and model keep their width. Conversation windows build their own summary from their own chat, so one window's status never shows in another's. The quick panel draws no Working status.
- **Process output in Now.** `BoundActivityPanel` moves the process cards (and the omitted-cards note) from This session to Now, as the `chat-activity` spec says; finished process output stays in Now until the process output state drops it.
- **Observability.** `chat.activity.opened` is recorded where `_toggleActivity(source: …)` is called; the line passes `source: 'line'` (the toolbar button passes `button`).

Platforms: iOS, Android, macOS, Windows, Linux. No native, entitlement, manifest or Xcode change.

## Risks / Trade-offs

- [Fast status changes make the line flicker] → The sentence changes in place without resizing; only appearance and disappearance animate.
- [A long goal text dominates the Mac subtitle] → The status part truncates first; the full text is in the inspector.
- [A 44 pt line costs transcript height on a small phone] → It exists only while Hermes works and at that moment the transcript is following the reply anyway.
- [Moving process output to Now changes panel tests] → Update them in the same commit; they assert the section, not the card.
