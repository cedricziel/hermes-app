# Design brief: chat activity line and Needs-you dock

Changes: `openspec/changes/archive/2026-11-14-chat-activity-line/` and `openspec/changes/archive/2026-11-14-chat-activity-needs-you/`. Read their design.md files for the facts and states; this brief is what the catalog and screen work need.

## Design (done)

Claude Design canvas "Hermes: Chat activity", built on the Hermes App design system: https://claude.ai/artifact/MrNWUNUAZWggxjbatmPNWM (private; ask its owner for access). 62 artboards in nine rows: idle chat (iPhone, Android); the activity line on iPhone (each source's sentence, plan and process counters, truncation, reduced motion, above a Bot Chat banner, appear and disappear); the line on iPad (with the inspector open), Android, Windows and Linux desktop, dark; macOS with no line (working, a long goal at 780 px, toolbar subtitle at five widths, a conversation window, the quick panel); the Needs-you dock on iPhone (billing, invalid URL, connector with one and three targets, reclaimed, "1 of 3" and "2 of 3", sending, chat after, panel after, lost answer, offline, keyboard on a 375 x 667 phone, the proposed keyboard collapse, dark); the Activity button marker (0, 1, 3 on iOS, Material and Mac); the dock on Android, iPad, desktop, Mac, conversation window and quick panel; the largest text size; every tier at once (line, dock and panel). Where this brief and the canvas differ, the sections below follow the canvas, except where "Corrections" says otherwise.

Decisions taken in the design pass:

- Line: 44 pt (Apple) or 48 dp (Material, desktop Material) button; progress indicator, one-line sentence with end ellipsis, counter chips at the right (plan checklist icon "2/5", processes terminal icon "1 running", references hub icon "3/5"). Surface-high background with a hairline below, first under the header, above a Bot Chat banner. Two rows from text scale 1.5.
- The line shows at most two counters, the ones that changed last; the goal sentence is the goal's text only; the rest lives in the panel.
- The sentence comes first (review of the catalog): when it does not fit beside the chips on one row they go compact (icon and number, no word), and if that is not enough only the chip that changed last stays. From text scale 2 the sentence may use two lines. On the Mac the subtitle drops spinner and status together when under about 24 pt are left for the status.
- Dock: surface-high rounded card at the composer's width. Header (kind icon, title that wraps up to two lines, "1 of N" with Previous and Next), body, pinned actions. Only the body scrolls.
- Billing: the host line ("Opens verify.example.com") comes before the code box; on a phone the actions stack full width, Open verification page filled over Copy code; elsewhere one row. Invalid URL: Open disabled with "This link can't be opened here."
- Sending: spinner, "Sending your answer…", 2 pt `BusyBar`, Skip and Continue disabled. Lost answer and offline are one plain warning line (icon and text in the warning colour), not a `Banner`.
- Settled items stay in This session with the value "Answered"; plan rows carry a status word as well as an icon.
- Marker: the same 10 pt dot (2 pt ring) for 1 and 3 waiting; the count is in the label "Activity, N need you" and in "1 of N".
- Mac: no line; the subtitle status is a flexible span with ellipsis after a 12 pt spinner, "default · gpt-5" does not shrink. Truncation starts near 700 px.

Corrections where this brief or the first proposals did not work:

- The first proposal made the line 32 pt and 36 dp. It is a control, so 44 pt and 48 dp.
- "Goal: ship the weekly digest (turn 3 of 20)" lost its tail at 390 pt; three counters left 60 pt for the sentence. Hence the goal text alone and at most two counters.
- At the largest text size three chips overflow even on two rows; the two-counter limit applies there too.
- With the body at 40% of the chat, the dock and composer leave no transcript on a 667 pt phone with the keyboard open. The design drew a collapse: title, one summary line ("3 sign-ins waiting · Expires in 4 min") and the action while the keyboard is open. Adopted in the change's design.md; the catalog fixes the thresholds.
- The canvas drew connector Open and billing Copy code enabled while offline. Connector Open needs operation authority, and billing details are discarded when the connection is lost (`agent-billing-verification`), so the change disables Open, keeps a connector item display-only and drops a billing item (design.md).
- The canvas draws the shared Button and `ChatComposer` unscaled at the largest size, so that board is indicative only.

Copy added by the design: "Billing access needs approval"; "Connect Notion to continue"; "Session opened elsewhere"; "This chat was opened on another device."; "Verify this request on your billing page, then come back. Enter this code there:"; "Opens verify.example.com"; "This link can't be opened here."; "Expires in 4 min"; "Waiting for sign-in"; "Signed in"; "Sending your answer…"; "Couldn't confirm your answer. It may have gone through; check before trying again."; "Offline. These actions come back when you're connected."; "N of M"; "Previous request"; "Next request"; "3 sign-ins waiting · Expires in 4 min"; "Activity, N need you"; "Working on the plan"; "Waiting for you"; "Answered". The titles for a failed restore ("This chat couldn't be restored") were not drawn; the catalog uses them.

