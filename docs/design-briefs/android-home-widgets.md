# Design brief: Android home widgets

Change: `openspec/changes/android-home-widgets/`. Read its design.md for the snapshot facts, the build and the rules; this brief is what the visual design pass needs and what it decided.

## Design (done)

Claude Design canvas "Hermes: Android home widgets", built on the Hermes App design system: https://claude.ai/artifact/A32jNXKc4gSovjGJidbLhB (private; ask its owner for access). 7 artboards in three rows: Recent chats, Needs you and Board (small and medium, light and dark side by side); the three with App Lock on (placeholder bars, light and dark); the empty, out-of-date and signed-out states of the three at small size; Recent chats at 200% text; and the widget picker's sample previews. Rendered headlessly with Chrome and read as contact sheets; not looked at in the claude.ai viewer. Where this brief and the canvas differ, the sections below have been brought in line with the canvas.

Decisions taken in the design pass:

- Sizes: small is 2x2 (160 x 160 dp drawn), medium is 4x3 (328 x 200 dp drawn). Medium is 4x3, not iOS's 4x2, because three tappable rows at 48 dp plus a header need about 184 dp. A 4x2 widget shows what fits (one row), and rows drop from the bottom rather than shrink.
- Frame: surface colour, 24 dp corners (the launcher's own radius where it supplies one), 12 dp padding, a 20 dp header line (16 dp icon, "Recent chats", "Needs you" or "Board" in 12 sp muted semibold) and nothing else drawn in the frame.
- Row: 48 dp minimum, title 14 sp semibold on one line (two when the text is large), age or meta in 12 sp muted at the right, snippet or kind in 12 sp muted underneath. Small Recent chats is one 16 sp title on up to three lines, then "profile · age".
- Needs you: the count is the widget. Small is a 44 sp numeral and "Approval · oldest 12 min". Medium moves the count to the header's end (20 sp bold) so three rows fit; a row is title, age, then an icon and the kind word (shield "Approval", help "Question", dots "Waiting for you").
- Board: parts in the order failed job, Kanban, next run. A failed job is the error icon, the name and "Failed · 2 h" in the error colour; small shows the two first parts, so a failure always survives. Small without a name ("Backup failed" over "2 h ago") also carries the error icon.
- App Lock: grey placeholder bars (12 dp high rounded bars, the border colour) where a title, snippet or job name would be; ages, counts, kind words, Failed and Kanban counts stay. Each bar's description is "Hidden".
- States: the empty, out-of-date and signed-out texts are the iPhone words ("No chats yet", "Nothing waiting", "No board or schedules on this server", "Open Hermes to refresh" as a 12 sp muted note at the bottom, "Open Hermes to sign in"). A stale widget keeps its content.
- Large text: snippet drops first, then rows that no longer fit; the header and the title scale with the text; titles wrap to two lines.
- Picker: three static previews with sample content ("Trip plan", "Weekly summary", "Fix the build", "Sample chat"), a name and a description under each ("Your newest chats. Tap one to open it.", "Approvals and questions waiting for you.", "Kanban counts and your next scheduled run."). The previews are rendered from these artboards.
- Lock screen: nothing is offered. Android cannot hide a widget's content on a locked device.
- Colour: wallpaper-derived system colours on Android 12 and newer; the Hermes tokens drawn on the canvas are the fallback below 12.

Corrections where this brief did not work:

- The first Needs you medium put the count on its own line above the rows; three rows did not then fit in 200 dp. The count moved into the header.
- A small Board row with only a red title relied on colour for failure; it now carries the error icon and the word "failed".
- The picker artboard was too short for three previews with their descriptions; it is taller.

Copy added by the design: the three picker descriptions above, "Sample chat" and "Sample task" as preview text, "Hidden" as the placeholder's description, "Tap to start one" under "No chats yet" (not in the iPhone widget; optional, decided in the first PR).

## Who and why

The person who runs Hermes for their own chores and carries an Android phone. They glance at the home screen to see whether the agent finished something, asked something or failed a scheduled job, and tap to get to it. They do not read; they scan a number and a word.

## Shared kit

The widgets are Glance Kotlin, so none of the Flutter shared widgets applies. They follow the same words and rules as the iPhone widgets (`home-screen-widgets`) and the tokens drawn on the canvas. The words on the canvas are the ones to ship; changing a word on one platform changes it on both.

## Screens

Three widgets, no screens. Each has the states below, in both sizes where the canvas shows both:

| State                | Recent chats                          | Needs you                    | Board                                  |
| -------------------- | ------------------------------------- | ---------------------------- | -------------------------------------- |
| Content              | newest chat (small), three rows       | count and kinds              | failed job, Kanban, next run           |
| App Lock on          | placeholder bars, ages                | count, kind words, bars      | counts, Failed, bars for names         |
| Empty                | "No chats yet"                        | "Nothing waiting"            | "No board or schedules on this server" |
| Out of date (6 h+)   | content and "Open Hermes to refresh"  | same                         | same                                   |
| Signed out, unreadable | "Open Hermes to sign in"            | same                         | same                                   |
| Largest text         | one or two rows, no snippet           | fewer rows                   | fewer parts                            |

## Accessibility

- Touch targets: every row at least 48 dp tall (Android's rule; the iPhone's is 44 pt).
- Status is never colour alone: Failed is an icon and a word; request kinds are an icon and a word.
- Honour the system text size with no cap; check 200%.
- Text contrast 4.5:1 on the widget surface in light and dark; the muted text token passes on both.
- Each row has one content description (kind and count, plus the title unless App Lock blanked it); a placeholder bar is described as "Hidden".

## Differences by platform

- iPhone: medium is 4x2 and shows three rows with snippets, a large size exists, titles are redacted by iOS on a locked device, ages tick without a reload.
- Android: medium is 4x3, no large size yet, nothing on the lock screen, ages move at the system's redraw (at least every 30 minutes), wallpaper colours on 12 and newer.

## New components needed

None in the Flutter design system. In Kotlin: a shared widget frame with header, a row, and a placeholder bar (PR 1), reused by PR 2.
