# Spec Delta

## Purpose

Lets the user see what each agent Hermes delegated part of a reply to is doing, read its recent output, stop it, and send it a note, from the chat's Activity panel, on servers that offer these calls.

## ADDED Requirements

### Requirement: Session-scoped gateway methods

The app SHALL use the `/api/ws` methods `subagent.list`, `subagent.tail`, `subagent.interrupt` and `subagent.steer`, each addressed with the chat's live runtime `session_id` from `session.create` or `session.resume` on that connection, never a stored id. The pinned contract is Hermes Agent `d923a5eb487a17c0a68801bba9ef0f56c81040a8`; no minimum release is established, so support SHALL be learned per connection from the answers.

#### Scenario: Listing a session's agents

- **WHEN** the app sends `subagent.list {session_id: "rt-1"}`
- **THEN** it reads `{subagents: [{subagent_id, parent_id?, depth?, goal?, delegation_id?, model?, started_at?, status?, tool_count?, last_tool?, accepting_steer?}], delegations: [{delegation_id, task_index, status, goal, error?, dispatched_at?, completed_at?}]}`

#### Scenario: Reading, stopping and steering

- **WHEN** the app sends `subagent.tail`, `subagent.interrupt` or `subagent.steer` with `session_id` and `subagent_id` (and `text` for steer)
- **THEN** it reads `{subagent_id, available, text, truncated}`, `{found, subagent_id}` or `{status: queued|rejected, subagent_id, text}` respectively

#### Scenario: Errors

- **WHEN** an answer carries error 4000, 4002, 4001 or -32601
- **THEN** the app treats it as a bad request, a bad request, a session not held by this connection, or an unsupported method respectively

### Requirement: Lenient answers

The app SHALL ignore unknown fields, skip rows without `subagent_id`, read numbers given as integers, decimals or numeric strings, and read a status it does not know as ended without claiming success or failure. A malformed answer SHALL leave the previous state in place and never break the chat.

#### Scenario: A snapshot with an unknown status

- **WHEN** `subagent.list` lists an agent with status `paused_for_budget`
- **THEN** the agent is shown as Ended, without Finished or Failed, and the rest of the list is shown

#### Scenario: A row without an id

- **WHEN** `subagent.list` returns a row with no `subagent_id`
- **THEN** that row is skipped and the others are shown

#### Scenario: A malformed list answer

- **WHEN** `subagent.list` answers with `subagents` as a string
- **THEN** the rows already shown stay as they were and the read counts as failed for the backoff

### Requirement: Agents are listed in the Activity panel

The Activity panel SHALL list each delegated agent of the open chat as a row: running and starting agents under Now, ended agents and failed background delegations under This session. Each row SHALL show the agent's goal, state, run time and tools used (see Row content). Nested agents SHALL be indented under their listed parent within the same section, at most three levels deep.

#### Scenario: Two agents run and one finishes

- **WHEN** a reply delegates two agents and one of them sends `subagent.complete` with status `completed`
- **THEN** Now lists the running one with its last tool and run time, and This session lists the other as Finished with its run time

#### Scenario: A failed background delegation

- **WHEN** `subagent.list` returns a failed delegation with goal "Audit the dependency tree" and an error
- **THEN** This session lists "Audit the dependency tree" as Failed, and its detail shows the error

#### Scenario: Nested agents

- **WHEN** an agent with id a1 is listed and another agent reports `parent_id: a1` at depth 2
- **THEN** the second agent is drawn indented under a1; an agent whose parent is not listed is drawn at the top level

#### Scenario: A finished child of a running parent

- **WHEN** agent a1 is running and its child a2 has finished
- **THEN** a1 is under Now and a2 is drawn at the top level of This session, not indented

### Requirement: Row content

A row SHALL show the goal (at most two lines), then a line that starts with the state word (Starting, Running, Finished, Failed, Stopped, Ended) followed by the run time and the tools used (left out while no tool has been used), and, while the agent runs, a further line with what it is doing now. Each state SHALL have its own icon shape.

#### Scenario: A long tool preview

- **WHEN** a running agent's last tool preview is longer than the row is wide
- **THEN** the row still shows "Running", the run time and the tools used in full on its own line, and only the tool line ends with an ellipsis

