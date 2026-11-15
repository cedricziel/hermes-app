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

## Transcript loading state (a stored chat's messages)

## Design (done)

Canvas: https://claude.ai/artifact/AKhFiQwGF7xKcES14JQe9Y ("Hermes: Chat loading state", private; ask the repo owner for access). 17 artboards on the Hermes App design system, built from the real `ChatHeader`, `ChatComposer`, `StateMessage`, `Banner` (the app's `AppBanner`), `UserMessage`, `AssistantMessage`, `Button` and `Spinner`. The skeleton bars are plain markup on tokens (the design system has no `LoadingSkeleton`).

Artboards:

1. Loading skeleton inside the chat screen (5): phone light with bars A and bars B, phone dark, Mac light, Mac dark.
2. Failed state with Retry (5): phone light and dark, Mac light and dark, Android light (material).
3. "Couldn't load earlier messages" row (5): phone light, dark and retrying, Mac light and dark.
4. Skeleton at the extremes (2): phone at the largest text size (3.1x), phone landscape with the keyboard open.

Decisions:

- **Bar colour.** The bars are `HermesColors.zinc300` in light and `HermesColors.zinc700` in dark, replacing `surfaceContainerHighest` (zinc100 light, zinc800 dark). Light contrast on the white transcript: today 1.10:1, A (zinc200) 1.27:1, B (zinc300) 1.48:1; B is chosen: it reads as grey text lines and is quieter than a divider with a border. Dark on zinc950: today 1.34:1 (the same fault), zinc700 1.91:1. The change is in `LoadingSkeleton` itself, so Logs, Providers, Usage and the other skeletons gain it too.
- **Pulse.** The opacity floor rises from 0.6 to 0.8, so the trough stays at 1.38:1 light and about 1.65:1 dark (it was 1.06:1 light). Reduced motion is unchanged: no pulse, no fade.
- **Text size.** Bar height (16) and the gap above and below each bar (8) scale with the text scaler, so a line of the skeleton is as tall as a line of text. Corner radius stays 6.
- **Short areas.** The skeleton draws only whole lines that fit its area (at least one) and clips what is left (`ClipRect`); it never scrolls and never shows a cut bar. At 3.1x on a 760 pt tall phone five of the six lines fit; in phone landscape with the keyboard open one line fits. The top padding is 24 pt, 16 pt when the window is under 500 pt tall. The header and the composer are never pushed.
- **Failed state.** `StateMessage` (error icon, "Could not load the messages", the detail) with the filled Retry, shown at once; only the title is the live region (its label is the title), the detail and Retry sit outside it. No snackbar over the composer (decided). The Retry hit area is 44 pt on touch and 48 dp on Android; on a Mac the Retry is given `minimumSize: Size(0, 28)` and standard visual density, because the app's Mac `FilledButton` theme measures 20 pt (the design's 40 pt was wrong; the app-wide Mac button size is reported separately).
- **Earlier-messages row (new, "L5").** When the first page failed and the user sent a message anyway, the transcript has messages, so the full-screen failed state goes. A single `AppBanner` row, tone warning, sits first in the transcript list, in the 680 column, scrolls with the messages and is not pinned. It carries the status three ways: the warning icon, the words "Couldn't load earlier messages" and a Retry button with a refresh icon. Targets: Retry 44 pt on touch, the compact 32 pt button on a Mac (floor 28). `AppBanner` already stacks the button under the title at large text sizes and is a polite live region, so a screen reader hears the title once when the row appears; the Retry button has its own node and the label "Retry loading earlier messages".
- **Retrying.** The row keeps its height: a spinner and "Retrying…" replace the button. A new failure puts Retry back with no new announcement. Nothing is resent automatically.
- **Success.** The earlier page is merged above the user's messages (as `_mergedWithPage` already does), the row goes and the scroll position stays on what the reader is looking at.
- **Why a banner, not a button in the header or a snackbar.** The failure belongs to the top of this transcript, a snackbar would cover the composer, and the shared `AppBanner` already has the status, announce and large-text behaviour.

Corrections to the brief above: "the skeleton bars do not scale" is wrong (they now scale); "`surfaceContainerHighest` bars" is replaced by the zinc300 and zinc700 tokens; the section said nothing about a failed first page that the user then sent past, which is the L5 row.

Copy added (`lib/l10n/arb/app_en.arb` and `app_de.arb`, `@@x-area-chat/widgets`):

| Key                             | en                             | de                                               |
| ------------------------------- | ------------------------------ | ------------------------------------------------ |
| `chatWidgetsHistoryEarlierFailedTitle` | Couldn't load earlier messages | Frühere Nachrichten konnten nicht geladen werden |
| `chatWidgetsHistoryEarlierRetrying`    | Retrying…                      | Wird erneut versucht …                           |
| `chatWidgetsHistoryEarlierRetryLabel`  | Retry loading earlier messages | Frühere Nachrichten erneut laden                 |

