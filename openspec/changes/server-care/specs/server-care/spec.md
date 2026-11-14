# Spec Delta

## Purpose

Lets the owner of a self-hosted Hermes see from the app whether the server is healthy and fix the common problems: read its status and version, update it, restart or start the messaging gateway, read recent logs, run the server check and see usage.

## ADDED Requirements

### Requirement: Backend contract

The feature SHALL use only these dashboard routes, verified at Hermes `d923a5eb` (0.22.2): `GET /api/status?profile=`, `GET /api/health`, `GET /api/hermes/update/check?force=`, `POST /api/hermes/update`, `GET /api/hermes/update/receipt`, `GET /api/actions/{name}/status?lines=`, `POST /api/gateway/restart?profile=`, `POST /api/gateway/start?profile=`, `GET /api/logs`, `POST /api/ops/doctor?profile=` and `GET /api/analytics/usage?days=&profile=`.

#### Scenario: Every request is one of the listed routes

- **WHEN** the user opens every part of the Server screen and uses every action
- **THEN** each request the app sends is one of the listed routes, and every profile-scoped request carries the chat's profile explicitly

#### Scenario: Responses are read leniently

- **WHEN** a response lacks an optional field or holds a value of an unexpected type
- **THEN** that field is treated as unknown, the rest of the response is used, and nothing is reported as a problem because of it

### Requirement: No roles

Hermes has no roles: anyone signed in to the dashboard SHALL be offered every part, so there is no non-admin case beyond the usual sign-in handling.

#### Scenario: Signed-in user

- **WHEN** any signed-in user opens the Server screen
- **THEN** every part the server offers is shown with its actions, and a 401 or 403 is handled by the existing sign-in path

### Requirement: Server screen entry points

The app SHALL offer a Server screen from the account menu on iPhone, iPad, Android, Windows and Linux (an item "Server" after "Connection details"), and from a "Server" row after Profiles in the Mac sidebar. Connection details SHALL keep its place.

#### Scenario: Phone

- **WHEN** the user opens the account menu on an iPhone and chooses Server
- **THEN** the Server screen opens as a page with Back

#### Scenario: Mac

- **WHEN** the user selects Server in the Mac sidebar
- **THEN** the Server page shows in the content area with the Mac toolbar, and its sub-pages go back with the toolbar's Back and ⌘[

### Requirement: Attention mark

When the server status needs attention (see the status headline requirement), the account button SHALL show a dot and announce "Account, server needs attention" to screen readers, the menu item SHALL read "Server · needs attention", and the Mac sidebar row SHALL show the caption "Needs attention". The mark SHALL NOT rely on colour alone.

#### Scenario: Gateway failed

- **WHEN** the status reports `gateway_state: startup_failed`
- **THEN** the account button shows the dot and its accessible label says the server needs attention

#### Scenario: Low disk is not urgent

- **WHEN** the only finding is `disk.pressure: elevated`
- **THEN** no mark is shown, and the Server screen still says "Disk space is getting low: <free> free"

### Requirement: Status headline

The Server screen SHALL start with one sentence about the server's health and, when one fixes it, one action. Findings SHALL be ranked: unreachable, unreadable session store, gateway failed, gateway not responding, gateway off with messaging channels configured, disk almost full, out-of-memory restart, channels offline, low memory or disk; else "Everything looks good".

#### Scenario: Healthy

- **WHEN** `/api/status` reports `overall: ok`, a running gateway and no pressure
- **THEN** the headline reads "Everything looks good" with no action

#### Scenario: Gateway not responding

- **WHEN** `gateway_heartbeat_stale_s` is a number
- **THEN** the headline reads "The messaging gateway isn't responding" with the action Restart gateway

#### Scenario: Session store unreadable

- **WHEN** `components.storage.reason` is `corrupt`
- **THEN** the headline reads "Hermes can't read its session store" with the action Run a check

#### Scenario: Unreachable

- **WHEN** the status request fails with a connection error
- **THEN** the headline reads "Can't reach Hermes" with Try again

### Requirement: Status details

Below the headline the screen SHALL show the Hermes version and release date, the messaging gateway's state in words and the channels connected out of those configured, disk free space and memory pressure when reported, and the session store's state. States SHALL be shown as words and icons, not colour alone.

#### Scenario: Channels

- **WHEN** `components.platforms` reports 2 configured and 1 connected
- **THEN** the gateway section reads "1 of 2 messaging channels connected"

#### Scenario: Older server without pressure fields

- **WHEN** `/api/status` has no `memory`, `disk` or `components`
- **THEN** those rows are left out and no finding is made from their absence

### Requirement: Update availability

The screen SHALL show whether an update is available from `GET /api/hermes/update/check` (cached on open, `force=true` on Check now): "Up to date", "Update available · <n> changes" with up to 20 change summaries, a rollback notice when `rollback_to` is set, or Hermes' message when the check could not run.