### Requirement: Rows merge frames and the list

Rows SHALL come from the chat's `subagent.*` frames and from `subagent.list`. A frame SHALL win over a list answer requested before it, an ended state SHALL never go back to running, and an agent a list answer no longer contains that no frame ended SHALL show as Ended. Rows SHALL be ordered by start time; This session SHALL keep the 20 newest ended agents and say how many earlier ones are not shown.

#### Scenario: An agent that started before this device attached

- **WHEN** the user opens the Activity panel on a chat whose running agents were started from another client
- **THEN** `subagent.list` is read and those agents appear under Now although no frame named them

#### Scenario: A stale list answer

- **WHEN** a list answer saying "running" arrives after a `subagent.complete` frame for the same agent
- **THEN** the agent stays Finished

#### Scenario: More than 20 ended agents

- **WHEN** a chat has 23 ended agents
- **THEN** This session lists the 20 newest and the line "3 earlier agents not shown"

### Requirement: The roster is read only while it is shown

The app SHALL read `subagent.list` when the panel or an agent's detail becomes visible for a chat whose session is attached on the current connection, then every 5 seconds while it stays visible and an agent is running or starting. It SHALL NOT resume a session to read the list. Reads SHALL stop in the background, under App Lock and while the panel is hidden, back off after failures, and drop answers that arrive after the chat, profile, connection or account changed.

#### Scenario: The panel is closed

- **WHEN** an agent is running and the user closes the Activity panel
- **THEN** no further `subagent.list` request is sent until the panel is shown again

#### Scenario: A chat that is not attached

- **WHEN** the user opens the Activity panel on an idle chat this device has not attached to
- **THEN** no `session.resume` and no `subagent.list` is sent, and only agents known from frames are listed

#### Scenario: The first read is slow or fails

- **WHEN** the panel opens and the first `subagent.list` has not answered or answered with a server error
- **THEN** the rows known from frames are shown at once without a spinner or error, and the next read follows the backoff

### Requirement: Agent detail

Tapping an agent row SHALL open the agent's detail in the Activity panel, showing the full goal, the state, run time, tools used and the last tool, a Recent output section, and, once the agent ended, what it delivered (its completion summary or the failed delegation's error). Reading SHALL be the detail's main content; Stop agent SHALL be a secondary action placed after the output and the note field, never next to Back.

#### Scenario: Opening a finished agent

- **WHEN** the user opens the detail of an agent that completed with a summary
- **THEN** the detail shows Finished, the run time and the summary under "What it delivered"

### Requirement: Recent output

The detail SHALL read `subagent.tail` when it opens and every 2 seconds while it is visible, in the foreground and unlocked, with one read in flight. Output SHALL be selectable plain monospaced text in a bounded area that follows the end, with no links opened or markup interpreted. At most 16 KiB SHALL be held, in memory only, dropped when the detail closes. A truncated answer SHALL lose its partial first line; broken characters SHALL never show.

#### Scenario: Reading a running agent's output

- **WHEN** the user opens the detail of a running agent whose transcript holds 40 KiB
- **THEN** the latest output is shown with "Showing the latest output", the partial first line is not shown, it refreshes every 2 seconds, and no more than 16 KiB is held

#### Scenario: Output starting mid-character

- **WHEN** the 16 KiB window begins inside a multi-byte character and `truncated` is true
- **THEN** the text starts at the first whole line and contains no replacement or broken characters

#### Scenario: No output yet

- **WHEN** `subagent.tail` answers `available: false` for a running agent the app can control
- **THEN** the section says "No output yet"

#### Scenario: Long output lines at phone width

- **WHEN** an output line is wider than the output area on an iPhone
- **THEN** it wraps, its continuation starts under the text after the time and role, and the area never scrolls sideways

#### Scenario: Output that looks like a link

- **WHEN** the output contains a URL and Markdown
- **THEN** both are shown as plain text and nothing is opened

#### Scenario: A read fails

- **WHEN** a `subagent.tail` read fails after output was shown
- **THEN** the last output stays and the section says "Couldn't refresh the output." until a read succeeds

