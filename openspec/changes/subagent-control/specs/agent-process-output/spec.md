# Spec Delta

## MODIFIED Requirements

### Requirement: Output is grouped by process identity

The app SHALL group chunks by process_id within the owning server, profile, and runtime session. A compact card SHALL identify a process as having output and provide a plain-text details tail; when `process.list` names the process, the card SHALL also show its command and state. The app SHALL not interpret escape sequences as commands, execute markup, or open links automatically. Missing process_id SHALL be ignored safely.

#### Scenario: Two processes emit interleaved chunks

- **WHEN** the events arrive on one session
- **THEN** each details view contains only its own ordered chunks

#### Scenario: A listed process is matched to its card

- **WHEN** `process.list` returns a row whose `session_id` equals a card's `process_id`
- **THEN** that card shows the row's command and state, and no other card does

### Requirement: Closure does not imply success

terminal.close SHALL mark the matching process Closed. The app SHALL not display a success or failure exit result from terminal.close alone, because that payload contains only process_id; an exit code SHALL be shown only when `process.list` or `process.kill` reported it. A close event arriving before output SHALL create a closed placeholder that later output can populate without reopening it. Session disposal SHALL release retained buffers.

#### Scenario: A close event has no exit code

- **WHEN** terminal.close arrives
- **THEN** the card says Closed and does not claim successful execution

#### Scenario: The list reports an exit code

- **WHEN** terminal.close arrived and `process.list` then reports the process `exited` with `exit_code` 1
- **THEN** the card says "Exited with code 1"

### Requirement: Existing backend contract and compatibility

The app SHALL use the dashboard `/api/ws` JSON-RPC contract for the agent.terminal.output and terminal.close events and the session-scoped `process.list` and `process.kill` methods. The current pinned contract SHALL be Hermes Agent commit `d923a5eb487a17c0a68801bba9ef0f56c81040a8`, recorded in `openrpc/HERMES_REF`. Commit `167e9fdb84248cd0fff80762dc57b6a914b6e930` SHALL remain the retained fixture baseline for the event schemas, which are unchanged. A minimum semantic release containing every required field is not established. Older backends SHALL keep ordinary chat usable when these optional events or methods are absent. Unsupported actions SHALL be unavailable, and malformed optional payloads SHALL not break the event stream. The app SHALL send `process.list` only while the Activity panel is shown and `process.kill` only after the user confirms, never speculatively to probe support. No backend route, protocol extension, or token-storage change SHALL be required.

The shapes are:

