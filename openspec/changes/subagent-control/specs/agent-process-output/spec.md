# Spec Delta

## ADDED Requirements

### Requirement: Session programs are read from the gateway

While the Activity panel is visible for a chat whose session is attached on the current connection, the app SHALL read `process.list {session_id}` once when the panel is shown and every 5 seconds while a listed program runs, matching rows to process cards by `session_id` = `process_id`. Reads SHALL stop in the background, under App Lock and while the panel is hidden, and back off after failures.

#### Scenario: Reading the list

- **WHEN** the panel opens on a chat with an attached session
- **THEN** the app sends `process.list` and reads `{processes: [{session_id, command, cwd?, pid?, status, uptime_seconds?, output_tail?, exit_code?, exited_at?, completion_reason?}]}`

#### Scenario: An older gateway

- **WHEN** `process.list` answers method-not-found
- **THEN** process cards show what the frames gave them, as before, with no error and no Stop

### Requirement: Process cards name the program and its state

A process card with a list entry SHALL show the command (at most two lines), its state as a word and icon (Running, Exited with code N, Stopped, Closed) and its run time. A listed program without a card SHALL get one seeded with its `output_tail` within the 64 KiB bound. A card without a list entry SHALL keep today's wording, and closure without an exit code SHALL NOT claim success.

#### Scenario: A running program

- **WHEN** `process.list` returns `{session_id: "proc_1", command: "npm test", status: "running", uptime_seconds: 42}` and the card proc_1 exists
- **THEN** the card reads "npm test", Running, and 42 s

### Requirement: Stop a background program

A running program's card SHALL offer Stop program when `process.list` is supported. It SHALL ask first with the title "Stop this program?", the message "Hermes ends <command>. Its output so far stays here. The agent won't be told the program finished.", a default Cancel and a destructive "Stop program". Only the confirmed action SHALL send `process.kill {session_id, process_id}`, once. The app SHALL NOT offer `process.stop`.

#### Scenario: The user stops a program

- **WHEN** the user presses Stop program on "npm run dev" and confirms
- **THEN** one `process.kill` is sent, and on `status: killed` the card shows Stopped and keeps its output

### Requirement: Program stop outcomes

The answer's status SHALL be reported: `killed` as Stopped, `already_exited` as "It had already ended.", `not_found` or error 4044 as "This program is no longer listed.", `error` as "Couldn't stop the program." with the card unchanged. A lost answer SHALL say "Couldn't confirm the stop. Checking…" and re-read `process.list`, never resend. The answer's `output` SHALL be kept only within the card's 64 KiB bound.

#### Scenario: Lost answer

- **WHEN** `process.kill` gets no answer before the timeout
- **THEN** the card says it couldn't confirm the stop, `process.list` is read, and no second kill is sent

### Requirement: Program commands and output stay private

Program commands, working directories and output SHALL NOT be written to logs, telemetry, preferences, files or any system surface. The log event `process.stop` SHALL carry only `outcome` (`killed`, `already_exited`, `not_found`, `unconfirmed`, `error`), and the breadcrumb `process.stop.pressed` no attribute.

#### Scenario: Stopping logs only the outcome

- **WHEN** a confirmed stop answers `killed`
- **THEN** `process.stop` is logged with `outcome: killed` and nothing about the program