### Requirement: Output that never becomes available

A running agent whose `subagent.tail` still answers `available: false` 30 seconds after it started SHALL show "Output isn't available here." instead of "No output yet".

#### Scenario: Output never available

- **WHEN** an agent listed as started two minutes ago answers `subagent.tail` with `available: false`
- **THEN** Recent output says "Output isn't available here." instead of "No output yet"

### Requirement: Reading is not interrupted by refreshes

While the user has a text selection in the output or has scrolled away from its end, the detail SHALL NOT replace the shown text: it SHALL say "Paused" and offer "Jump to latest", which clears the selection, shows the newest output and resumes following.

#### Scenario: Selecting output

- **WHEN** the user selects a line of output to copy and a newer tail arrives
- **THEN** the selection and shown text stay, the section says Paused, and Jump to latest shows the newer output

### Requirement: Some agents cannot be controlled from this device

Hermes lists agents the chat owns through its history but controls only those of the session's current run on the server. When a re-read list still shows an agent running after `subagent.interrupt` answered `found: false`, or after `subagent.steer` answered `rejected` while `accepting_steer` was true, the app SHALL remove that agent's controls and say "Hermes doesn't let this device stop or redirect this agent. It keeps running."

#### Scenario: A running agent listed after the server rebuilt the session

- **WHEN** the list shows agent a1 running and the confirmed `subagent.interrupt` answers `found: false`, and the re-read list still shows a1 running
- **THEN** the detail says Hermes doesn't let this device stop or redirect the agent, removes its controls, and does not say it finished

#### Scenario: An agent that really finished

- **WHEN** `subagent.interrupt` answers `found: false` and a successful re-read of the list no longer shows the agent, or a completion frame arrives
- **THEN** the detail says "This agent had already finished."

#### Scenario: The re-read fails after found false

- **WHEN** `subagent.interrupt` answers `found: false` and the re-read of the list fails, times out or is unsupported
- **THEN** the detail does not say the agent finished; it says "Couldn't confirm the stop. It may still be running." and offers Stop agent again

### Requirement: Stop an agent