- `agent.terminal.output`: `TerminalOutputPayload`, required `process_id`, `chunk`.
- `terminal.close`: `TerminalClosePayload`, required `process_id`.
- `process.list {session_id}`: `{processes: [{session_id, command (at most 200 characters), cwd?, pid?, status: running|exited, uptime_seconds?, output_tail (at most 4,000 characters), exit_code?, exited_at?, completion_reason?}]}`; error 4001 (unknown session) and 5032 (the session's agent is still starting).
- `process.kill {session_id, process_id}`: `{status: killed|already_exited|not_found|error, command?, exit_code?, completion_reason?, output?, output_cut?, error?}`; error 4044 when the process is not the session's.

#### Scenario: Optional capability is absent

- **WHEN** an older backend omits this capability or refuses an optional method as unsupported
- **THEN** ordinary chat remains usable and the app reports unavailable functionality without inventing state or submitting speculative requests

#### Scenario: The agent is still starting

- **WHEN** `process.list` answers 5032
- **THEN** the cards stay as they are, nothing is reported, and the next read follows the backoff

## ADDED Requirements

### Requirement: Session programs are read while the panel is shown

While the Activity panel is visible for a chat whose session is attached on the current connection, the app SHALL read `process.list` once when the panel is shown and every 5 seconds while a listed program runs. Reads SHALL stop in the background, under App Lock and while the panel is hidden, and back off after failures. The app SHALL NOT resume a session only to read the list.

#### Scenario: Reading the list

- **WHEN** the panel opens on a chat with an attached session
- **THEN** the app sends `process.list` with the runtime session id

#### Scenario: An older gateway

- **WHEN** `process.list` answers method-not-found
- **THEN** process cards show what the frames gave them, as before, with no error and no Stop

### Requirement: Process cards name the program and its state

A card with a list entry SHALL show the command (at most two lines) and a state word and icon: Running for `running`; Stopped for `exited` with `completion_reason` `killed`, whatever the exit code; Exited with code N for another `exited` row with an exit code; Ended for `exited` without one. A listed running program without a card SHALL get one; a listed exited program without a card SHALL NOT, so finished programs do not take card slots.

#### Scenario: A running program

- **WHEN** `process.list` returns `{session_id: "proc_1", command: "npm test", status: "running", uptime_seconds: 42}` and the card proc_1 exists
- **THEN** the card reads "npm test", Running, and 42 s

#### Scenario: A program the user stopped

- **WHEN** `process.list` returns `status: exited`, `exit_code: -15`, `completion_reason: killed`
- **THEN** the card says Stopped, not "Exited with code -15"

#### Scenario: A finished program without a card

- **WHEN** `process.list` returns an `exited` program for which no output frame arrived
- **THEN** no card is added for it

#### Scenario: A card Hermes does not list

- **WHEN** a card has output frames but `process.list` has no entry for it
- **THEN** it keeps today's "Process <id> · Output received" (or "Closed") title and shows no state icon, so it never reads as running or succeeded

### Requirement: List output never replaces received output

A card's frame-fed output SHALL NOT be replaced or extended by the list's `output_tail`. The tail SHALL seed only a new or empty card, within the 64 KiB bound, with "Earlier output omitted" when the tail is 4,000 characters long (the server's cut). The command SHALL be shown as given, with a trailing "…" when it is 200 characters long.

#### Scenario: A card already has output

- **WHEN** a card holds 20 KiB from frames and `process.list` returns a 4,000-character `output_tail`
- **THEN** the card keeps its 20 KiB unchanged

#### Scenario: Seeding a new card

- **WHEN** a running program with a 4,000-character `output_tail` has no card
- **THEN** a card is added with that tail and "Earlier output omitted"

### Requirement: Stop a background program

A running program's card SHALL offer Stop program when `process.list` is supported. It SHALL ask first with the title "Stop this program?", the message "Hermes ends <command>. Its output so far stays here, and the agent won't be told it finished.", a default Cancel and a destructive "Stop program". Only the confirmed action SHALL send `process.kill`, once; the control SHALL not be pressable while it is in flight. The app SHALL NOT offer `process.stop`.

#### Scenario: The user stops a program

- **WHEN** the user presses Stop program on "npm run dev" and confirms
- **THEN** one `process.kill` is sent, and on `status: killed` the card shows Stopped and keeps its output

#### Scenario: Double tap

- **WHEN** the user confirms and presses Stop program again before the answer
- **THEN** no second confirmation opens and no second `process.kill` is sent

### Requirement: Program stop outcomes

`killed` SHALL show Stopped, `already_exited` "It had already ended.", `not_found` or error 4044 "This program is no longer listed.", and `error` "Couldn't stop the program." with the card unchanged. A lost answer SHALL say "Couldn't confirm the stop. Checking…" and re-read `process.list`, never resend. The answer's `output` SHALL NOT be appended to a card that has output; it MAY seed an empty card, with "Earlier output omitted" when `output_cut` is present.

#### Scenario: Lost answer

- **WHEN** `process.kill` gets no answer before the timeout
- **THEN** the card says it couldn't confirm the stop, `process.list` is read, and no second kill is sent

#### Scenario: Kill output is not duplicated

- **WHEN** `process.kill` answers `killed` with the program's whole recent output and the card already holds that output from frames
- **THEN** the card's output is unchanged

### Requirement: A program stop check ends

After a lost `process.kill` answer, a successful re-read that shows the program exited or gone SHALL show that state. A re-read that still shows it running, fails or times out, no answer within 10 seconds, or losing the connection SHALL show "Couldn't confirm the stop. It may still be running." and offer Stop program again, which asks for confirmation again.

#### Scenario: The re-read still shows it running

- **WHEN** a kill's answer was lost and the re-read `process.list` shows the program running
- **THEN** the card says "Couldn't confirm the stop. It may still be running." and Stop program can be pressed again; pressing it asks again, and nothing was resent

### Requirement: Program commands and output stay private

Program commands, working directories and output SHALL NOT be written to logs, telemetry, preferences, files or any system surface. The log event `process.stop` SHALL carry only `outcome` (`killed`, `already_exited`, `not_found`, `unconfirmed`, `error`), and the breadcrumb `process.stop.pressed` no attribute.

#### Scenario: Stopping logs only the outcome

- **WHEN** a confirmed stop answers `killed`
- **THEN** `process.stop` is logged with `outcome: killed` and nothing about the program