#### Scenario: Behind

- **WHEN** the check reports `behind: 12`, `can_apply: true` and commits
- **THEN** the Updates row reads "Update available · 12 changes" and the Update page lists the summaries and offers Update Hermes

#### Scenario: Check could not run

- **WHEN** the check reports `behind: null`
- **THEN** the row shows Hermes' message and a Check now action, and offers no update

### Requirement: Updates the dashboard cannot apply

When `can_apply` is false or `/api/status.can_update_hermes` is false, the app SHALL NOT offer Update Hermes. It SHALL show Hermes' message and, when `update_command` is not empty, the command with a Copy action.

#### Scenario: Docker install

- **WHEN** the check reports `install_method: docker` with a message and an update command
- **THEN** the Update page shows the message, the command and Copy, and no Update Hermes button

#### Scenario: Managed host

- **WHEN** the check reports `install_method: managed-runtime` and an empty `update_command`
- **THEN** only the message is shown, with no command row

### Requirement: Update confirmation

Update Hermes SHALL ask first, saying that Hermes restarts, that replies running in this app and on messaging channels stop, and how many are running now when known. Cancel SHALL be the default; nothing SHALL be sent before the user confirms.

#### Scenario: Replies running

- **WHEN** one reply in this app is running and the status reports `active_agents: 2`
- **THEN** the confirmation says that 1 reply in this app and 2 conversations on messaging channels will stop

#### Scenario: Cancel

- **WHEN** the user cancels
- **THEN** no update request is sent

### Requirement: Update progress

After confirmation the app SHALL send `POST /api/hermes/update` once, follow the action's status, then the restart through `GET /api/health`, and SHALL decide the outcome from the update receipt naming the same action id, never from liveness alone. It SHALL never resend the update request.

#### Scenario: Success

- **WHEN** the action runs, the dashboard stops answering, `/api/health` answers again with a new `commit`, and the receipt for the same action id reports `outcome: success` and `post_version: 0.23.0`
- **THEN** the Update page reads "Hermes is up to date · 0.23.0", the app probes the connection again, and the status is read again

#### Scenario: Partial

- **WHEN** the receipt reports `outcome: partial` with a `user_action` reason
- **THEN** the page reads "Hermes updated, with one thing left to do" and shows the reason

#### Scenario: Failed before restarting

- **WHEN** the action status reports `running: false` with `exit_code: 1` and the receipt reports `failed`
- **THEN** the page reads "The update didn't finish", shows the version still running, and offers Show details with the last log lines

#### Scenario: Refused

- **WHEN** `POST /api/hermes/update` answers `ok: false` with `error: docker_update_unsupported`
- **THEN** the page shows Hermes' message and the command to copy, and no progress starts

#### Scenario: Already running

- **WHEN** the answer carries `already_running: true` and an action id
- **THEN** the app follows that action as its own

#### Scenario: Receipt cannot be matched

- **WHEN** the dashboard is back but the receipt is missing or names another action for 60 seconds
- **THEN** the page reads "Hermes is back, but the app can't confirm the update" with the version now running

#### Scenario: The proxy answers 502 during the restart

- **WHEN** a reverse proxy in front of Hermes answers `/api/health` with HTTP 502 and an HTML page while the dashboard is down
- **THEN** the update stays in the restarting phase, and only an HTTP 200 JSON answer with `ok: true` moves it on

#### Scenario: Updated but the old server still runs

- **WHEN** the action ends with `exit_code: 0`, the receipt for the same action reports `success`, and `/api/health` still answers with the commit from before the update
- **THEN** the page reads "Hermes updated, but the server is still running the old version. Restart Hermes on the server to finish." and offers Check again, and no success is reported

#### Scenario: Not back

- **WHEN** `/api/health` has not answered for 15 minutes
- **THEN** the page says Hermes hasn't come back and may need to be started on the server, and offers Keep waiting and Dismiss

### Requirement: Update survives leaving the screen

An update's progress SHALL continue when the user leaves the Server screen, and SHALL be resumed after the app restarts within one hour. The action id, start time and the version and commit before it SHALL be kept in preferences under the account key until the update is resolved, sign-out or a server change.

#### Scenario: Leave and return

- **WHEN** the user opens a chat during an update and returns to Server
- **THEN** the Update page shows the current phase, and meanwhile the Mac sidebar row's caption reads "Updating…"

#### Scenario: App restarted

- **WHEN** the app is relaunched 10 minutes after an update started
- **THEN** it reads the action status or receipt for the saved action id and shows the outcome

### Requirement: Restart banner

While an update the user started is restarting Hermes or verifying it, the main window SHALL show a banner above every destination: "Hermes is restarting after the update. Chats continue when it's back." After success it SHALL read "Hermes <version> is ready" and dismiss itself after 6 seconds, unless reduced motion is on, when it stays until dismissed.