The detail of a running agent SHALL offer Stop agent, which SHALL ask first with the title "Stop this agent?", a message that names the agent (see The stop confirmation's message), a default Cancel and a destructive "Stop agent". Only the confirmed action SHALL send `subagent.interrupt`, once. Stopping an agent SHALL NOT stop the reply. The detail SHALL say under the action "Programs it started keep running."

#### Scenario: The user stops an agent

- **WHEN** the user presses Stop agent and confirms
- **THEN** one `subagent.interrupt` is sent, the detail says "Stopping…", and when `subagent.complete` arrives with status `interrupted` the agent shows as Stopped while the reply goes on

#### Scenario: The user cancels

- **WHEN** the user presses Stop agent and then Cancel
- **THEN** nothing is sent and the agent keeps running

#### Scenario: Stop from a row

- **WHEN** the user swipes a running agent's row on iOS and taps "Stop agent", or chooses "Stop Agent…" from the row's context menu on the Mac
- **THEN** the same confirmation opens, and nothing is sent unless the user confirms

### Requirement: The stop confirmation's message

The stop confirmation's message SHALL name the agent by its goal, cut to one line, followed by "It stops as soon as it can, along with any agents it started. A tool that is running may be cut off. What it already did stays, and the reply goes on without the rest. Programs it started keep running."

#### Scenario: Confirming a stop

- **WHEN** the user presses Stop agent on "Audit the dependency tree for packages with known vulnerabilities"
- **THEN** the confirmation's message begins with that goal on one line and says a running tool may be cut off and programs it started keep running

### Requirement: The confirmation is bound to one agent

The stop confirmation SHALL be bound to the agent's `AgentKey` (thread, profile, connection and `subagent_id`) when the action starts, and a confirmed stop SHALL go to that agent only.

#### Scenario: The list changes while the confirmation is open

- **WHEN** the confirmation for agent a1 is open and the list refreshes and reorders its rows
- **THEN** confirming sends `subagent.interrupt` for a1, whatever row now sits where a1 was

#### Scenario: The agent ends while the confirmation is open

- **WHEN** the confirmation for agent a1 is open and a1 ends
- **THEN** the confirmation closes without sending anything and the detail says "That agent has ended."

### Requirement: Stop outcomes

While a stop is in flight its control SHALL show progress and not be pressable, and no second confirmation SHALL open. On `found: false` the app SHALL re-read the list before it says anything (see the requirement on agents that cannot be controlled). A lost answer SHALL say "Couldn't confirm the stop. Checking…", re-read `subagent.list`, and never resend. A server error or 4001 SHALL say "Couldn't stop the agent. Try again." and offer Stop agent again.

#### Scenario: The answer is lost

- **WHEN** `subagent.interrupt` times out
- **THEN** the detail says it couldn't confirm the stop, `subagent.list` is read, and no second interrupt is sent

#### Scenario: Stop fails

- **WHEN** `subagent.interrupt` answers error 4001 after the app resumed the session
- **THEN** the detail says it couldn't stop the agent, offers Stop agent again, and sends nothing more by itself

#### Scenario: Double tap

- **WHEN** the user confirms and taps Stop agent again before the answer
- **THEN** no second confirmation opens and no second `subagent.interrupt` is sent

#### Scenario: The agent ends while the stop is in flight

- **WHEN** a `subagent.complete` frame with status `completed` arrives before the interrupt's answer
- **THEN** the detail shows Finished, and the answer, when it comes, changes nothing and is logged as `already_ended`

### Requirement: A stop that is accepted

When `subagent.interrupt` answers `found: true`, the detail SHALL say "Stopping…" and that a tool that is running may be cut off, and SHALL remove Stop agent.

#### Scenario: The stop is accepted

- **WHEN** `subagent.interrupt` answers `found: true`
- **THEN** the detail says "Stopping…" and "A tool that is running may be cut off.", Stop agent is no longer shown, and a typed but unsent note is replaced by the read-only "Not sent" text with Copy

### Requirement: Every check after a stop ends

"Couldn't confirm the stop. Checking…" SHALL last at most until the re-read list answers or 10 seconds pass. A successful re-read that shows the agent gone or ended SHALL show that state. Nothing SHALL be resent automatically.

#### Scenario: No answer within 10 seconds

- **WHEN** an interrupt's answer was lost and the re-read has not answered after 10 seconds
- **THEN** the detail says "Couldn't confirm the stop. It may still be running." and offers Stop agent again

### Requirement: An unconfirmed stop

A re-read that still shows the agent running, that fails, times out or is unsupported, no answer within 10 seconds, or losing the connection SHALL end the check with "Couldn't confirm the stop. It may still be running." and offer Stop agent again, which asks for confirmation again.

#### Scenario: The re-read shows the agent still running

- **WHEN** an interrupt's answer was lost and the re-read list shows the agent running
- **THEN** the detail says "Couldn't confirm the stop. It may still be running.", Stop agent can be pressed again and asks again, and no interrupt was resent

#### Scenario: The connection drops while checking

- **WHEN** the detail says "Checking…" and the connection to Hermes drops
- **THEN** the detail shows the offline note and "Couldn't confirm the stop. It may still be running." together, and Stop agent stays disabled until the connection is back

### Requirement: Redirect an agent

The detail of a running agent that accepts notes SHALL offer a note field titled "Redirect this agent", addressed "To: <goal>", with the helper "Goes only to this agent, after the step it's on. It isn't added to the chat. Notes aren't kept once you close this." and a "Send to agent" button, disabled while the text is blank, over 4,000 characters, or in flight. It SHALL hide when `accepting_steer` is false.

#### Scenario: A note is queued

- **WHEN** the user types "Only check the Go modules" and presses Send to agent
- **THEN** one `subagent.steer` is sent with that text, the field clears, the detail says "Sent. The agent gets it after its current step." and lists the note under "Your notes"

#### Scenario: Composer and note stay apart

- **WHEN** an agent's detail is open and the user types in the note field
- **THEN** the chat composer's draft is unchanged and nothing is sent to the chat

### Requirement: The note field is not the composer

The note field SHALL sit in the agent's detail, look unlike the chat composer (none of its attach, model, microphone or round send controls), and have autofill, autocorrect, suggestions and keyboard learning off.

#### Scenario: Typing a note

- **WHEN** the user focuses the note field on an iPhone
- **THEN** the keyboard offers no suggestions or autocorrection, and no attach, model or microphone control is shown

### Requirement: Note length

A note SHALL be at most 4,000 characters, counted on the trimmed text. The limit is the app's own; Hermes sets none. A counter SHALL show from 3,500 characters.

#### Scenario: A note that is too long

- **WHEN** the note holds 4,001 characters
- **THEN** the field shows "4,001 / 4,000" and Send to agent is disabled

### Requirement: Note outcomes

A note SHALL be sent once with its trimmed text. `rejected` SHALL keep the text with "This agent isn't taking notes now." A lost answer SHALL keep the text, never resend, and say "Couldn't confirm the note was sent. Sending it again may deliver it twice." A server error or 4001 SHALL keep it with "Couldn't send the note. Try again." After a lost answer Send to agent SHALL stay enabled, and only the user's tap sends the text again.

#### Scenario: The note is rejected

- **WHEN** `subagent.steer` answers `rejected` for an agent the list shows with `accepting_steer: false`
- **THEN** the typed text stays in the field and the detail says the agent isn't taking notes now

#### Scenario: Sending fails

- **WHEN** `subagent.steer` answers a server error
- **THEN** the text stays and the detail says it couldn't send the note

### Requirement: Notes are not kept

Typed text and "Your notes" SHALL live only while the detail is open. Closing the detail SHALL drop them. A note in flight when the detail closes SHALL finish sending in the background; it SHALL NOT be retried and no outcome SHALL be shown for it later. Typed text SHALL never be dropped while the detail stays open: when Stop is accepted, the agent ends, or the agent turns out not to be controllable here, it SHALL stay readable as "Not sent" with Copy.

#### Scenario: Closing the detail with a note in flight

- **WHEN** the user sends a note and closes the detail before the answer
- **THEN** the `subagent.steer` call completes, nothing is resent, and reopening the detail shows an empty field and no "Your notes"

#### Scenario: Stop accepted with a typed note

- **WHEN** the note field holds unsent text and `subagent.interrupt` answers `found: true`
- **THEN** the field is replaced by the read-only text marked "Not sent" with Copy

#### Scenario: Send again after a lost answer

- **WHEN** a note's answer was lost
- **THEN** the text stays, Send to agent can be pressed, and nothing is sent until the user presses it

### Requirement: A note that arrives too late

If the ended agent's completion summary contains Hermes' notice "[steer did not land — the subagent finished before it could be delivered", or a failed delegation's error contains "[steer did not land before the subagent stopped", the detail SHALL say "Your note didn't reach the agent. It had finished first."; otherwise it SHALL claim neither delivery nor loss.

#### Scenario: A note that missed

- **WHEN** a note was queued and the agent's `subagent.complete` summary contains "[steer did not land — the subagent finished before it could be delivered"
- **THEN** the detail says "Your note didn't reach the agent. It had finished first."

#### Scenario: A note that missed a failed agent

- **WHEN** a note was queued and the agent's failure error contains "[steer did not land before the subagent stopped"
- **THEN** the detail says "Your note didn't reach the agent. It had finished first."

### Requirement: An agent that ends while its detail is open

When the agent shown in an open detail ends, the detail SHALL stay open, show the new state, remove Stop agent and the note field with "This agent has finished. Stop and notes no longer apply." (or the Failed or Stopped wording), keep the last output read under "Last output" without refreshing it, and keep an unsent note readable with Copy and "Not sent". A stop or note in flight SHALL report its own answer first.

#### Scenario: The agent finishes while the user reads its output

- **WHEN** the detail of a running agent is open and `subagent.complete` arrives with status `completed`
- **THEN** the detail shows Finished, the summary, the last output under "Last output", and no Stop or note field, and no further `subagent.tail` is sent

#### Scenario: An unsent note when the agent ends

- **WHEN** the user has typed a note without sending it and the agent ends
- **THEN** the note stays readable with Copy and "Not sent", and cannot be sent

### Requirement: Calls go over the connection that holds the session

Every `subagent.*` call SHALL be sent on a connection on which the chat's session is attached, for the profile the chat was listed under. Stop and Redirect SHALL attach the session with `session.resume` first when it is not attached. A 4001 answer to a read SHALL mark the session as not attached on this connection, leaving rows to frames; a 4001 answer to `subagent.interrupt` or `subagent.steer` SHALL be reported and SHALL NOT be repeated without the user.

#### Scenario: The connection dropped since the agents were listed

- **WHEN** the socket was replaced and the user confirms Stop agent
- **THEN** the app resumes the chat's session on the new connection and sends one `subagent.interrupt` with the new runtime session id

### Requirement: A server without the calls

Method-not-found SHALL turn off only what needs that method, for that connection: `subagent.list` leaves rows to frames; `subagent.tail` removes Recent output; `subagent.interrupt` or `subagent.steer` removes its control after saying "This server can't stop agents." or "This server can't take notes for agents." once where it was pressed. None SHALL show as a chat failure; the next connection SHALL try again.

#### Scenario: An older gateway

- **WHEN** every `subagent.*` method answers method-not-found
- **THEN** agent rows still appear from frames, the detail shows the goal and state only, and no Stop, note field, or error is shown

#### Scenario: Output missing, notes offered

- **WHEN** `subagent.tail` answers method-not-found and `subagent.steer` answers `queued`
- **THEN** the detail has no Recent output section and keeps the note field

### Requirement: Offline detail

While the app has no connection to Hermes, an open agent detail SHALL keep the last output read and any typed note, say "You're offline. This is the last output read. Stop and notes work again once Hermes is back.", and disable Stop agent and Send to agent. Nothing SHALL be queued to send later.

#### Scenario: The connection drops with a detail open

- **WHEN** an agent's detail is open with a typed note and the connection to Hermes drops
- **THEN** the output stays, the note stays in the field, the offline sentence shows, and Stop agent and Send to agent cannot be pressed

#### Scenario: The connection comes back

- **WHEN** the connection is back and the agent is still running
- **THEN** the offline sentence goes, the output refreshes, and Stop agent and Send to agent can be pressed again; nothing was sent while offline

### Requirement: One filled action in the detail

Send to agent SHALL be the only filled button in an agent's detail. Stop agent SHALL be a tinted destructive button whose label meets WCAG AA contrast on its tint in light and dark themes.

#### Scenario: A running agent's detail

- **WHEN** the detail of a running agent that accepts notes is open
- **THEN** Send to agent is the only filled button and Stop agent is drawn tinted, after the output and the note field

### Requirement: Reaching an agent from the transcript

Where the chat has an Activity panel (the main window and Mac conversation windows), each agent row of the transcript's agent card SHALL offer "Show details" (the row itself, and a context menu item on the Mac), opening the panel at that agent's detail. In the Mac quick panel the card SHALL stay read-only.

#### Scenario: From the transcript on a phone

- **WHEN** the user taps an agent row in the transcript's "Used 3 agents" card on an iPhone
- **THEN** the Activity sheet opens at that agent's detail

#### Scenario: The quick panel

- **WHEN** a reply in the quick panel delegates an agent
- **THEN** the transcript card shows it with no details action and no stop

### Requirement: Output and notes stay private

Agent output, goals, summaries, errors and notes SHALL NOT be written to logs, telemetry, preferences, files, the surface snapshot, notifications, widgets, Live Activities, Spotlight or the watch.

#### Scenario: A notification after a reply

- **WHEN** a reply with delegated agents finishes while the app is in the background
- **THEN** the reply notification says nothing about the agents' goals or output

### Requirement: Held data is dropped when the context changes

While App Lock covers the app, tail and list reads SHALL stop and held output SHALL be dropped, to be read again after unlock. Signing out, an expired session, changing server, switching profile and closing the chat SHALL drop every held output, unsent note and list answer and cancel reads in flight.

#### Scenario: App Lock while a detail is open

- **WHEN** the agent's detail is open and the app is locked
- **THEN** reads stop and the held output is dropped, and after unlock the output is read again

#### Scenario: Profile switch

- **WHEN** the user switches the chat to another profile with an agent's detail open
- **THEN** the detail closes, its output and any unsent note are dropped, and a late tail answer is discarded

#### Scenario: Sign-out

- **WHEN** the user signs out while an agent's detail is open with an unsent note
- **THEN** the detail, output, note and rows are dropped and no `subagent.*` call is sent afterwards

#### Scenario: Server change

- **WHEN** the user changes server while a list read is in flight
- **THEN** its answer is discarded and the new server's chats show no rows from the old one

### Requirement: Accessible rows and controls

Rows and controls SHALL have targets of at least 44 by 44 points on iPhone and iPad and 48 by 48 dp on Android; on the Mac, where they are used with a pointer, at least 28 points. A row's screen-reader label SHALL read goal, state, tools used and run time, with the custom actions "Show details" and "Stop agent" named as the swipe and menu name them. State SHALL be a word, not colour alone.

#### Scenario: VoiceOver on an agent row

- **WHEN** VoiceOver focuses a running agent row
- **THEN** it reads the goal, "Running", the number of tools used and the run time, and offers the actions Show details and Stop agent

#### Scenario: Android rows

- **WHEN** the user swipes a running agent's row on Android
- **THEN** nothing happens; a tap opens the detail, where Stop agent is offered

### Requirement: Accessible detail and motion

State changes of the agent whose detail is open SHALL be announced once, politely. Text SHALL scale to the largest accessibility size without cutting the goal or controls, output text included. Running indicators SHALL be still when reduced motion is on.

#### Scenario: Reduced motion

- **WHEN** reduced motion is on and an agent is running
- **THEN** the row shows a still running icon instead of an animated one

### Requirement: Largest text sizes

At accessibility text sizes rows SHALL stack (icon and chevron above the text), the detail's bar text SHALL keep its normal size, the output SHALL drop its hanging indent and keep at least five lines visible, the note field SHALL grow to five lines, and Send to agent and Stop agent SHALL be full width, one above the other.

#### Scenario: Largest accessibility text size

- **WHEN** the text size is the largest accessibility size and the Activity panel and an agent's detail are open
- **THEN** each row shows its whole goal and lines at full width under its icon and chevron, the output text is at the chosen size, wraps without sideways scrolling and shows at least five lines, and Send to agent and Stop agent are full width, stacked, with their whole labels

### Requirement: Screen readers and refreshing output

The output area SHALL NOT be a live region, and a refresh SHALL NOT move the screen reader's focus. Outcome banners (sent, couldn't send, the stop outcomes, offline) SHALL be announced once, politely.

