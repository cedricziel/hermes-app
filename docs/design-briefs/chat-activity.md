# Design brief: chat activity line and Needs-you dock

Changes: `openspec/changes/chat-activity-line/` and `openspec/changes/chat-activity-needs-you/`. Read their design.md files for the facts and states; this brief is what the catalog and screen work need.

## Design (done)

Claude Design canvas "Hermes: Chat activity", built on the Hermes App design system: https://claude.ai/artifact/MrNWUNUAZWggxjbatmPNWM (private; ask its owner for access). 62 artboards in nine rows: idle chat (iPhone, Android); the activity line on iPhone (each source's sentence, plan and process counters, truncation, reduced motion, above a Bot Chat banner, appear and disappear); the line on iPad (with the inspector open), Android, Windows and Linux desktop, dark; macOS with no line (working, a long goal at 780 px, toolbar subtitle at five widths, a conversation window, the quick panel); the Needs-you dock on iPhone (billing, invalid URL, connector with one and three targets, reclaimed, "1 of 3" and "2 of 3", sending, chat after, panel after, lost answer, offline, keyboard on a 375 x 667 phone, the proposed keyboard collapse, dark); the Activity button marker (0, 1, 3 on iOS, Material and Mac); the dock on Android, iPad, desktop, Mac, conversation window and quick panel; the largest text size; every tier at once (line, dock and panel). Where this brief and the canvas differ, the sections below follow the canvas, except where "Corrections" says otherwise.

Decisions taken in the design pass:

- Line: 44 pt (Apple) or 48 dp (Material, desktop Material) button; progress indicator, one-line sentence with end ellipsis, counter chips at the right (plan checklist icon "2/5", processes terminal icon "1 running", references hub icon "3/5"). Surface-high background with a hairline below, first under the header, above a Bot Chat banner. Two rows from text scale 1.5.
- The line shows at most two counters, the ones that changed last; the goal sentence is the goal's text only; the rest lives in the panel.
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
- The canvas drew connector Open enabled while offline. It needs operation authority, so the change keeps it disabled (design.md); Copy code and the billing Open stay.
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

iOS: detent sheet from the line. Android: Material modal sheet, 48 dp targets. iPad and wide desktop: inspector beside the chat; the line hides while it is open. macOS: toolbar subtitle, ⌥⌘I inspector, 28 pt targets, no sheets. The quick panel shows the dock and no Working status.

## What was not checked

The claude.ai viewer, real devices, VoiceOver and TalkBack output, reduced-motion animation, contrast beyond an eye check (warning text on the dark surface), live keyboard behaviour, the size transition (a static sketch), App Lock (not drawn). Not every board was re-rendered after the last small edits.
