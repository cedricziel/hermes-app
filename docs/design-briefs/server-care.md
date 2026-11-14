# Design brief: Server care

Change: `openspec/changes/server-care/`. Read its design.md for the server facts and the state machines; this brief is what the visual design pass needs.

## Who and why

The person who installed Hermes on their own machine and uses the app as its remote. They come here when something seems wrong ("the Telegram bot stopped answering", "my scheduled task didn't run", "is there an update?") or now and then to see what Hermes costs. They are on a phone more often than not, maybe away from home. They know what Hermes is; they may not know what a gateway, a receipt or a doctor is, so the words below avoid those where we can.

Two facts the design must not blur:

- **The messaging gateway is not this app's chat.** Restarting it never stops a reply in the app. It pauses Telegram, Discord and the other channels and the scheduled tasks.
- **Updating restarts Hermes itself.** Chats in the app pause until it is back; replies in progress stop.

## Shared kit (reuse, do not invent)

- Page chrome: `SettingsScaffold` (title, subtitle "<profile> · …", `SettingsBarAction`s; iOS 44 pt bar, Mac toolbar with Back and ⌘[, Material 56 pt bar). No floating buttons.
- Lists: `GroupedListView`, `GroupedSection` (header, footer), `GroupedRow` (title, meta, subtitle, warning and error lines, value, chevron, trailing), `GroupedSwitchRow`, `GroupedMetrics.of(context)` for sizes.
- Empty, error and loading messages: `StateMessage`; thin progress: `BusyBar`; fold-outs: `DisclosureTile`.
- Segmented choices: `AdaptiveTabBar` / `PillSegmentedControl` (Material), the Cupertino sliding control on Apple, `MacToolbarTabs` in the Mac toolbar.
- Confirmations: `showConfirmDialog` / `AppAlertDialog` (restrained Mac alert at every width, Cupertino alert on iOS, Material dialog on Android). Choices that need more text than an alert holds: `showAdaptiveSheet` (bottom sheet on a phone, dialog on wide windows and every Mac width). No bottom sheets on the Mac.
- Wide layouts: list beside detail at 900 pt (700 pt on iPad), as on the Plugins and Memory proposals screens.
- Icons from `AppIcons`; status always icon plus word, never colour alone.

## Navigation

- **iPhone, Android phone:** account menu (the avatar at the bottom of the chat list) gains "Server" after "Connection details". When the server needs attention the item reads "Server · needs attention" and the avatar carries a small dot (a filled circle with a 2 pt outline in the surface colour so it reads on both themes). The avatar's accessible label becomes "Account, server needs attention".
- **iPad, wide Android, Windows, Linux:** the same menu in the sidebar footer. The Server screen is list beside detail at 700 pt (iPad) or 900 pt; below that, pages push.
- **Mac:** a "Server" row in the sidebar after Profiles, 28 pt like the other destinations, with a trailing caption: "Needs attention", "Updating…", "Restarting…", or none. The page fills the content area with the Mac toolbar (title "Server", Refresh button, ⌘R). Sub-pages push in the content area with Back and ⌘[.

## Screen: Server (overview)

Job: "Tell me whether Hermes is OK, and if not, let me fix it with one tap."

Hierarchy, top to bottom:

1. **Headline card** (not a row; a card at the top of the list with an icon, one sentence, an optional second line, and at most one button). The sentence is the first match in this order:

   | State                             | Icon      | Sentence                                                | Second line                                                             | Button          |
   | --------------------------------- | --------- | ------------------------------------------------------- | ----------------------------------------------------------------------- | --------------- |
   | Loading                           | spinner   | "Checking Hermes…"                                      | —                                                                       | —               |
   | Unreachable                       | warning   | "Can't reach Hermes"                                    | "Check that the server is on and that you're connected to its network." | Try again       |
   | Store unreadable                  | error     | "Hermes can't read its session store"                   | "Chats and usage may be missing until it's repaired."                   | Run a check     |
   | Gateway failed                    | error     | "The messaging gateway stopped with an error"           | "Messaging channels and scheduled tasks are paused."                    | Restart gateway |
   | Gateway stale                     | warning   | "The messaging gateway isn't responding"                | "It's running but hasn't checked in for <n> minutes."                   | Restart gateway |
   | Gateway off (channels configured) | warning   | "The messaging gateway is off"                          | "Messaging channels and scheduled tasks don't run while it's off."      | Start gateway   |
   | Disk critical                     | error     | "Disk almost full: <1.2 GB> free"                       | "Hermes may stop saving chats. Free up space on the server."            | —               |
   | Out-of-memory restart             | warning   | "Hermes restarted unexpectedly, probably out of memory" | —                                                                       | Show logs       |
   | Channels offline                  | warning   | "<1> of <2> messaging channels are offline"             | —                                                                       | Show logs       |
   | Memory low                        | info      | "Memory is low on the server"                           | —                                                                       | —               |
   | Disk elevated                     | info      | "Disk space is getting low: <8.4 GB> free"              | —                                                                       | —               |
   | Healthy                           | checkmark | "Everything looks good"                                 | "Hermes <0.22.2> · checked just now"                                    | —               |

2. **Section "Hermes"**
   - Row "Version" · value "0.22.2" · subtitle "Released 2 Nov 2026".
   - Row "Updates" · value one of "Up to date", "Update available", "Checking…", "Couldn't check" · subtitle "12 changes" when behind · chevron → Update page. While an update runs: value "Updating…" with a `BusyBar` under the row.
3. **Section "Messaging gateway"** (footer: "Runs your messaging channels and scheduled tasks. Chats in this app don't depend on it.")
   - Row "State" · value in words: "Running", "Starting", "Running, some channels offline", "Draining", "Off", "Failed to start", "Not responding".
   - Row "Channels" · "1 of 2 connected" (hidden when none are configured).
   - Row "Shared with" · "default, work" (only for a shared gateway).
   - Action row: "Restart gateway" (or "Start gateway" when off), tinted as a button, not destructive red (it asks first). States in the row during a restart: "Restarting…" (BusyBar), "Waiting for the gateway…", "Running again" (checkmark, 4 s), "The gateway didn't restart" (error line, buttons Show logs, Try again), "The gateway hasn't come back yet" (warning line, Show logs), Hermes' refusal text as an error line.
4. **Section "Server"**
   - Row "Disk" · "8.4 GB free · 91% used" with a warning line when elevated or critical.
   - Row "Memory" · "OK", "Getting low", "Low", hidden when unknown.
   - Row "Session store" · "OK" or "Can't be read" (error line).
5. **Section "Tools"**
   - Row "Usage" · subtitle "Tokens and cost by day and model" · chevron.
   - Row "Logs" · subtitle "Recent lines from Hermes' logs" · chevron.
   - Row "Run a check" · subtitle "Hermes looks for problems in its setup" or, after a run, "2 problems · checked 5 min ago" · chevron.
6. **Section** with one row "Connection details" · chevron (the existing page).

Subtitle of the page: "<profile>" when the server has one profile, "<profile> · 3 profiles" otherwise. Bar action: Refresh (pull to refresh on iOS and Android too).

Wide layouts: the overview list on the left (340 pt), the selected sub-page on the right; nothing selected shows the Usage page.

Old server: rows whose route is missing are simply absent. Never an error for that.

## Page: Update

Job: "Get the latest Hermes without breaking anything, and know whether it worked."

Hierarchy: status line, then the one primary action, then what changes, then details.

States and copy:

- **Up to date:** title "Hermes is up to date", body "Version 0.22.2. Checked <just now / 2 hours ago>." Button (secondary) "Check now".
- **Checking:** "Checking for updates…" with spinner.
- **Couldn't check:** Hermes' message ("Couldn't reach the update source — try again later."), button "Check now".
- **Update available (can apply):** title "Update available", body "12 changes since your version (0.22.2)." Primary button "Update Hermes". Section "What's new" lists up to 20 change summaries as rows (summary as title, "author · 3 days ago" as subtitle, no hashes shown). Footer: "Hermes restarts during the update. It usually takes a few minutes."
- **Rollback:** same, with a warning line: "This build is newer than stable release v0.22.0. Updating moves it back to that release." Primary button "Move to 0.22.0".
- **Cannot apply here:** title "Update Hermes on the server", Hermes' message as body, and when there is a command, a monospaced row with the command and a "Copy" button (copy announces "Command copied"). No primary button. Managed host: just the message.

Confirmation (alert; Cancel is the default and on the left on Apple, "Update" plain, not red):

- Title: "Update Hermes now?"
- Message, built from what applies: "Hermes restarts during the update, usually for a few minutes. Chats pause until it's back." + "1 reply in this app is still running and will stop." + "2 conversations on messaging channels will stop."
- Buttons: "Cancel", "Update".

Progress (the page keeps one card with a step list; each step is a row with an icon and a word: pending circle, spinner, checkmark, cross):

1. "Starting the update"
2. "Downloading and installing" — subtitle shows nothing from the log; a "Show details" `DisclosureTile` reveals the last lines in monospace (memory only).
3. "Restarting Hermes" — subtitle "Chats continue when it's back."
4. "Checking the result"

Outcomes:

- **Success:** checkmark, "Hermes is up to date", "Now running 0.23.0." Button "Done".
- **Partial:** warning, "Hermes updated, with one thing left to do", the reason from Hermes (one line per item). Button "Done".
- **Failed or interrupted:** error, "The update didn't finish", "Hermes is still running 0.22.2." "Show details" with the last lines. Buttons "Done", "Try again" (Try again asks again).
- **Refused:** like "Cannot apply here", with Hermes' message.
- **Can't confirm:** info, "Hermes is back, but the app can't confirm the update", "Now running 0.23.0."
- **Not back:** warning, "Hermes hasn't come back yet", "If you started Hermes by hand, it may need to be started again on the server." Buttons "Keep waiting", "Dismiss".

Leaving the page never cancels. There is no Cancel during the update (Hermes offers none).

## Restart banner (above every destination in the main window)

Job: "Explain why chats are not answering right now."

A full-width strip under the toolbar or app bar, 44 pt minimum, info tint, icon + text + chevron: "Hermes is restarting after the update. Chats continue when it's back." Tap → Update page. After success: "Hermes 0.23.0 is ready" with a close button, gone after 6 s (stays until closed under reduced motion). Not shown in Mac conversation windows or the quick panel. Announced once to screen readers when it appears (polite).

## Gateway restart confirmation

Alert. Title "Restart the messaging gateway?" ("Start the messaging gateway?" for start, no confirmation needed for start; start runs at once).

Message lines:

- "Chats in this app keep running."
- "Messaging channels and scheduled tasks pause until it's back, usually within a minute."
- When conversations run: "2 conversations on messaging channels will stop."
- Shared: "This gateway is shared. The bots of default, work and family reconnect too."

Buttons: "Cancel" (default), "Restart" ("Restart for all" when shared). Not red.

## Page: Logs

Job: "See what Hermes said just before something went wrong."

Bar: title "Logs", subtitle "<profile> · newest first". Actions: Refresh; a menu (…) with "Copy shown lines", and the profile choice when there are several profiles.

Controls (under the bar on phones, in the Mac toolbar as `MacToolbarTabs` plus a search field):

- File segments: "Errors" (default), "Agent", "Gateway".
- Level menu button: "All levels", "Warnings and errors", "Errors only".
- Search field, placeholder "Search these logs".

Lines: a list, newest first. Each line: first row time ("09:12:03", with the date on the first line of each day as a sticky section header "Today", "Yesterday", "12 Nov") and the level as a word chip ("Error", "Warning", "Info", "Debug") with an icon; second row the source in small monospace ("gateway.run"); then the message in monospace, wrapping. Continuation lines (tracebacks) sit under their line, indented, folded after 3 lines with "Show 12 more lines". Text selectable. At the end: "Show older lines" (up to 500), then "That's the last 500 lines."

States:

- Loading: three skeleton lines, label "Loading logs".
- Empty, no filter: "Nothing logged yet" / "Hermes hasn't written to this log."
- Empty with filter: "No lines match" / "Try another level or search." button "Clear filters".
- Offline: "Can't reach Hermes" / Try again.
- Refused: Hermes' message.
- App inactive on a phone: the content area is blank (surface colour, the Hermes glyph centred); no text.

Copy confirmation (alert): title "Copy these log lines?", message "Logs can contain private details, like messages and file paths. Anyone you paste them to can read them.", buttons "Cancel", "Copy".

## Page: Server check

Job: "Find out what's misconfigured, in plain words, and what to do about it."

Before a run: `StateMessage` "Check Hermes for problems" / "Hermes checks its configuration, connections and storage. It changes nothing and takes up to a minute." Primary button "Run check".

Running: "Checking…" with a `BusyBar`, and the sections appear as they come in (count "14 checks so far").

Result:

- Summary card: "All checks passed" (checkmark) or "2 problems and 3 warnings" (error icon), "Checked just now". Button "Run again".
- Section "Problems" (each row: cross icon + "Problem" for screen readers, the check's text as title, its detail as subtitle, notes from Hermes below).
- Section "Warnings" (warning icon).
- Section "Things to fix" (Hermes' numbered list; commands in monospace with Copy).
- `DisclosureTile` "18 passed" with the passed checks grouped by Hermes' section titles.
- Unknown lines appear as plain text rows inside their section.
- Footer: "To fix what can be fixed automatically, run 'hermes doctor --fix' on the server."

Timeout: "The check is taking longer than expected" / "It may still finish. Look again in a minute." button "Look again". Failed to start: Hermes' message, button "Try again".

App inactive on a phone: blank, as on Logs.

## Page: Usage

Job: "How much is Hermes using, and on what?"

Bar: title "Usage", subtitle "<profile>". Profile menu when there are several.

Controls: window segments "7 days", "30 days" (default), "90 days"; metric segments "Tokens", "Estimated cost".

Hierarchy:

1. **Totals card**: big number "8.4M tokens" (or "$12.40 estimated"), line "Last 30 days · 112 conversations". Under it in small text: "Input 7.9M · Output 520K · Cache reads 3.1M". With cost: "Billed $10.02" when Hermes reports billed cost.
2. **Chart**: vertical bars, one per day, the accent colour, 2 pt corner radius, zero days as a 1 pt baseline tick. Three horizontal gridlines labelled in units ("4M", "8M" tokens; "$1", "$2"). X labels: start of each week (7 and 30 days), each month (90 days); at accessibility text sizes the x labels go and the y labels shorten. Selected bar: a label above the chart "12 Nov · 812K tokens · 9 conversations" (stays in place, no floating tooltip covering bars). Height 180 pt phone, 240 pt desktop. No entrance animation when reduced motion is on; otherwise bars rise once, 200 ms.
3. Switch row "Show as table" (`GroupedSwitchRow`): replaces the chart with rows "12 Nov · 812K tokens · $3.42 · 9 conversations".
4. **Section "By model"**: rows sorted by tokens: title the model id as Hermes reports it, subtitle "790K tokens · $3.30 · 8 conversations", trailing "92%", a thin proportion bar under the subtitle (decorative).
5. Footer: "Days follow the server's time zone. Conversations count chats, messaging and scheduled tasks. Costs are estimates in US dollars."

States:

- Loading: skeleton totals and 30 grey bars, label "Loading usage".
- Empty: "No usage in the last 30 days" / "Usage appears here after Hermes answers a chat, a message or a scheduled task."
- Store unreadable (503): "Usage can't be read" / "The server's session store needs repair." button "Run a check".
- Offline: "Can't reach Hermes" / Try again.

## Accessibility (all pages)

- 44 pt (Apple) / 48 dp (Android) minimum targets; the attention dot is not a target.
- Every status in words with an icon; colours only reinforce.
- At the largest accessibility size, rows wrap to several lines, values move under titles, the chart drops x labels; nothing is cut with an ellipsis where meaning would be lost (model ids may wrap).
- WCAG AA contrast in light and dark, including the chart's gridline labels and the banner.
- Screen-reader order: headline, its button, then sections top to bottom. The chart is one node with a summary, then the days in order.
- Keyboard on desktop: Tab order follows the visual order; arrow keys move between chart bars; ⌘R / Ctrl+R refresh; Escape closes alerts with Cancel.
- Reduced motion: no bar animation, the banner does not auto-dismiss, progress spinners stay (they carry state).

## Differences by platform

|               | iPhone                              | iPad / wide desktop                            | Mac                                              |
| ------------- | ----------------------------------- | ---------------------------------------------- | ------------------------------------------------ |
| Entry         | Account menu "Server"               | Account menu in sidebar footer                 | Sidebar row "Server" with caption                |
| Layout        | Pushed pages                        | Overview beside sub-page (700 pt iPad, 900 pt) | Content area, pushed sub-pages, toolbar Back, ⌘[ |
| Confirmations | Cupertino alert                     | Alert                                          | Restrained Mac alert                             |
| Log filters   | Under the bar                       | Under the bar                                  | In the toolbar (tabs, search field)              |
| App switcher  | Logs and check blank while inactive | Same on iPad; Android also blocks screenshots  | No change                                        |
| Refresh       | Pull to refresh and bar button      | Bar button                                     | Toolbar button, ⌘R                               |
