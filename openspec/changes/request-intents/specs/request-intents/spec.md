# Spec Delta

## Purpose

Describes the iOS App Intents that tell the user what Hermes is waiting for and let them answer an approval from Siri or Shortcuts: "Pending Requests", "Answer Approval", the Pending Request entity, what each may say on a locked device, and the gateway methods they rely on.

## ADDED Requirements

### Requirement: Pending Requests intent

The system SHALL offer on iOS a "Pending Requests" App Intent with an optional Profile that answers without opening the app. It SHALL read the requests waiting for the user across all profiles (or the given one) fresh from the server, and SHALL answer with their number and, oldest first, up to five entries naming the chat's title and the kind: "is waiting for your approval", "has a question for you" or "is waiting for you in Hermes"; more entries SHALL be summed up as "and N more". With none it SHALL answer "Nothing is waiting for you." Shortcuts SHALL receive the count and the list. The answer SHALL NOT include a command, a question, a secret's name or any reply text. When the server cannot be reached, nobody is signed in, or the device has not been unlocked since it started, it SHALL answer from the last list the app shared, prefixed with "As of <time>,". When there is none, it SHALL answer "Hermes can't reach your server right now.", "Sign in to Hermes first." or "Unlock your iPhone first." respectively. The App Shortcut phrases SHALL be "What does Hermes need", "Hermes requests" and "Pending Hermes requests".

#### Scenario: Two requests

- **WHEN** "Trip plan" waits for an approval and "Backup" has a question
- **THEN** the intent answers "2 requests: Trip plan is waiting for your approval. Backup has a question for you."

#### Scenario: Server unreachable

- **WHEN** the server cannot be reached and the app last shared one pending approval at 10:42
- **THEN** the intent answers "As of 10:42, 1 request: Trip plan is waiting for your approval."

#### Scenario: Signed out with nothing shared

- **WHEN** nobody is signed in and the app never shared a pending list
- **THEN** the intent answers "Sign in to Hermes first."

### Requirement: Pending Requests while locked

"Pending Requests" SHALL run on a locked device without asking to unlock. When Hermes' App lock is on it SHALL answer with the count only: "N requests are waiting. Open Hermes to see them."

#### Scenario: App lock on

- **WHEN** App lock is on and two requests wait
- **THEN** the intent answers "2 requests are waiting. Open Hermes to see them." and names no chat

### Requirement: Answer Approval intent

The system SHALL offer on iOS an "Answer Approval" App Intent with a required Request (an open approval), an optional Choice (Once, This session, Always, Deny) and an optional Profile that narrows the requests offered. It SHALL require the device to be unlocked (`authenticationRequired`) and SHALL NOT look anything up or send anything before it is. When nobody is signed in it SHALL answer "Sign in to Hermes first.", when the server cannot be reached "Hermes can't reach your server right now.", and send nothing. It SHALL look the approval up on the server before answering; when the approval is no longer waiting it SHALL answer "That request is no longer waiting." and send nothing. It SHALL offer only the choices Hermes offers for that approval: a Choice that is not offered SHALL end the intent with "Hermes doesn't offer <choice> for this request.", and a missing Choice SHALL be asked for among the offered ones. Before any choice other than Deny it SHALL show the command (and its description, when Hermes gives one) and ask for confirmation; cancelling SHALL send nothing. After answering it SHALL say "Approved once.", "Approved for this session.", "Approved always." or "Denied.", and the request SHALL disappear from the pending list the app shares. The answer SHALL be sent through the app's shared request-answering path (`answerOpenRequest` by request id), the same one notification buttons use.

#### Scenario: Approve once

- **WHEN** the user runs "Answer Approval" for the approval in "Trip plan" with Choice Once and confirms
- **THEN** Hermes receives the answer `once` for that request and the intent says "Approved once."

#### Scenario: Choice not offered

- **WHEN** the user chooses Always for an approval Hermes offers only Once and Deny for
- **THEN** the intent says "Hermes doesn't offer Always for this request." and sends nothing

#### Scenario: Already answered

- **WHEN** the approval was answered in the app before the intent ran
- **THEN** the intent says "That request is no longer waiting."

#### Scenario: Server unreachable when answering

- **WHEN** the user runs "Answer Approval" while the server cannot be reached
- **THEN** the intent says "Hermes can't reach your server right now." and nothing is sent

#### Scenario: Locked device

- **WHEN** the user runs "Answer Approval" on a locked device
- **THEN** iOS asks to unlock before anything is looked up

### Requirement: Pending Request entity

The Request parameter SHALL offer the open approvals from the pending list the app last shared, oldest first, each shown with its chat's title, "Approval" and when it was raised, and identified by profile, thread and request id together. It SHALL NOT hold or show the command.

#### Scenario: Pick an approval

- **WHEN** the user taps the Request parameter in Shortcuts
- **THEN** the open approvals are listed by chat title, without their commands

### Requirement: Telemetry for request intents

The system SHALL record each run as a `background.task` span with `task` = `intent.pending` or `intent.answer_approval`, `outcome` (`answered`, `none`, `gone`, `cancelled`, `failed`, `signed_out`, `device_locked`, `unreachable`, `unavailable`) and `engine`; each "Answer Approval" run SHALL also log the event `intent.answer_approval` with `outcome` and `choice`; and, when the app's own engine ran it, the breadcrumb `intent.pending.ended` or `intent.answer_approval.ended` with `outcome`. None SHALL carry a command, question, title, profile name, server address or id.

#### Scenario: Approval logged without the command

- **WHEN** an approval for `rm -rf build` is answered `once` with telemetry on
- **THEN** the log event carries `outcome: answered` and `choice: once` and no command

### Requirement: Gateway contract for request intents

The intents SHALL use the dashboard's `/api/ws` JSON-RPC gateway: `session.active_list` with `profile` (each row has `id`, the live session id, `session_key`, the stored session id, and `status`) and `approval.pending` with `session_id` and `profile` (answer `{approvals: [{request_id, command, description, choices, …}]}`) to look an approval up, and the app's shared answer by request id (`request.answer`, falling back to `approval.respond`) to answer it. The pending list itself comes from the snapshot the app builds. These methods exist in the Hermes version pinned by `HERMES_REF`.

#### Scenario: Respond by request id

- **WHEN** the user approves request `r1` in profile `work` with Choice Once
- **THEN** the answer `once` is sent for request `r1` with `profile: work` through the shared answer path, and no session coordinates are needed
