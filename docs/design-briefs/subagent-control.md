# Design brief: subagent control

Change: `openspec/changes/subagent-control/`. This brief is for the visual design pass ("Hermes App" design system) and the Widgetbook use cases that follow it. The behaviour is specified in the change's specs; this file says what each screen is for, what the user must see first, which existing pieces to reuse, and the exact words.

## Design (done)

Claude Design canvas "Hermes: Subagent control", built on the Hermes App design system: https://claude.ai/artifact/9bCTgyReK3Pe71SbPkjcXj (private; ask its owner for access). 57 artboards in seven rows:

- **Kits:** the panel content, the agent detail (one `state` prop covers all 29 detail states) and the program cards. These are the plain-model widgets listed in design.md decision 6.
- **Activity panel on iPhone:** many agents (Bot screen card, three running, status row, four ended, the overflow line, a process card), none running, one agent with the row pressed, nested agents, every row state (including reduced motion and a long goal), the iOS swipe, the iOS long press.
- **Main views:** iPhone dark (panel; detail after a queued note), largest accessibility text (panel; detail), iPad detail in the docked inspector, Mac inspector with the row's context menu, Mac detail beside the chat, a Mac window under 760 pt with the inspector over the chat, Android panel and detail.
- **Agent detail and live output:** streaming and truncated, reading output, no output yet, paused by a selection, refresh failed, output never available, ended (finished, failed delegation, stopped, unknown), older server, offline.
- **Stop:** the confirmation on iPhone, Android and Mac; stop in flight, accepted, had already finished, lost answer, failed, refused (can't be controlled here), server can't stop.
- **Redirect:** note typed, sending, sent (queued), refused, lost answer, failed, over 4,000 characters, arrived too late, agent ended with the note not sent, server can't take notes.
- **Transcript and programs:** the transcript's agent card with a chevron per row; program cards in every state; a running card expanded with Stop program; its confirmation; every stop outcome.

Every artboard was rendered locally in headless Chrome against the design system's own bundle and looked at; the claude.ai viewer and real devices were not checked. Where this brief and the canvas differ, the sections below have been brought in line with the canvas.

Decisions taken in the design pass:

- **Row lines.** Line 1: the goal (two lines, ellipsis). Line 2, for every state: `<State word> · <run time> · <N tools>` ("Running · 1 min 12 s · 4 tools"; no tool count while it is 0). Line 3, only while running: `<last tool> · <preview>` ("read_file · go.sum"), one line with an ellipsis. Then the chevron in a 44 pt (48 dp) target. The whole row is the target.
- **Glyphs differ in shape, not only colour:** Running is the platform spinner (`WorkingDot`; a still filled dot with reduced motion), Starting a hollow ring, Finished a filled check (success colour), Failed a filled cross (error colour), Stopped a filled stop square (text colour), Ended a neutral dash (muted).
- **Nesting** is drawn only inside a section (16 pt per level, three levels; a fourth sits at the third). A child whose parent sits in the other section (a running parent with a finished child) is drawn at the top level of its own section.
- **Detail header:** iOS shows "‹ Activity" on the left, the title "Agent" centred and, in the phone sheet, the sheet's close button on the right. Android shows the back arrow, "Agent" on the left and close. Mac and the inspectors show the chevron alone (tooltip "Back to Activity") and no close.
- **Facts:** the state glyph and word, then "1 min 12 s · 4 tools"; while running a second line with the current tool. Ended states add one plain sentence under the facts.
- **Output box:** monospaced, 12 pt on iPhone and 13 pt elsewhere, on the surface-high colour with a border. Lines wrap with a hanging indent so wrapped text lines up under the message column after the 19-character `HH:MM:SS role     | ` prefix; there is no sideways scrolling. The box follows the end and its top edge fades out to show there is more above. It is about 290 pt tall in the phone sheet and 230 pt in an inspector, which scrolls as a whole.
- **Paused:** the selected line keeps its highlight; a pill sits over the bottom of the box: pause icon, "Paused", then the "Jump to latest" button (44 pt tall).
- **Outcomes are `Banner`s.** Stop outcomes sit under the facts line; note outcomes sit between the helper text and Send to agent. Success tone for "Stopping…", "This agent had already finished." and "Sent."; warning tone for the lost answers, "This agent isn't taking notes now." and "Your note arrived after the agent finished."; error tone for the failures. Long sentences are split into a bold title and a detail line (see the copy below).
- **Can't be controlled here** and **offline** use a neutral info note (surface-high box with the info icon), not a warning: nothing failed.
- **Stop agent:** tinted destructive button (the error colour on a 12% tint of itself, stop icon, 44 pt / 48 dp, 28 pt on the Mac), trailing at its natural width under a divider, "Programs it started keep running." under it. It uses the error token, not the system red, so the label passes AA on its tint in both themes. While a lost stop is being checked it is disabled; once a stop is accepted, Stop and the note section both go (a note can no longer reach an agent that is stopping).
- **Send to agent** is the only filled button on the screen: full width in the iPhone sheet, trailing at its natural width in inspectors and on Android. Disabled, it uses the hover fill and the muted text colour.
- **Agent ended with text in the field:** the section keeps its title; the text moves into a dashed read-only box headed "Not sent", with an outlined Copy button.
- **Largest accessibility text:** a row stacks (glyph and chevron on one line, then the goal and lines at full width, nothing clamped); the detail's bar text keeps its normal size, as iOS bars do; output text scales to at most 200% and drops the hanging indent; buttons go full width and wrap their label; the note field grows to five lines.
- **Mac:** inspector 340 pt wide under the toolbar; rows use the Mac type ramp; buttons are pointer sized (28 pt). Below 760 pt the inspector lies over the chat behind a scrim, so the composer cannot take focus while the note field is open. The row's context menu: Show Details, divider, Stop Agent… (destructive).
- **Material confirmation:** two text buttons (Cancel, then "Stop agent" in the error colour), no filled button. Apple: the system alert with Cancel bold and "Stop agent" red.
- **Program cards:** command in monospace on line 1 (two lines, "…" at Hermes' 200-character cut), state glyph, then `<State> · <run time>`. A card Hermes doesn't list (only frames) gets no state glyph, so it never looks like it ran or succeeded. Expanding shows the output and, while running, "Stop program" as the same tinted destructive button, trailing. Stop outcomes are banners inside the card; "Couldn't stop the program." brings Stop program back.

Corrections where this brief did not work:

- Row line 2 in Screen 1 put the state word only on ended rows and let a long tool preview push the run time out of view. Every row now starts line 2 with the state word, and the current tool moves to its own third line (see the decision above). This also keeps "state is never colour only" true for running rows.
- "44 × 44 pt on Apple platforms" now reads 44 pt on iPhone and iPad (touch); Mac controls are pointer sized (at least 28 pt), as everywhere else in the app's Mac UI. Rows are taller than 44 pt on every platform anyway.
- The brief had no offline state. Offline keeps the last output and any typed note, shows the info note, and disables Send to agent and Stop agent rather than letting them fail.
- The design system's `AlertDialog` draws no destructive action on Material, so the Android confirmation in the canvas is built from `Sheet`; in the app `showConfirmDialog` already does this.

Copy added by the design:

- Banner titles and details: "Stopping…" / "The agent stops after the step it's on."; "Couldn't confirm the stop." / "Checking…"; "Couldn't stop the agent." / "Try again."; "Sent." / "The agent gets it after its current step."; "Couldn't confirm the note was sent." / "Sending it again may deliver it twice."; "Couldn't send the note." / "Try again."
- Offline: "You're offline. This is the last output read. Stop and notes work again once Hermes is back."
- Paused pill: "Paused" plus the button "Jump to latest" (as before); the screen-reader name of the note field: "Note to this agent"; the program stop button while in flight: "Stopping…".

## The job

While Hermes answers, it can hand parts of the work to helper agents and start programs in the background. The person wants to know what those helpers are doing, and to step in when one goes the wrong way: stop it, or tell it what to do differently, without stopping the whole reply.

Words: the UI says **agent** (not "subagent", "child", "delegation" or "task") and **program** (not "process"). "Redirect" is the action of sending an agent a note; the field itself talks about a **note**. "Stop" is used for both agents and programs. Never "interrupt", "steer", "kill" or "spawn".

## Where it lives

Everything is in the chat's existing **Activity panel**, opened with the Activity button in the chat header (toolbar button on the Mac, View > Inspector ⌥⌘I). No new screen, tab, window or menu bar item.

|              | iPhone, Android phone                                                                                                                                                                                                                                          | iPad, Windows, Linux (≥ 760 pt)                                                  | Mac                                                                                                          |
| ------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| Panel        | Detent sheet (iOS) / modal bottom sheet (Android), opens at medium height                                                                                                                                                                                      | Inspector beside the chat; over the chat below 760 pt                            | Inspector beside the chat; over it below 760 pt. Never a bottom sheet                                        |
| Agent detail | Pushed inside the sheet with the platform push; the sheet grows to full height                                                                                                                                                                                 | Replaces the inspector's content; back chevron at top left                       | Same as iPad; Escape goes back, then closes an overlay inspector                                             |
| Row actions  | iOS: swipe from the trailing edge reveals red "Stop agent" (opens the confirmation); long press lists Show details, Stop agent…. Android: tap only, on purpose: Material has no standard trailing swipe for a destructive action, and Stop lives in the detail | Pointer hover highlights the row; right click menu on Windows/Linux not required | Right click: Show Details, Stop Agent… (title case on the Mac; opens the confirmation); hover highlight      |
| Confirmation | Alert (Cupertino on iOS, Material dialog on Android)                                                                                                                                                                                                           | Dialog                                                                           | Mac alert sheet style dialog (`AppAlertDialog`), Cancel is the default button (Return), Stop agent plain red |
| Send a note  | Button below the field                                                                                                                                                                                                                                         | Button; Control-Enter                                                            | Button; ⌘Return. Return adds a line                                                                          |

Mac conversation windows behave like the Mac main window. The Mac quick panel has no Activity panel: its transcript card stays read-only.

## Components to reuse

- `ActivityPanel` and its section titles (NOW, PLAN, THIS SESSION), the empty `StateMessage`.
- Row: the visual weight of `SessionStatusCard` / `MoaProgressCard` rows in the panel, not a heavy card. Status glyph from `ToolCallStatusIcon` (running, done, failed, stopped); the running indicator is `WorkingDot` (still when reduced motion is on). Durations with `formatToolDuration`.
- Indented nesting as in the transcript's `SubagentGroupCard` (16 pt per level, max three levels drawn, deeper ones at the third).
- Detail header: `NamedIconButton` back chevron with label "Activity" (iOS shows the word, other platforms the chevron with tooltip "Back to Activity").
- Output: `SelectableText` in the app's monospace style inside a bounded scroll area, the same treatment as the expanded `ProcessOutputCard` (max height about 45% of the detail; it grows on a tall window, never past the note field).
- Confirmation: `showConfirmDialog` (destructive, Cancel default).
- Row actions: `RowActions` (iOS swipe and long press, Mac context menu, VoiceOver custom actions).
- Note field: a plain bordered multi-line text field (`AppDialogTextField` styling on Apple platforms, outlined `TextField` on Material). **Not** `ChatComposer`: no attach button, no model pill, no microphone, no round send button.

## Screen 1: Activity panel with agents

**Purpose:** see at a glance which agents are working and which are done.

**Hierarchy:** Under NOW, the Bot screen card stays first, running agents follow it (oldest first), then the status and mixture-of-agents rows. Under THIS SESSION, ended agents come before process cards and the other reference items, newest first.

**Row content, left to right, top to bottom:**

1. Status glyph (running spinner, hollow ring for Starting, check, cross, stop square, or a neutral dash for Ended).
2. Goal, body text, at most two lines, ellipsis at the end.
3. Secondary line, subtle text, one line, for every state: the state word, the run time and the tools used ("Running · 1 min 12 s · 4 tools").
4. While running, a third subtle line: `<last tool> · <what it's doing>` (e.g. "read_file · src/main.go"), one line with an ellipsis.
5. A trailing chevron (disclosure) on every row.

**State words:** Starting, Running, Finished, Failed, Stopped, Ended.

**Overflow line** under the ended rows: "12 earlier agents not shown".

**Empty:** the panel's existing empty state is unchanged. Agents never add their own empty state.

**Old server:** rows look the same; the detail is thinner (see Screen 2, old server).

## Screen 2: Agent detail

**Purpose:** understand what one agent is doing and decide whether to step in.

**Hierarchy (top to bottom):**

1. Header: back control "Activity"; title "Agent".
2. Goal, full text, title style, selectable.
3. Facts line: state glyph and word, run time, "4 tools", last tool. For a nested agent: "Started by another agent".
4. **Recent output** section: the detail's main content. Section title, then the monospaced output box. Under the title, a subtle note when truncated: "Showing the latest output".
5. **Redirect this agent** section (only while running and accepting notes): see Screen 3.
6. Secondary action, while running: **Stop agent**, a tinted (not filled) destructive button, trailing-aligned at its natural width, after the output and the note section, with the subtle line "Programs it started keep running." under it. Never in the header, never next to Back.
7. **What it delivered** (only once ended): the summary in body text, selectable; for a failed delegation the error under "What went wrong".

Reading is the default job of this screen: there is no filled primary button. Send to agent is the only primary inside the note section.

**States and their copy:**

| State                                     | What changes                                                                                        | Copy                                                                                           |
| ----------------------------------------- | --------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| Loading output (first read)               | Output box shows a one-line progress row                                                            | "Reading output…"                                                                              |
| No output yet                             | Output box replaced by subtle text                                                                  | "No output yet"                                                                                |
| Output truncated                          | Note under the section title                                                                        | "Showing the latest output"                                                                    |
| Output read failed                        | Subtle line under the box, last text kept                                                           | "Couldn't refresh the output."                                                                 |
| User selected text or scrolled up         | Refresh holds the shown text; pill above the box's bottom edge                                      | "Paused" · "Jump to latest" (button)                                                           |
| Output never available (30 s)             | Output box replaced by subtle text                                                                  | "Output isn't available here."                                                                 |
| Can't be controlled here                  | Stop, note section and output removed; info banner                                                  | "Hermes doesn't let this device stop or redirect this agent. It keeps running."                |
| Stop in flight                            | Stop button shows a spinner, disabled                                                               | "Stopping…" (button label)                                                                     |
| Stop accepted                             | Banner under the facts line; Stop and the note section gone                                         | "Stopping… The agent stops after the step it's on."                                            |
| Already finished (confirmed by a re-read) | Banner                                                                                              | "This agent had already finished."                                                             |
| Stop unconfirmed                          | Banner, warning style; Stop disabled while the list is re-read                                      | "Couldn't confirm the stop. Checking…"                                                         |
| Stop failed                               | Banner, error style, button back                                                                    | "Couldn't stop the agent. Try again."                                                          |
| Server can't stop                         | Button removed, one-time line                                                                       | "This server can't stop agents."                                                               |
| Ended: finished                           | State "Finished", controls gone, line                                                               | "This agent has finished. Stop and notes no longer apply."                                     |
| Ended: failed                             | State "Failed", line                                                                                | "This agent failed. Stop and notes no longer apply."                                           |
| Ended: stopped                            | State "Stopped", line                                                                               | "This agent was stopped."                                                                      |
| Ended: unknown                            | State "Ended", line                                                                                 | "This agent is no longer running."                                                             |
| After ending                              | Output section title becomes "Last output"; no refresh                                              |                                                                                                |
| Failed delegation                         | No output section; "What went wrong" with the error                                                 |                                                                                                |
| Old server (no tail)                      | No output section at all                                                                            |                                                                                                |
| Old server (no stop, no notes)            | No button, no note section, no error                                                                |                                                                                                |
| Offline (no connection to Hermes)         | Last output kept; info note under the facts; Send to agent and Stop agent disabled; typed note kept | "You're offline. This is the last output read. Stop and notes work again once Hermes is back." |

**Announcements (screen reader):** only the state word when it changes ("Finished", "Stopped"), politely, once.

## Screen 3: Redirect this agent (inside the detail)

**Purpose:** tell this one agent to change course without stopping it and without writing in the chat.

**How it must not be confused with the chat composer:** it sits inside the agent's detail under its own section title; it names its recipient; its button says who gets it; it has none of the composer's controls (no attach, model pill, microphone or round send button). Beside a wide inspector the composer stays visible and untouched; in the phone sheet at full height and in a Mac inspector drawn over a narrow window the composer is hidden, so the note field is the only text field on screen.

**Copy:**

- Section title: "Redirect this agent"
- Recipient line, subtle: "To: <goal, one line, ellipsis>"
- Placeholder: "Tell this agent what to do differently"
- Helper under the field: "Goes only to this agent, after the step it's on. It isn't added to the chat."
- Button: "Send to agent" (disabled while blank, over 4,000 characters or sending; spinner while sending)
- Counter under the field from 3,500 characters: "3,612 / 4,000"; red over the limit.
- The field may hold secrets: autofill, autocorrect, suggestions and keyboard learning are off (as the sudo password prompt does). It is not obscured.

**Outcomes:**

| Outcome                            | Field                                           | Copy                                                                                                                           |
| ---------------------------------- | ----------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| Queued                             | Clears                                          | "Sent. The agent gets it after its current step." Then "Your notes" list below with the sent text, subtle, each with time sent |
| Rejected                           | Keeps text                                      | "This agent isn't taking notes now."                                                                                           |
| Unconfirmed                        | Keeps text                                      | "Couldn't confirm the note was sent. Sending it again may deliver it twice."                                                   |
| Failed                             | Keeps text                                      | "Couldn't send the note. Try again."                                                                                           |
| Missed (only when Hermes says so)  | —                                               | "Your note arrived after the agent finished." Without Hermes' word the screen claims neither delivery nor loss                 |
| Can't be controlled here           | Section removed                                 | Banner from Screen 2                                                                                                           |
| Server can't take notes            | Section removed after one line                  | "This server can't take notes for agents."                                                                                     |
| Agent ended with text in the field | Field becomes read-only text with a Copy button | "Not sent"                                                                                                                     |

## Screen 4: Stop confirmation

**Purpose:** make sure the person knows what stopping costs before it happens.

- Title: "Stop this agent?"
- Message: "It stops after its current step, along with any agents it started. What it already did stays, and the reply goes on without the rest."
- (Programs it started keep running: said under the Stop button in the detail, not in the alert.)
- Buttons: "Cancel" (default, bold on Apple platforms), "Stop agent" (destructive red).
- Mac: the alert dialog, not a sheet from the bottom. Escape cancels.

## Screen 5: Transcript card link

**Purpose:** get from the agent the person sees in the reply to the place where they can act on it.

- In the transcript's agent card ("Used 3 agents" / "2 agents · …"), every agent row becomes tappable where the surface has an Activity panel. Touch: the whole row; the row gets a trailing chevron. Mac: the row and a right-click item "Show Details".
- VoiceOver hint on the row: "Shows details in Activity".
- Quick panel: unchanged, no chevron, not tappable.
- No Stop or note field in the transcript.

## Screen 6: Program cards (PR 5)

**Purpose:** know which program is running and stop one that runs away.

- Row: command (monospaced, two lines max; a trailing "…" when Hermes cut it at 200 characters), state word and glyph, run time. Expanding shows the output as today.
- State words: Running; Stopped (any program Hermes ended on request, whatever its exit code, never "Exited with code -15"); Exited with code N; Ended (exited, no code); Closed (frames only, no list entry). Exit code 0 still reads "Exited with code 0", not "Succeeded".
- A card first filled from the list shows "Earlier output omitted" above its text.
- Stop: "Stop program" text button in the expanded card while running.
- Confirmation title: "Stop this program?"; message: "Hermes ends <command, one line>. Its output so far stays here, and the agent won't be told it finished."; buttons "Cancel" (default) and "Stop program" (destructive).
- Outcomes: "Stopped", "It had already ended.", "This program is no longer listed.", "Couldn't stop the program.", "Couldn't confirm the stop. Checking…".
- A card without a command keeps today's "Process <id> · Output received" until the list fills it in.

## Accessibility (applies to every screen)

- Targets: 44 × 44 pt on iPhone and iPad, 48 × 48 dp on Android, including the row chevron, back, Stop, Copy and Send. Mac controls are pointer sized (at least 28 pt).
- Row label order: goal, state, tools used, run time ("Audit the dependency tree, Running, 4 tools, 1 minute 12 seconds"). Custom actions: Show details, Stop agent (the same words as the swipe button and the context menu).
- State is never colour only: glyph and word always.
- Dynamic Type / font scale up to the largest accessibility size: goal wraps fully in the detail; rows may grow; buttons stack vertically when they do not fit side by side; the output box keeps a minimum of five lines.
- Contrast: WCAG AA for the subtle secondary line and the monospaced output in both themes; the destructive red on the Stop button meets AA on its tinted background.
- Reduced motion: no pulsing dot, no slide on the detail push (cross-fade or none).
- Keyboard: focus order back, goal, output, note field, Send to agent, Stop agent; ⌘Return / Control-Enter sends; Escape goes back from the detail.

## Privacy rules the design must keep

- Output, goals, notes and commands appear only inside the Activity panel. Nothing in notifications, widgets, Live Activities, the menu bar item, Dock menu, Spotlight or the watch.
- No preview of output in the row: the row shows the tool name and Hermes' short preview only, as the transcript card does today.
- When App Lock covers the app, the panel is covered with the rest; after unlock the output reloads (a brief "Reading output…").

## Use cases the catalog must have (both themes, phone, iPad and desktop widths)

Panel: agents running under Now with the Bot screen card above; ended agents with the overflow line; nested agents; old server. Row: each state word; long goal; largest text size. Detail: every row of the Screen 2 and Screen 3 tables, including Paused with a selection and Can't be controlled here. Confirmations: agent and program. Program card: running, exited with code, stopped (killed), ended without code, closed without list entry, seeded with omitted output, stop in flight and every stop outcome.