## Who and why

Someone chatting with their Hermes who looks away while it works. The line answers "is it still busy, and with what" at a glance; the dock answers "what does it need from me" where they type. Voice: plain words, no protocol terms.

## Shared kit (reuse, do not invent)

`BusyBar`, `NamedIconButton` (paging, 44 pt / 28 pt Mac), `AdaptiveTabBar` is not needed, `GroupedSection`/`GroupedRow` (panel rows), the `MacToolbar` `subtitleBuilder`, `ActivityButton` (gains `waiting`), `AppIcons` (checklist, terminal and hub glyphs to add if missing), tokens only (`--h-warning`, `--h-surface-high`). Status is icon plus word, never colour alone.

## Widgets for the catalog (plain models, no controller)

| Widget | Model | Use cases | Closest existing |
| --- | --- | --- | --- |
| `ActivityLine` | `ActivityLineModel` (sentence, counters up to two, busy) | every source sentence, with and without counters, truncating, two rows at the largest size, reduced motion, Apple, Material, desktop, dark | none (Tag, list row) |
| `ActivityCounterChip` (private to the line) | icon, text, semantic label | in the line's use cases | Tag |
| `MacToolbarSubtitle` | profile, model, status, busy | idle, working, long goal at narrow width, conversation window | `MacToolbar` subtitle |
| `NeedsYouDock` | `NeedsYouDockModel` (items, shown index, callbacks) | billing (valid, invalid URL), connector 1 and 3 targets, reclaimed, restore failed, "1 of 3", "2 of 3", sending, unconfirmed, offline, keyboard open and collapsed, largest size, dark | `ApprovalCard` (transcript, not docked) |
| `BillingNeedsYouBody`, `ConnectorNeedsYouBody`, `ReclaimNeedsYouBody` | per-kind body models; `CodeBox`, `TargetRow`, `NoticeLine` are private parts | with the dock | extracted card bodies |
| `ActivityButton` marker | `waiting: int` | 0, 1, 3 on iOS, Material, Mac toolbar | `ActivityButton` |

New components needed (from the canvas, all token markup): ActivityLine, CounterChip, NeedsYouDock card, CodeBox, TargetRow, NoticeLine, the button marker. The canvas hand-composes the chat header because `ChatHeader` has no trailing slot in the design system; in the app `ActivityButton` is already in `ChatHeader`.

## Differences by platform

iOS: detent sheet from the line. Android: Material modal sheet, 48 dp targets. iPad and wide desktop: inspector beside the chat; the line hides while it is open. macOS: toolbar subtitle, ⌥⌘I inspector, 28 pt targets, no sheets. The expanded quick panel shows the dock inside its fixed height, the compact one shows none, and neither shows Working status.

## What was not checked

The claude.ai viewer, real devices, VoiceOver and TalkBack output, reduced-motion animation, contrast beyond an eye check (warning text on the dark surface), live keyboard behaviour, the size transition (a static sketch), App Lock (not drawn). Not every board was re-rendered after the last small edits.

## Tool call inputs and outputs: JSON and code

What a tool call card shows when opened: what the tool was given (Input, Arguments, Content) and what it returned (Result, Error, Output). Today that is flat monospace text plus a collapsible JSON tree (`flutter_json_view`) for a JSON object or array. This section is the design for colouring it. The catalog widgets are `ToolValueView`, `ToolJsonView` and `ToolValuePanel` (`lib/src/chat/widgets/tool_value_view.dart`, use cases under "ToolValuePanel"). Wiring them into `ToolCallCard`, `ToolArgumentsView` and the Terminal body is the next change; it does not touch card keys, ids or the open and closed state (lifted separately).

Design status: the Claude Design canvas was not reachable from this work, so the pass was done with what the repo holds: the Files code palette (`--h-code-*` in `design/web/src/styles/tokens.css`, `HermesCodeColors`, 5.2:1 or better on both surfaces) and rendered catalog use cases on phone and desktop, light and dark, and at text scale 2. A canvas board for the two options below was not drawn.

### Decisions fixed beforehand

- Reuse the Files palette and its guards; no new canvas colours. Colour is the only difference to today's text: the characters are never changed.
- Text is shown **as sent**: no reformatting, no re-indenting. What the server sent is what the person can read and copy.
- Language is derived on the client from the call alone (`toolValueLanguage`): the `command` of a terminal call is shell, the extension of the `path` argument names the language of a file's content, a JSON object or array is JSON, anything else is plain. Never from the server, never guessed from content beyond the JSON parse.
- Control and bidi characters are drawn as visible `<U+202E>` placeholders (`safeContentText`), as in Files.
- The 220 px height cap stays; the body scrolls inside it and the header row does not scroll.

### The two options for JSON

