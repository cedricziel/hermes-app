# Design brief: Skill curator

Change: `openspec/changes/skills-curator/`. Read its design.md for the server facts (what each route returns, what a pass does, the 404 and 500 traps); this brief is the visual and copy pass. Roadmap item 4.8.

## Design (written, no canvas)

No Claude Design canvas was built for this change, and there is no canvas link: the pass was written as docs only and the design tool was not run. The Hermes App design system README was not read for it, so nothing here is checked against its tokens; the decisions were taken from the merged briefs for Server care and Tools and from the widgets in `lib/src/widgets/` and `lib/src/server_care/widgets/`. Nothing was rendered; the screens are described, not drawn. The Widgetbook use cases (task group 1 in tasks.md) are the first place anyone will see them, so look at every state there in both themes, at phone and desktop width and at the largest text size before wiring the screen.

Screens and states decided:

- Skills screen, Installed tab, "Skill curator" section: loading, never run, ran, paused, off in config, unknown fields, refreshing, offline, curator could not load, profile gone, old server (absent), dark, largest text, German.
- Run now row: idle, running, finished, finished with no output, failed, stopped with no exit code, not started (profile gone, refused as unnamed, spawn failure), lost answer, progress lost, still running after 15 minutes, checked and nothing running.
- Pause switch: idle, saving, failed, lost answer.
- Run confirmation: three wordings (prune only, may also merge and rewrite, unknown config), phone sheet, wide and Mac dialog, Android, largest text, dark.

Decisions, one line each:

