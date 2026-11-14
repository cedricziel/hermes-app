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

### Requirement: Agents are listed in the Activity panel

The Activity panel SHALL list each delegated agent of the open chat as a row: running and starting agents under Now, ended agents and failed background delegations under This session. A row SHALL show the goal (at most two lines), the state as a word and an icon (Starting, Running, Finished, Failed, Stopped, Ended), what it is doing now while it runs, the tools used, and its run time. Nested agents SHALL be indented under their listed parent.

#### Scenario: Two agents run and one finishes

- **WHEN** a reply delegates two agents and one of them sends `subagent.complete` with status `completed`
- **THEN** Now lists the running one with its last tool and run time, and This session lists the other as Finished with its run time

#### Scenario: A failed background delegation

- **WHEN** `subagent.list` returns a failed delegation with goal "Audit the dependency tree" and an error
- **THEN** This session lists "Audit the dependency tree" as Failed, and its detail shows the error

### Requirement: Rows merge frames and the list

Rows SHALL come from the chat's `subagent.*` frames and from `subagent.list`. A frame SHALL win over a list answer requested before it, an ended state SHALL never go back to running, and an agent a list answer no longer contains that no frame ended SHALL show as Ended. Rows SHALL be ordered by start time; This session SHALL keep the 20 newest ended agents and say how many earlier ones are not shown.

#### Scenario: An agent that started before this device attached

- **WHEN** the user opens the Activity panel on a chat whose running agents were started from another client
- **THEN** `subagent.list` is read and those agents appear under Now although no frame named them

#### Scenario: A stale list answer

- **WHEN** a list answer saying "running" arrives after a `subagent.complete` frame for the same agent
- **THEN** the agent stays Finished

### Requirement: The roster is read only while it is shown

The app SHALL read `subagent.list` when the panel or an agent's detail becomes visible for a chat whose session is attached on the current connection, then every 5 seconds while it stays visible and an agent is running or starting. It SHALL NOT resume a session to read the list. Reads SHALL stop in the background, under App Lock and while the panel is hidden, back off after failures, and drop answers that arrive after the chat, profile, connection or account changed.

#### Scenario: The panel is closed

- **WHEN** an agent is running and the user closes the Activity panel
- **THEN** no further `subagent.list` request is sent until the panel is shown again

#### Scenario: A chat that is not attached

- **WHEN** the user opens the Activity panel on an idle chat this device has not attached to
- **THEN** no `session.resume` and no `subagent.list` is sent, and only agents known from frames are listed

### Requirement: Agent detail

Tapping an agent row SHALL open the agent's detail in the Activity panel, showing the full goal, the state, run time, tools used and the last tool, a Recent output section, and, once the agent ended, what it delivered (its completion summary or the failed delegation's error).

#### Scenario: Opening a finished agent

- **WHEN** the user opens the detail of an agent that completed with a summary
- **THEN** the detail shows Finished, the run time and the summary under "What it delivered"

### Requirement: Recent output

The detail SHALL read `subagent.tail` when it opens and every 2 seconds while it is visible, in the foreground and unlocked, with one read in flight. Output SHALL be selectable plain monospaced text in a bounded scrolling area that follows the end until the user scrolls up; links SHALL NOT open and markup SHALL NOT be interpreted. At most 16 KiB SHALL be held, in memory only, and dropped when the detail closes.

#### Scenario: Reading a running agent's output

- **WHEN** the user opens the detail of a running agent whose transcript holds 40 KiB
- **THEN** the latest output is shown with "Showing the latest output", the partial first line is not shown, it refreshes every 2 seconds, and no more than 16 KiB is held

#### Scenario: No output yet

- **WHEN** `subagent.tail` answers `available: false` for a running agent
- **THEN** the section says "No output yet"

#### Scenario: Output that looks like a link

- **WHEN** the output contains a URL and Markdown
- **THEN** both are shown as plain text and nothing is opened

### Requirement: Stop an agent

The detail of a running agent SHALL offer Stop agent, which SHALL ask first with the title "Stop this agent?", the message "It stops after the step it's on. Work it already did stays, and Hermes gets what it had so far and goes on with the reply. Agents it started stop too; programs it started keep running.", a default Cancel and a destructive "Stop agent". Only the confirmed action SHALL send `subagent.interrupt`, once. Stopping an agent SHALL NOT stop the reply.

#### Scenario: The user stops an agent

- **WHEN** the user presses Stop agent and confirms
- **THEN** one `subagent.interrupt` is sent, the detail says "Stopping…", and when `subagent.complete` arrives with status `interrupted` the agent shows as Stopped while the reply goes on

#### Scenario: The user cancels

- **WHEN** the user presses Stop agent and then Cancel
- **THEN** nothing is sent and the agent keeps running

### Requirement: Stop outcomes