#### Scenario: Output refreshes while VoiceOver reads it

- **WHEN** VoiceOver focus is on the output and a newer tail arrives
- **THEN** nothing is announced and the focus stays where it was

#### Scenario: A note is sent

- **WHEN** `subagent.steer` answers `queued`
- **THEN** "Sent. The agent gets it after its current step." is announced once, politely

### Requirement: Keyboard use

On the Mac and other keyboard layouts the detail's focus order SHALL follow the visual order: back, goal, output, note field, Send to agent, Stop agent. Escape SHALL go back from the detail to the list. Command-Return on Apple platforms and Control-Enter elsewhere SHALL send a note from the field; Return alone SHALL add a line.

#### Scenario: Sending with the keyboard on a Mac

- **WHEN** the note field has focus and holds text and the user presses Command-Return
- **THEN** the note is sent to the agent

### Requirement: Observability

The app SHALL record a `subagent.rpc` span per call with `method` and `outcome`; log events `subagent.stop` (`outcome`), `subagent.redirect` (`outcome`) and `subagent.unsupported` (`method`, once per connection); and breadcrumbs `subagent.detail.opened` (`source`), `subagent.detail.closed`, `subagent.stop.pressed`, `subagent.stop.confirmed` and `subagent.redirect.sent`, with fixed words, counts and size buckets only.

#### Scenario: Stopping logs only the outcome

- **WHEN** a confirmed stop answers `found: true`
- **THEN** `subagent.stop` is logged with `outcome: stopped` and no goal, note, output, summary, tool name, model, id or profile