#### Scenario: During restart

- **WHEN** the update is in the restarting phase and the user is on Kanban
- **THEN** the banner is shown on Kanban, and tapping it opens the Update page

#### Scenario: Conversation window

- **WHEN** a Mac conversation window is open during the restart
- **THEN** the window shows no banner

### Requirement: Gateway restart and start

Restart gateway SHALL ask first and then send `POST /api/gateway/restart?profile=<chat profile>`; Start gateway, offered while the gateway is not running, SHALL send `POST /api/gateway/start`. The row SHALL show progress until `/api/status` reports the gateway running again.

#### Scenario: Back

- **WHEN** the restart child exits 0 and `/api/status` reports `gateway_running: true` and `gateway_state: running` within 90 seconds
- **THEN** the row reads "Running again" and the status is read again

#### Scenario: Child still running

- **WHEN** the restart child is still running after 30 seconds and the status then reports the gateway running
- **THEN** the restart counts as done

#### Scenario: Failed

- **WHEN** the restart child exits with a non-zero code
- **THEN** the row reads "The gateway didn't restart" and offers Show logs and Try again

#### Scenario: Slow

- **WHEN** the gateway is not reported running 90 seconds after the restart
- **THEN** the row reads "The gateway hasn't come back yet" and offers Show logs

#### Scenario: Restart answer lost

- **WHEN** the answer to `POST /api/gateway/restart` is lost to a timeout
- **THEN** the app reads the action status and `/api/status` to learn whether the restart started, and does not send the restart request again unless the user confirms Try again

#### Scenario: Refused

- **WHEN** start answers HTTP 409, or restart answers HTTP 500 with a detail
- **THEN** Hermes' detail is shown in the row and nothing is retried automatically

### Requirement: Gateway restart confirmation

The confirmation SHALL say that chats in this app keep running, that messaging channels and scheduled tasks pause until the gateway is back, how many messaging conversations will stop when `active_agents` is above 0, and, when `gateway_shared_with` lists two or more profiles, that their bots reconnect too, naming them.

#### Scenario: Shared gateway

- **WHEN** the status reports `gateway_shared_with: ["default", "work"]`
- **THEN** the confirmation says the bots of default and work reconnect too, and the button reads "Restart for all"

#### Scenario: Cancel

- **WHEN** the user cancels the confirmation
- **THEN** no restart request is sent

### Requirement: Logs

The Logs page SHALL read `GET /api/logs` for the chat's profile with `file` errors (default), agent or gateway, `lines` 200 (500 after Show older), an optional level of WARNING or ERROR, and an optional search sent 400 ms after typing stops. Lines SHALL be shown newest first with time, level as a word, source and message.

#### Scenario: Filter

- **WHEN** the user picks Agent and "Warnings and errors" and types "timeout"
- **THEN** the app requests `file=agent&level=WARNING&search=timeout&lines=200` and shows only that answer

#### Scenario: Traceback

- **WHEN** a line does not start with a time and level
- **THEN** it is shown as a continuation of the line before it

#### Scenario: Empty

- **WHEN** the answer has no lines
- **THEN** the page reads "Nothing logged yet" without a filter, or "No lines match" with one

### Requirement: Log and check privacy

Log lines and server check output SHALL be held in memory only and SHALL NOT be written to disk, preferences, telemetry, breadcrumbs, notifications, widgets or the surface snapshot. Log lines SHALL be dropped when the Logs page closes. Both SHALL be dropped under App Lock, on sign-out, server change and profile switch.

#### Scenario: App Lock

- **WHEN** App Lock covers the app while the Logs page is open
- **THEN** the lines are dropped and read again after unlock

#### Scenario: App switcher on a phone

- **WHEN** the app becomes inactive on iOS or Android while the Logs or Server check page is shown
- **THEN** the page draws no text until the app is active again, and on Android the window is marked secure while either page is on screen

#### Scenario: Copy

- **WHEN** the user chooses Copy shown lines
- **THEN** the app first warns that logs can contain private details, and copies only after confirmation

### Requirement: Server check

Run a check SHALL send `POST /api/ops/doctor?profile=<chat profile>`, follow `GET /api/actions/doctor/status` until the run ends (at most 3 minutes), and show the output after its latest start header as a summary, problems, warnings, passed checks (folded) and Hermes' list of things to fix. The last result SHALL stay available until sign-out, server change, profile switch or App Lock.

#### Scenario: Problems found

- **WHEN** the output holds two `✗` lines, three `⚠` lines and "Found 2 issue(s) to address:"
- **THEN** the summary reads "2 problems and 3 warnings", problems are listed first and the fixes are numbered

#### Scenario: All passed

- **WHEN** the output ends with "All checks passed!"
- **THEN** the summary reads "All checks passed"