While a stop is in flight its control SHALL show progress and not be pressable. On `found: false` the detail SHALL say "This agent had already finished." and re-read the list. When the answer is lost (timeout or closed connection) it SHALL say "Couldn't confirm the stop. Checking…", re-read `subagent.list`, and SHALL NOT send the stop again by itself.

#### Scenario: The answer is lost

- **WHEN** `subagent.interrupt` times out
- **THEN** the detail says it couldn't confirm the stop, `subagent.list` is read, and no second interrupt is sent

#### Scenario: Already finished

- **WHEN** `subagent.interrupt` answers `found: false`
- **THEN** the detail says the agent had already finished

### Requirement: Redirect an agent

The detail of a running agent that accepts notes SHALL offer a note field titled "Redirect this agent", addressed "To: <goal>", with the placeholder "Tell this agent what to do differently", the helper "Goes only to this agent, after the step it's on. It isn't added to the chat." and a "Send to agent" button disabled while the text is blank or a note is in flight. The field SHALL sit inside the detail, look unlike the chat composer, and be hidden when `accepting_steer` is false.

#### Scenario: A note is queued

- **WHEN** the user types "Only check the Go modules" and presses Send to agent
- **THEN** one `subagent.steer` is sent with that text, the field clears, the detail says "Sent. The agent gets it after its current step." and lists the note under "Your notes"

#### Scenario: Composer and note stay apart

- **WHEN** an agent's detail is open beside the chat and the user types in the note field
- **THEN** the chat composer's draft is unchanged and nothing is sent to the chat

### Requirement: Note outcomes

A note SHALL be sent once with its trimmed text. On `rejected` the text SHALL stay and the detail SHALL say "This agent isn't taking notes now." On a lost answer the text SHALL stay with "Couldn't confirm the note was sent. Sending it again may deliver it twice." and SHALL NOT be resent by the app. When the agent's completion summary says a note did not land, the detail SHALL say "Your note arrived after the agent finished."

#### Scenario: The note is rejected

- **WHEN** `subagent.steer` answers `rejected`
- **THEN** the typed text stays in the field and the detail says the agent isn't taking notes now

#### Scenario: A note that missed

- **WHEN** a note was queued and the agent's `subagent.complete` summary contains "steer did not land"
- **THEN** the detail says the note arrived after the agent finished

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

A method answering method-not-found SHALL turn off only what needs it, for that connection: `subagent.list` leaves rows to frames, `subagent.tail` removes Recent output, and `subagent.interrupt` or `subagent.steer` removes its control after saying "This server can't stop agents." or "This server can't take notes for agents." once where it was pressed. None SHALL show as a chat failure; the next connection SHALL try again.

#### Scenario: An older gateway

- **WHEN** every `subagent.*` method answers method-not-found
- **THEN** agent rows still appear from frames, the detail shows the goal and state only, and no Stop, note field, or error is shown

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

### Requirement: Accessible rows and controls

Rows and controls SHALL have targets of at least 44 by 44 points on Apple platforms and 48 by 48 dp on Android. A row's screen-reader label SHALL read goal, state, tools used and run time in that order, and state SHALL be carried by a word, not colour alone. A state change of the agent whose detail is open SHALL be announced once, politely. Text SHALL scale to the largest accessibility size without cutting the goal or controls, and running indicators SHALL be still with reduced motion.

#### Scenario: VoiceOver on an agent row

- **WHEN** VoiceOver focuses a running agent row
- **THEN** it reads the goal, "Running", the number of tools used and the run time

#### Scenario: Reduced motion

- **WHEN** reduced motion is on and an agent is running
- **THEN** the row shows a still running icon instead of an animated one

### Requirement: Keyboard use

On the Mac and other keyboard layouts the detail's focus order SHALL be back, goal, Stop agent, output, note field, Send to agent. Command-Return on Apple platforms and Control-Enter elsewhere SHALL send a note from the field; Return alone SHALL add a line.

#### Scenario: Sending with the keyboard on a Mac

- **WHEN** the note field has focus and holds text and the user presses Command-Return
- **THEN** the note is sent to the agent

### Requirement: Observability

The app SHALL record a `subagent.rpc` span per call with `method` and `outcome`; log events `subagent.stop` (`outcome`), `subagent.redirect` (`outcome`) and `subagent.unsupported` (`method`, once per connection); and breadcrumbs `subagent.detail.opened` (`source`), `subagent.detail.closed`, `subagent.stop.pressed`, `subagent.stop.confirmed` and `subagent.redirect.sent`, with fixed words, counts and size buckets only.

#### Scenario: Stopping logs only the outcome

- **WHEN** a confirmed stop answers `found: true`
- **THEN** `subagent.stop` is logged with `outcome: stopped` and no goal, note, output, summary, tool name, model, id or profile