The Retry button text reuses `commonRetry` ("Retry" / "Erneut versuchen"). The existing `chatWidgetsHistoryLoading`, `chatWidgetsHistoryFailedTitle` and `chatWidgetsHistoryFailedDetail` are unchanged.

Not checked: the claude.ai viewer, real devices, VoiceOver and TalkBack output, the pulse and fade (the boards are static), the real text scaler (the largest-size board scales the bars only; the header and the composer are drawn at 100%), the keyboard (a placeholder block). Rendered locally in headless Chromium on the design system's bundle; all 17 boards were rendered and the phone, Mac and extreme boards were looked at. Not drawn: a loaded chat whose Retry succeeds, App Lock.

In this PR: the skeleton colour, pulse floor, text scaling, whole-line clip and Retry target above are built. The earlier-messages row (L5) is built in a stacked PR on this one: `ChatEarlierMessagesFailedRow` (`lib/src/chat/widgets/chat_earlier_messages_failed_row.dart`), shown through the transcript's `topSliver` when `ChatController.earlierMessagesStatusOf` is not null, with use cases under Chat thread / Messages ("Earlier messages failed", "Earlier messages retrying", "Earlier messages failed, largest text size").

`ChatHistoryState` (`lib/src/chat/widgets/chat_history_state.dart`) fills the transcript area of a stored chat that has no messages on screen yet; it is a plain model (`ChatHistoryStatus` and a retry callback) with use cases under Chat thread in the catalog. It is built from components the app already has.

- Today a stored chat that is picked shows the welcome view (greeting and starter prompts) until its messages arrive, which reads as "this chat is empty". It shows loading instead.
- Loading: the shared `LoadingSkeleton` (the Logs and Providers placeholder, six lines, quiet pulse), top aligned in the transcript's column, clear of the composer. It appears only after 180 ms (`kChatHistoryLoadingDelay`) and fades in over 150 ms (the fade runs when the skeleton appears, not when the transcript is built), so a read that finishes sooner shows an empty transcript for that moment, never the skeleton and never the welcome view. A chat that loads from the cache has its messages at once and shows nothing of this.
- The header (title, profile, avatar) and the composer are there from the moment of selection. The transcript is that chat's own (each chat has its own message list), so the previous chat's messages are never under the new title.
- Composer: unchanged. A send while the messages load stays allowed, as before: the controller merges the page into what was sent meanwhile (`_mergedWithPage`) and keeps a stored chat's name (`unread` in `_send`), and the message the user sends ends the loading state because the transcript then has a message. It is the safest existing rule; nothing new could reorder a chat.
- Failed: the shared `StateMessage` (error icon, "Could not load the messages", "Check your connection, then try again.") with the filled "Retry" button (`commonRetry`), at once, without the delay. Retry reads the first page again and shows the skeleton. Its title is a polite live region, so a screen reader hears it once. There is no "Could not load this chat" snackbar for this failure (the state says it, and reselecting the chat retries); the snackbar stays for other failures.
- Not shown for a new chat (its welcome view stays), for a chat whose messages are shown, or for a stored chat whose page came back empty.
- Reduced motion: the skeleton does not pulse (`LoadingSkeleton` already stops) and the fade is skipped. The pulse only runs while the skeleton is on screen.
- Screen reader: the skeleton is one node, "Loading chat", marked as a polite live region, so it is announced once when it appears. A fast load never reaches it, so nothing is announced; nothing is announced when the messages arrive either.
- Light and dark: the bars are `skeletonBarColor` (zinc300 light, zinc700 dark), the default of `LoadingSkeleton`, so Logs, Providers and Usage gain it too (the working-directory row keeps its own on-surface override). Phone, and the desktop and Mac split layout: the column keeps the transcript's maximum width; the sidebar is untouched. At the largest text size the failed state scrolls inside the area (`StateMessage`); the skeleton bars and their gaps scale with the text size, and a short area (phone on its side with the keyboard open) draws only the whole lines that fit, never a scroll view or a cut bar. Top padding 24, 16 under 500 pt of window height; Retry is 44 pt on touch (48 dp on Android).
- Catalog: Chat thread / Messages: "Loading the chat", "Loading the chat, reduced motion", "Loading the chat failed", "Loading the chat, largest text size", and Chat thread / ChatHistoryState (loading, short 70 pt area, largest text size, reduced motion, failed), next to the existing "Empty, welcome" (new chat) and "Conversation" (loaded).