#### Scenario: Unknown lines

- **WHEN** a line matches no known shape
- **THEN** it is shown as plain text in its section

#### Scenario: Timeout

- **WHEN** the run has not ended after 3 minutes
- **THEN** the page reads "The check is taking longer than expected" and offers Check again later, without sending another run

### Requirement: Usage

The Usage page SHALL show, for the chat's profile and the last 7, 30 (default) or 90 days, tokens (input plus output) or estimated cost in US dollars per day as bars with one bar per calendar day (missing days as zero), totals, and a per-model list sorted by tokens.

#### Scenario: Thirty days

- **WHEN** `/api/analytics/usage?days=30` answers 12 days of data
- **THEN** the chart shows 30 bars, 18 of them zero, and the totals match `totals`

#### Scenario: Cost basis

- **WHEN** the user switches to Estimated cost and `total_actual_cost` is above 0
- **THEN** the bars use `estimated_cost`, the axis is labelled in dollars, and the totals also show the billed amount

#### Scenario: No usage

- **WHEN** every day is zero
- **THEN** the page reads "No usage in the last 30 days" and explains that usage appears after Hermes answers a chat, a message or a scheduled task

#### Scenario: Store unreadable

- **WHEN** the route answers HTTP 503
- **THEN** the page says usage can't be read because the session store needs repair and offers Run a check

### Requirement: Usage accessibility

The usage chart SHALL expose a summary (metric, window, total, highest day) and each bar's date and value to screen readers in date order, SHALL offer a table with the same rows, SHALL label units on its axis, SHALL drop axis labels before truncating them at large text sizes, and SHALL not animate under reduced motion.

#### Scenario: Screen reader

- **WHEN** VoiceOver focuses the chart
- **THEN** it reads the summary, and swiping moves through the days, each read as "<date>: <value> <unit>, <n> conversations"

#### Scenario: Table

- **WHEN** the user turns on Show as table
- **THEN** the chart is replaced by a list of days with tokens, estimated cost and conversations

### Requirement: Old servers

A part whose route answers 404 (other than the receipt's "No update receipt" answer) or 405, or a non-JSON body, SHALL be hidden without an error message. With every optional part hidden, the screen SHALL still show the status and version.

#### Scenario: No doctor route

- **WHEN** `POST /api/ops/doctor` answers 404
- **THEN** Run a check is not offered and no error is shown

#### Scenario: No receipt yet

- **WHEN** `/api/hermes/update/receipt` answers 404 with "No update receipt found" before any update
- **THEN** nothing is shown about a previous update and nothing is hidden

### Requirement: Scope changes

On a profile switch the profile-scoped parts SHALL be read again for the new profile and late answers for the old one SHALL be dropped. On sign-out and server change all server care state SHALL be cleared and polling SHALL stop.

#### Scenario: Profile switch during a log read

- **WHEN** the chat switches from profile default to work while a log read for default is in flight
- **THEN** the default answer is discarded and the page shows work's log

#### Scenario: Sign-out during an update

- **WHEN** the user signs out during an update
- **THEN** polling stops, the banner disappears and the saved update record is deleted

### Requirement: Accessibility

Every control SHALL be at least 44 points (48 dp on Android) high, every state SHALL be conveyed in words, text SHALL wrap at the largest accessibility size without losing meaning, contrast SHALL meet WCAG AA in both themes, and destructive confirmations SHALL make Cancel the default.

#### Scenario: Largest text

- **WHEN** the system text size is the largest accessibility size
- **THEN** every row of the Server screen wraps, no value is cut, and the chart drops its axis labels while keeping its summary

#### Scenario: Bars at the largest text size

- **WHEN** the 90-day window is shown at the largest accessibility text size on a phone
- **THEN** each bar keeps a tap target at least 44 points (48 dp) wide, the chart scrolls sideways (starting at the newest day) instead of shrinking the targets, and the table remains available

#### Scenario: Thirty days on a phone

- **WHEN** the 30-day window is shown on a phone
- **THEN** all 30 bars fit the width without scrolling, pressing and dragging across the chart selects the nearest bar and shows its value above the chart, and each day stays reachable through its semantics node and the table

### Requirement: Telemetry

Server care SHALL record only fixed names, enums, counts and buckets: spans for each request and run, outcome log events and breadcrumbs for user steps. It SHALL NOT record log lines, search text, check output, commands, messages from Hermes, profile names, model ids, action ids, URLs or paths.

#### Scenario: Update outcome

- **WHEN** an update finishes with success after 4 minutes
- **THEN** `server_care.update_finished` is logged with `outcome: success`, `came_back: true` and `duration: 3-10m` and nothing else

#### Scenario: Log search

- **WHEN** the user searches the logs
- **THEN** the `server_care.logs.fetch` span carries `filtered: true` and not the search text