- The curator is one `GroupedSection` headed "Skill curator" at the top of the Installed list, not a screen and not a pane. Its rows: Status, Last ran, Schedule, Unused skills, a Pause switch, Run now. The footer says passes also start by themselves on the server. Last ran carries a footnote line (see the table).
- The section is shown only on the Installed list and only while no search text or filter is active, so a search never has a curator section above its results. It is also not shown on Discover. A server with no skills hub has no Installed and Discover tabs (`tabs` is null); the section then sits on the only list.
- Run now is a `GroupedActionRow` (the gateway action row of Server care) extended for this feature: link-coloured text with a play icon, never red, never a filled button. As it stands it has a working phase (status text as the title, `BusyBar`; on a Mac no leading icon or spinner, only the `BusyBar`), a done phase (check mark, not tappable), failed and warning lines with outlined buttons. It has no subtitle slot, no tappable done phase, and no neutral line with a button. The extension is listed under New components needed.
- The confirmation is an adaptive sheet (bottom sheet on a phone, dialog on wide windows and every Mac width), because it holds a list and a copyable command that an alert cannot. Cancel is first, default and the only emphasised button. "Run now" is an outlined button in the link colour, not red (archived skills are kept, and the text says so) and not filled (it moves skills out of the list). On Android the two buttons are text buttons, Cancel first.
- Output lines are not shown while the run goes, only when it ends. A live-updating box of skill names would make a screen reader read the log; the row announces "Curator pass started" and the result once.
- Lines sit in a "Show output" disclosure (the monospace lines tile of the Update page, `UpdateDetailsDisclosure` in `update_step_list.dart`, extracted and extended so both use it: today it has no line cap, no footnote and no blank mode), closed by default, last 30 lines with "N earlier lines not shown" first when there are more. The lines are not selectable and cannot be copied (the privacy rule keeps output off the clipboard). The footnote under them says they may include another profile's run.
- The result wording never says "nothing changed". Hermes' own output carries counts (per the Hermes source, `auto: checked=N stale=N archived=N reactivated=N` and `curator: auto: ... | no changes; llm: ...`), but the app does not parse them for the result line, a line can be missing or reworded, and a consolidating pass can change things its prune counts do not show. A finished run says "The pass finished" and "See Hermes' output for what changed." "The pass finished" needs proof (see Check status): a newer `last_run_at` alone does not prove it, because per the Hermes source `last_run_at` is saved right after the prune step, before consolidation.
- The installed skills list is read again when a run ends, because archived skills leave it.
- A running pass keeps going when the screen closes; the app stops following it. Reopening the screen shows the last run time only, as the spec says.
- Pause is immediate and needs no confirmation. Its subtitle always says "Run now still works."
- No next-run time, no counts, no report, no Undo control and no dry run, because the server offers none. The only restore help is a copyable command in the confirmation.
- Every unknown field is "Unknown" in muted text, never a guess and never hidden, except `enabled`, where null counts as on (the server's default).

Copy added by the design: "Skill curator", "Run the curator now?", "Curator pass started", "The pass finished", "See Hermes' output for what changed.", "Show output", "N earlier lines not shown", "No pass is running now", "Leaving this screen doesn't stop it" and the strings in the tables below.

New components needed (all plain-model, Widgetbook first):

| Name                     | What it is                                                                                                           | Closest existing                                                                                    |
| ------------------------ | -------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| `CuratorSection`         | The section: the rows above, in the states listed, from one model                                                    | `GroupedSection` with `GroupedRow`, `GroupedSwitchRow`, `GroupedActionRow`                          |
| `CuratorRunConfirmation` | The body of the sheet or dialog: title, "A pass may" list, skip and keep lines, the restore command, the two buttons | `showAdaptiveSheet` with the Terminal confirmation of the Tools brief; `CommandRow` for the command |
| `OutputLinesTile`        | The "Show output" disclosure with monospace lines, a cap, a footnote and a blank mode                                | `UpdateDetailsDisclosure` in `update_step_list.dart` (extract and extend it; do not copy)            |
| Extend `GroupedActionRow` | A subtitle slot, a tappable done phase, a neutral line with a Check status button, and on a Mac a leading icon or spinner in the working phase | `GroupedActionRow` in `lib/src/server_care/widgets/grouped_action_row.dart`, moved to `lib/src/widgets/`; Server care's callers keep their look |

Everything else is existing kit.

## Who and why

The person who runs Hermes on their own machine. They open Skills because a skill they expected is gone, or because the list is long and they wonder what tidies it. They may not know there is a curator, or that Hermes starts it by itself once a week. They have no terminal in front of them, often a phone. The section answers three questions in this order: is it on, when did it last run, and can I stop it or start it.

Facts the design must not blur:

- **Passes start by themselves.** From the messaging gateway, or from the dashboard's own hourly check. The app need not be open. The footer says so.
- **Pause stops scheduled passes only.** Run now still works while paused. The Pause row says it.
- **Archived is not deleted, and the app cannot bring a skill back.** Only `hermes curator restore <name>` on the server does. The confirmation says it and offers the command to copy.
- **The action log is shared by every profile on the server.** Output lines are shown only for a run this app started, with a footnote.

## Shared kit (reuse, do not invent)

- Chrome: `SettingsScaffold` as the Skills screen already has it (title "Skills", subtitle "<profile> · <count>" (the count is Mac-only), tabs Installed and Discover when the server has a hub, search, bar actions). Nothing is added to the bar.
- Rows: `GroupedListView`, `GroupedSection` (header, footer), `GroupedRow` (title, value, subtitle, warning and error lines), `GroupedSwitchRow`, `GroupedActionRow` (`lib/src/server_care/widgets/grouped_action_row.dart`, the Run now row; it moves to `lib/src/widgets/` and is extended, see New components needed).
- Messages and progress: `AppBanner` (tone, icon, title, detail, action; a polite live region) for load errors inside the section, `StateMessage` is not used (the section is not the whole screen), `LoadingSkeleton` (label "Loading the curator", 3 lines), `BusyBar` (under the Run now row while it runs and under the section while status refreshes; on a Mac it is the only running indicator unless the extension adds a spinner).
- Disclosure: `DisclosureTile` for "Show output".
- Command: `CommandRow` with Copy ("Command copied" announced).
- Confirmation: `showAdaptiveSheet` (`adaptive_sheet.dart`); buttons per the settled rules.
- Destructive tint: `DestructiveTintButton` is not used; nothing is deleted and the red is kept for deletes elsewhere.
- Icons from `AppIcons`; status is icon plus word, never colour alone.
- Secrets: none on this feature, so `SecretFieldRow` is not used.

## Navigation

Nothing new. The Skills screen is reached as today (the chat sidebar's Skills row, the Mac sidebar, deep links), and the curator lives inside it.

- **iPhone, Android phone:** the section is the first group of the Installed list. It scrolls away with the list; no sticky header.
- **iPad, wide Android, Windows, Linux:** the same single column in the Skills screen's `ContentColumn`. There is no list-beside-detail layout on Skills, so there is none here. The confirmation is a centred dialog.
- **Skills screen states** (`_body` in `skills_screen.dart`): loading (centred spinner): the section shows above it and loads on its own; empty ("This profile has no skills yet."): the section shows above the `StateMessage`, since Run now still works on a profile with no list; failed ("Could not load skills" with Retry): the section shows above the `StateMessage`; unsupported ("The connected Hermes does not support skills."): the section is hidden. The screen's body is today a single widget per state, so showing the section above a `StateMessage` means wrapping it in a column.
- **Mac:** the same list under the `MacToolbar`. Rows are 28 pt minimum with a hover state; Return or Space on the focused Run now row opens the confirmation; Escape closes it with Cancel; ⌘[ goes back as on every Skills page. The confirmation is a dialog, never a bottom sheet.
- **Profile:** the section follows the profile the Skills screen shows (its profile menu). Switching profile reads the status again and drops any result, banner or running state of the old profile; a run for the old profile is not shown against the new one.

## Screen: Skill curator section

Job: "Tell me whether the curator is on, when it last ran, and let me stop it or start it."

Hierarchy, top to bottom inside the Installed list (above the first skill group):

**Section "Skill curator"**, footer: "Hermes tidies skills the agent made. Unused ones are marked stale, then archived, never deleted. Passes also start by themselves on the server, whether or not this app is open."

| Row           | Title                             | Value                           | Subtitle or line                                                                                                                                                                                  |
| ------------- | --------------------------------- | ------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Status        | "Status"                          | "Active", "Paused" (pause icon) | Paused: "Scheduled passes are paused."                                                                                                                                                            |
| Status, off   | "Status"                          | "Off"                           | "Turned off in the server's config. Change it there to use the curator." No Pause row, no Run now row.                                                                                            |
| Last ran      | "Last pass or first check"        | "3 days ago"                    | Tap or click shows the exact time as the subtitle ("12 Nov 2026, 09:12"), tap again hides it. Footnote under the section's rows: "Hermes also sets this time the first time it sees a profile, without a pass." No time: value "Hasn't run yet" (the spec's wording), subtitle "The first scheduled pass waits one interval (7 days)." |
| Schedule      | "Schedule"                        | "Every 7 days"                  | none                                                                                                                                                                                              |
| Unused skills | "Unused skills"                   | none                            | "Marked stale after 14 days, archived after 30."                                                                                                                                                  |
| Pause         | "Pause scheduled passes" (switch) | on or off                       | "Run now still works while paused."                                                                                                                                                               |
| Run now       | "Run now" (action row, play icon) | none                            | "Hermes reviews skills on the server."                                                                                                                                                            |

Interval wording, checked in this order: 1 hour "Every hour"; a multiple of 24 hours "Every day" (24) or "Every N days" (48 is "Every 2 days"); otherwise "Every N hours" ("Every 12 hours", "Every 36 hours"). A short value stays in the value column (`GroupedRow` cuts a value at half the row); "Every 7 days" fits, a long German value moves to the subtitle.

The Last ran value reads relative; the screen-reader label always carries both ("Last ran 3 days ago, 12 November 2026 at 09:12"), so the tap is a convenience, not the only way. `last_run_at` is also set by Hermes when it first sees a profile (per the Hermes source, first-seen seeding), so a time here can mean a first check, not a pass, and a null can follow a reset; hence "Last pass or first check" and the footnote. Fields come from `GET /api/curator`; each unknown one reads "Unknown" in muted text with no subtitle.

### Section states

- **Loading (first read):** header, then `LoadingSkeleton` labelled "Loading the curator". The skill groups below load on their own and are not held back.
- **Refreshing (reading again, old values shown):** the old rows stay; a `BusyBar` sits under the header. No spinner replaces them.
- **Never run:** the Last ran row above.
- **Ran:** as the table.
- **Paused:** Status value "Paused", the switch on. The Run now row stays.
- **Off in config (`enabled` false):** Status row and its subtitle only, plus the footer. Nothing to press.
- **Unknown fields:** "Unknown" as above; the Pause switch is shown only if `paused` is known, otherwise it is absent and a muted line says "Couldn't read the pause setting."
- **Offline (the request never left the device):** the rows are replaced by an `AppBanner` (warning, `AppIcons.cloud` with the word; `AppIcons` has no offline icon, a dedicated one would be a new entry) "Can't reach Hermes", detail "Check that the server is on and that you're connected to its network.", action "Try again". Old values are not kept under it.
- **Curator could not load (500 "Curator unavailable"):** `AppBanner` (error) "The server's curator could not load", action "Try again".
- **Other failure (400 invalid profile, unreadable answer):** `AppBanner` (error) "Couldn't load the curator", action "Try again".
- **Profile gone (404 `Profile '`):** `AppBanner` (warning) "This profile no longer exists", no action; the profile list reloads.
- **Old server (route-missing 404 or 405):** the section is absent, the list is exactly as today, no message.
- **Lost answer to the status read:** no answer within 10 seconds, or the connection dropped after the request was sent: an `AppBanner` (warning) "Couldn't confirm the curator's state", action "Try again". This is the settled rule of design.md, not the offline banner; reading is safe to repeat, so Try again simply reads.
- **App Lock:** the section holds no skill name, so it stays as is behind the lock screen; the output lines below are blanked. App Lock blanking comes free through `AppLockGate`; blanking while the app is inactive on a phone does not exist yet and is new work (tasks 2.4).
- **Large text:** values stack under titles (`GroupedRow` does it above the default text size); subtitles wrap in full on Status, Last ran and Unused skills (`wrapWhenStacked`); the Run now row keeps its icon beside a wrapping label.
- **German:** the longest risks are "Geplante Durchläufe pausieren" (the switch title wraps to two lines on a phone, which the row allows), "Seit 14 Tagen ungenutzt: veraltet, nach 30 archiviert" style sentences in the Unused skills subtitle (two lines, allowed), and "Das hat Hermes auf dem Server nicht gestartet" style failure lines. No value is longer than a short word or the interval; a long interval moves to the subtitle.

### Pause switch

- Idle: switch reads on or off. Turning it sends the new value at once, no confirmation.
- Saving: the switch is disabled, the subtitle says "Saving…", a `BusyBar` under the row. Screen reader: "Pause scheduled passes, on, saving".
- Done: the switch shows what Hermes answered (`paused`). The Status value follows. The section announces "Paused" or "Resumed".
- Failed: the switch returns to its old value; an error line under the row, "Couldn't change it" with Hermes' text when it sent one, or "Can't reach Hermes" when the request never left the device. The line stays until the next change. By status: 422, 400 and 500 (`Curator unavailable`) are section errors: the section shows the "Couldn't load the curator" or "The server's curator could not load" banner with Try again (per the spec scenario), and no switch changes. A 404 whose detail starts `Profile '` adds a pause state, "This profile no longer exists", as for the section's profile-gone state.
- Lost answer (no answer within 10 seconds, or the connection dropped after the request was sent, since the write may have landed): the switch returns to its last known value and a warning line says "Couldn't confirm whether this changed." Status is read again, which settles the switch on the real value and clears the line if it can. Nothing is resent automatically.

### Run now row

- Idle: "Run now", play icon, link colour, 44 pt / 48 dp / Mac 28 pt. Tapping opens the confirmation; nothing is sent until its Run now button.
- Open while a pass runs elsewhere: on open the app reads the action status once (`running` only, no lines are shown for a run this app did not start). When `running` is true the Run now row is disabled with the subtitle "A pass is running on this server", because Hermes does not guard a second run. This needs the subtitle slot of the extended row. When Check status finds a run in progress it becomes the running state and restarts polling with a new 15-minute limit counted from that check (open question 6).
- Running: the row is disabled with a spinner (on a Mac only the `BusyBar`, until the extension adds one), subtitle "Running on the server…", a `BusyBar` under it. Under it a muted line: "Leaving this screen doesn't stop it." Pause stays usable. Announced once: "Curator pass started".
- Finished: the row's status text "The pass finished" with a check mark, and the line "See Hermes' output for what changed." Under it the "Show output" tile. Announced once: "Curator pass finished". The Last ran row has refreshed. The skill list has been read again. The status text stays until the profile changes, the screen closes or the next run starts.
- Finished with no output: same, and the tile is replaced by the muted line "Hermes printed no output."
- Failed (non-zero exit): error line with an error icon and the word "Failed", then Hermes' last line verbatim; per the Hermes source the full line reads "curator: disabled via config; enable with `curator.enabled: true`" (shown in full, wrapping). "Show output" under it. The Run now row is tappable again; there is no separate retry, a new run needs a new confirmation.
- Stopped, no exit code (the dashboard restarted): neutral line "Hermes stopped, but the app can't tell whether the pass finished." Button "Check status" (needs the neutral line with a button of the extended row).
- Not started, profile gone (500 with `404: Profile '`): error line "This profile no longer exists. Nothing started." No button; the profile list reloads.
- Not started, refused as unnamed (400 "requires an explicit profile"): error line "Nothing started. Hermes needs to know which profile to run." Button "Try again" (opens the confirmation).
- Not started, spawn failure (500 "Failed to run curator: …"): error line "Nothing started" with Hermes' text. Button "Try again" (opens the confirmation).
- Lost answer to the start (no answer within 10 seconds, or the connection dropped after the request was sent; "Can't reach Hermes" is only for a request that never left the device): warning line "We couldn't tell if it started." Detail: "Nothing was sent again. It may be running on the server." Button "Check status". Nothing is resent.
- Check status: reads `GET /api/curator` and the action status once (reading is safe to repeat). Running now: becomes the running state. "The pass finished" only when `running` is false and the log has a `=== curator-run started` header after this app's POST. A newer last-run time alone reads "A pass started at <time>" and, unless `running` is false, "Couldn't confirm it finished" (per the Hermes source `last_run_at` is saved before consolidation ends). Nothing running and nothing newer: neutral line "No pass is running now. Last pass or first check <3 days ago>." If neither read answers within 10 seconds: "Couldn't confirm" with Check status again.
- Progress lost while running (polling fails for 10 seconds): warning line "Couldn't confirm how the pass is going." Button "Check status". The pass is not assumed finished or failed.
- Still running after 15 minutes: neutral line "Still running on the server." Button "Check status". The app stops polling by itself, it does not stop the pass.

### Show output

A `DisclosureTile` "Show output", closed by default, under the Run now row. It opens a box in the surface-high colour with monospace lines, not selectable (no copy), wrapping, the lines after the latest `=== curator-run started` header. Up to the last 30 lines; above that the first line reads "12 earlier lines not shown". A footnote under the box: "Hermes keeps one log for every profile on this server, so these lines can include another profile's run." Lines are memory only: never cached, logged or in telemetry. There is no copy at all, not by selection and not as Copy all, because the text can hold skill names and the privacy rule keeps output off the clipboard. While the app is inactive on a phone, or under App Lock, the box is blank (surface colour, no text). The tile label and line count stay. Blanking under App Lock is free through `AppLockGate`; blanking while inactive is new work (a shared helper or a piece of tasks 2.4), since there is no existing one to reuse.

## Screen: Run confirmation

Job: "Make sure I know what a pass can do before it starts, and that I can't undo it from here."

Sheet on a phone (bottom sheet, drag handle, 16 pt gutters); dialog on iPad, wide windows and every Mac width; on Android the phone sheet has text buttons. Scrolls when the largest text makes it taller than the screen; the buttons stay pinned at the bottom.

- Title: "Run the curator now?"
- Lead: "A pass reviews the skills on the server. It may:"
- Items (icon bullets, in this order):
  - "Mark skills stale after 14 days without use and archive them after 30." (numbers from the status read; "after the set number of days" when unknown). Then "Only skills recorded as agent-made count." as part of the same item (the marker also sits on skills a person wrote and then adopted).
  - Only if `curator.prune_builtins` is true or unreadable: "Include skills that came with Hermes." Unreadable reads "May include skills that came with Hermes."
  - Only if `curator.consolidate` is true or unreadable: "Merge and rewrite skills, and update scheduled tasks that use them." Unreadable reads "May also merge and rewrite skills, and update scheduled tasks that use them." Add "Merged or rewritten skills can only be rolled back on the server." to that item, because restore does not undo a merge or rewrite. If consolidate is false the item is replaced by the line "It archives unused skills only."
- Then, as plain lines: "Pinned skills, skills a scheduled task uses and skills installed from the hub are skipped." and "Archived skills are moved aside on the server, not deleted. This app can't undo a pass." (hedged: per the Hermes source nothing is deleted, not verified on a live server)
- "To bring an archived skill back, run this on the server:" then a `CommandRow` with `hermes curator restore <name>` and Copy. Per the Hermes source `restore` only moves an archived folder back; merges and rewrites need `hermes curator rollback`.
- Buttons, in this order: "Cancel" (default and focused, emphasised) then "Run now" (outlined, link colour, not red). On Apple phones they are stacked full width, Cancel on top; in a dialog and on Android they sit side by side, Cancel left, both text buttons on Android. The system back action, Escape and Return on the default all cancel and send nothing.
- At the largest text size the buttons stack on every platform, Cancel on top.

States:

- **Config not read yet** when the sheet opens: the sheet opens at once with the hedged wording (unknown), so a slow `GET /api/config` never delays or blocks it. If the read finishes while the sheet is open the wording does not change under the user's eyes; it applies the next time.
- **Config read failed:** same as unknown.
- **App Lock:** the sheet holds no skill name; it closes if the lock engages.

German risks: the first item is the longest sentence in the feature; it wraps to four lines on a phone and the sheet scrolls. "Archivierte Skills bleiben auf dem Server erhalten" and "Diese App kann einen Durchlauf nicht rückgängig machen" each take two lines. The `CommandRow` stays English and monospace and breaks at spaces.

## Offline, errors and lost answers: summary

| Situation                      | Where             | What the person sees                                                  |
| ------------------------------ | ----------------- | --------------------------------------------------------------------- |
| Status read, no answer in 10 s | Section           | "Couldn't confirm the curator's state", Try again                      |
| Connection dropped after a pause or run was sent | Pause or Run now row | A lost answer (switch back and re-read, or "We couldn't tell if it started."), never "Can't reach Hermes" |
| Pause, no answer in 10 s       | Pause row         | Switch back, "Couldn't confirm whether this changed.", status re-read |
| Start, no answer in 10 s       | Run now row       | "We couldn't tell if it started.", Check status, nothing resent       |
| Progress, no answer in 10 s    | Run now row       | "Couldn't confirm how the pass is going.", Check status               |
| Run lasts 15 minutes           | Run now row       | "Still running on the server.", Check status                          |
| Request never left the device  | Per row, as above | "Can't reach Hermes"                                                  |

Nothing here resends a pause or a run. Only reads (status, action status) are repeated, by the person pressing Try again or Check status.

## Accessibility

- Targets: 44 pt on Apple touch, 48 dp on Android, 28 pt minimum on a Mac (rows, the switch, Check status, Try again, Cancel and Run now, the Copy button of `CommandRow`).
- Status is an icon plus a word: Active (check), Paused (pause), Off (`AppIcons.radioOff`, the empty circle), Failed (error), warnings with the warning triangle and a word ("Couldn't confirm"). Colour only reinforces.
- Labels: the Pause switch reads "Pause scheduled passes, on" (and ", saving" while a write is out, reported disabled); the Run now row reads "Run now, button" and "Run now, running" when disabled; Last ran reads relative and exact time together; the output tile reads "Show output, 12 lines, collapsed".
- Live regions: `AppBanner` is polite. A run's start and end are announced once each ("Curator pass started", "Curator pass finished" or the failure sentence). Polling never announces.
- Order: Status, Last ran, Schedule, Unused skills, Pause, Run now and its status line, then the skill groups. The confirmation focuses Cancel first.
- Largest text: nothing is cut with an ellipsis where meaning would be lost; rows stack; the confirmation scrolls with pinned buttons.
- Desktop keyboard: Tab follows the visual order; Space toggles the switch; Return opens the confirmation from Run now; Escape closes it with Cancel.
- Reduced motion: the `BusyBar` and spinners stay (they carry state); no transition on the section appearing.
- Contrast AA in light and dark, for muted values, the monospace box and the link-coloured action text.

## Privacy

- Skill names appear only in Hermes' output lines. Those are on screen only, never cached, logged, in telemetry (the span and log event carry the outcome and, if kept, the parsed `archived=` count), in the surface snapshot or on the clipboard, never selectable, and are blank under App Lock and while the app is inactive on a phone.
- The only text this feature puts on the clipboard is the restore command the person copies, with the placeholder `<name>`.
- No content goes into a notification, the Lock Screen, Siri or a complication. The curator adds no notification.
- Nothing is stored: no secret is involved, and no preference is written.

## Platform differences

|              | iPhone                            | iPad / wide desktop         | Mac                              | Android                                                            |
| ------------ | --------------------------------- | --------------------------- | -------------------------------- | ------------------------------------------------------------------ |
| Section      | First group of the Installed list | Same, in the content column | Same, 28 pt rows with hover      | Same, Material rows                                                |
| Confirmation | Bottom sheet, Cancel on top       | Centred dialog              | Restrained dialog, never a sheet | Bottom sheet, two text buttons, Cancel first                       |
| Run now      | Tap                               | Tap                         | Click, Return or Space           | Tap                                                                |
| Output blank | While the app is inactive (new piece) | Same                    | Under App Lock only              | While inactive (new piece); nothing blocks screenshots today |
| Switch       | Cupertino                         | Cupertino                   | Mac switch                       | Material switch                                                    |

## Spec scenarios and where the design covers them

| Spec scenario                                    | Covered by                                                                                                                 |
| ------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------- |
| Backend contract: Old server                     | Section absent, no message ("Old server")                                                                                  |
| Backend contract: Missing profile                | Section state "Profile gone"; Run now row "Not started, profile gone"                                                      |
| Backend contract: Curator unavailable or invalid | Section states "Curator could not load" and "Other failure"; Pause "Failed" leaves the switch where it was                 |
| Backend contract: Odd response                   | "Unknown" in muted text, the rest shown                                                                                    |
| Explicit profile: Switching profile              | Navigation, "Profile": status read again, results dropped                                                                  |
| Explicit profile: Profile deleted before a run   | Run now row "Not started, profile gone"                                                                                    |
| Explicit profile: Refused as unnamed             | Run now row "Not started, refused as unnamed", Try again                                                                   |
| Status: Never run                                | Last ran row "Hasn't run yet" with the first-pass subtitle                                                                 |
| Status: Off in config                            | Section state "Off in config", no Pause row, no Run now row                                                                |
| Pause and resume: Pause                          | Pause switch "Done" (value from Hermes' answer)                                                                            |
| Pause and resume: Lost answer                    | Pause switch "Lost answer"                                                                                                 |
| Run needs a confirmation: Cancel is the default  | Confirmation buttons, focus and back action                                                                                |
| Run needs a confirmation: Consolidation unknown  | Confirmation items (false, true, unreadable)                                                                               |
| Run needs a confirmation: Undo is not offered    | Confirmation: the restore line and `CommandRow`; no undo control anywhere                                                  |
| Following a run: Finished                        | Run now row "Finished" plus "Show output" (proof rule under Check status)                                                |
| Following a run: Failed                          | Run now row "Failed" with Hermes' last line                                                                                |
| Following a run: Spawn failure                   | Run now row "Not started, spawn failure", Try again opens the confirmation                                                 |
| One run at a time: Lost answer                   | Run now row "Lost answer to the start" and "Check status"                                                                  |
| Shared action log: Opening the screen            | Section shows the last run time only; the output tile exists only for a run this app started, with the shared-log footnote |
| Privacy and observability: Telemetry content     | Not visible; the design adds no text to any signal                                                                         |
| Strings: German                                  | German risks listed under the section, the confirmation and Accessibility; every string in both ARB files                  |

Spec requirement "Run now SHALL be disabled while a run is shown as running" is met by the Run now row's disabled running state and, after reopening the screen, by the one-time `running` read on open.

## Open questions for the owner

1. **Restore command and profiles.** The spec says the command is `hermes curator restore <name>`. For a profile other than the server's default, restore would need `-p <profile>`. Recommendation: keep the spec's placeholder command and add the line "For another profile, add `-p <profile>` after `hermes`", so no profile name is put on the clipboard and the spec's privacy requirement stays as written. The owner decides whether the command may carry the real profile name instead (needs a spec change).
2. **Hedged "last ran".** `last_run_at` can be a first-seen seed, not a pass, and the route drops `run_count` and `last_run_summary`, which would tell them apart. Raise upstream to return them (design.md open question 1); until then the copy is "Last pass or first check" with a footnote.
3. **Counts in the output.** Per the Hermes source the output has counts (`auto: checked=N stale=N archived=N reactivated=N`, `curator: auto: ... | no changes; llm: ...`, "consolidation is off - running prune-only") but no per-skill archived lines. Decided here: the app never says "nothing changed", because lines can be missing or reworded, and the telemetry attribute `archived_lines` becomes `archived` (the parsed `archived=` count, absent when no such line is found). The owner may drop the attribute instead.
4. **Dismissing a result.** The result stays until the profile changes, the screen closes or the next run. There is no Dismiss button. Say so if a person should be able to clear it.
5. **Hiding the section while searching.** Chosen so results are not pushed down. If the owner wants it always visible, the Installed list's empty-search state needs a curator-only variant.
6. **Check status finding a run.** This brief restarts polling with a new 15-minute limit counted from that check, since the route does not say when the pass began. Confirm.
7. **Spec scenarios still to add.** The spec is not changed here. It needs a scenario each for: PUT 404 `Profile '` (a pause state), the one-time `running` read on open, the finish proof (`running` false plus a start header after this app's POST), and the section's place in each Skills screen state.
8. **Unverified server claims.** The Hermes source readings (`last_run_at` saved after the prune step, first-seen seeding, the printed lines, `restore` versus `rollback`) come from a reviewer's reading of `agent/curator.py` and `hermes_cli/curator.py`, not from a run; confirm them on a live backend (tasks 2.1).