|            | A: text as sent by default, Tree switch                                                                                                | B: tree by default, Text switch                                       |
| ---------- | -------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------- |
| First view | Coloured flat text, exactly the bytes sent                                                                                             | Today's collapsible tree                                              |
| Switch     | "Tree view" opens the collapsible tree                                                                                                 | "Text view" shows the coloured text                                   |
| Good at    | Reading a short payload at a glance, comparing with the logs, copying what you see, a phone's narrow width (the tree indents by depth) | Exploring a deep result, hiding what you do not need                  |
| Cost       | The tree costs one tap                                                                                                                 | The common case, a payload of a few keys, costs a tap to read as sent |

**Recorded choice: A.** Most inputs are a handful of keys and most results are short; for those the flat text is shorter than the tree (no indent per level, no arrow column) and is the one that can be compared with a log or a command line. The tree stays one labelled tap away for the large, deep result where folding helps. The render check bore this out: at 390 pt the tree clips values at depth three while the text wraps in place. No problem found that would reverse it.

### The switch

A text button with an icon and a word: "Tree view" while the text shows, "Text view" while the tree shows (German: "Baumansicht", "Textansicht"). It names the view you will get, and the icon changes with it, so it is not colour or an icon alone. Target 44 pt on iOS, 48 dp on Android, 28 pt on a Mac (buttons keep `VisualDensity.standard`); the copy button beside it has the same size. The header is one row: the section label, the switch, copy; at large text sizes the buttons wrap under the label instead of squeezing it. Which view shows is state of `ToolJsonView`, so it survives a rebuild of the card; it ends with the widget (a card rebuilt in another place starts on the text).

The switch is offered only for a **settled** call whose text parses as a JSON object or array within the size bound. It is absent for invalid JSON, plain text, a running call and a scalar.

### States

| State                                | What shows                                                                                                                                                                                                                                                                                                                                                    |
| ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Settled JSON                         | Coloured text as sent, "Tree view" switch, copy                                                                                                                                                                                                                                                                                                               |
| Settled JSON, tree                   | The collapsible tree, "Text view" switch, copy                                                                                                                                                                                                                                                                                                                |
| Running (streaming)                  | Plain text with the control placeholders, no switch, no colour: the text grows with each delta and colouring would start over each time. It is coloured when the call settles                                                                                                                                                                                 |
| Failed                               | Same as settled: the section is labelled "Error", the card header carries the error icon, and the text is coloured only if it is JSON or has a known language. Status is never colour alone: icon, label and the error text itself                                                                                                                            |
| Very long                            | The body scrolls inside the 220 px cap, there is no "show all". Text that is not small and plain shaped is coloured by the worker and shows plain meanwhile; text above 512 KB, a stretch of 10,000 characters without a break, or more than 1,000 spans stays plain (the Files guards). A JSON text above 64 KB is not parsed, so it is plain with no switch |
| Invalid JSON                         | Plain text, no switch, never an error                                                                                                                                                                                                                                                                                                                         |
| Plain text                           | Plain text, no switch                                                                                                                                                                                                                                                                                                                                         |
| Terminal                             | The command is shell-coloured; the output is plain unless it parses as JSON                                                                                                                                                                                                                                                                                   |
| Diff                                 | Untouched: the diff body keeps its own view                                                                                                                                                                                                                                                                                                                   |
| Code argument (`write_file` content) | Coloured by the extension of its `path`; an unknown extension is plain                                                                                                                                                                                                                                                                                        |

Phone and desktop differ only in width and in the target sizes above. Both themes use the Files palette, which was checked for contrast on surfaces of both themes. Largest text (scale 2): the header wraps, the body is still capped at 220 px and scrolls; the text wraps in place (no horizontal scroll).

### Cost

The colouring is the Files one and obeys its rules:

- At most 2,000 characters of small, plainly shaped text are coloured while the frame builds; anything else is coloured in one killable isolate (at most one per text, timeout 2 s, ended with the widget) and shows plain until it answers; a failure or a timeout leaves it plain.
- A section keeps one State, so a rebuild with the same text does not colour again. Colouring runs only when the call has settled, never per delta.
- A chat-wide budget like the one the fences of a Markdown document share (`CodeHighlightBudget`) is for the wiring change to apply: with many cards open at once, those over the budget stay plain. `HighlightedCode` already takes one.
- No highlighter code lives outside `lib/src/files/code_highlight.dart`.

### Copy

The copy button copies the **original** text, byte for byte, with no placeholder in it. Selecting text with the pointer copies what is shown, so a placeholder like `<U+202E>` can be in a selection; the button is the exact copy. Nothing is copied unless the person taps.

### Privacy

Tool inputs and outputs never reach logs, spans or breadcrumbs: not their text, not their language, not the choice of view. The switch and the copy button record nothing.

### Not drawn

The canvas board (see above); a "show all" for a body over the cap (not needed while the body scrolls); a chat-wide budget (wiring change); VoiceOver and TalkBack output for the switch (its name is its visible text).
