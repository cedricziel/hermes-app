# Spec Delta

## Purpose

Describes the iOS "Ask Hermes" App Intent, which sends a question to Hermes from Siri or Shortcuts and answers in place without opening the app: its inputs, the chat it uses, the answer and its time limit, the late notification, its behavior on a locked device and under App lock, and the gateway methods it relies on.

## ADDED Requirements

### Requirement: Asking Hermes

The system SHALL offer on iOS an "Ask Hermes" App Intent with a required Question (text), an optional Profile and an optional Chat. When the Question is missing, Siri SHALL ask "What do you want to ask Hermes?". Without a Chat the intent SHALL start a new chat in the given Profile, or in the profile the app last reported as current when none is given, and with neither known in the server's default profile. With a Chat it SHALL continue that chat in the chat's own profile, and the Profile SHALL be ignored. The intent SHALL send the Question exactly as given, as one prompt, and SHALL NOT open the app. The App Shortcut phrases SHALL be "Ask Hermes" and "Ask Hermes something".

#### Scenario: New chat per ask

- **WHEN** the user says "Ask Hermes" and then "What's on my calendar today?"
- **THEN** a new chat in the current profile receives that prompt, and the app does not open

#### Scenario: Continue a chat

- **WHEN** a shortcut runs "Ask Hermes" with the Chat "Trip plan" (profile `work`) and the Profile `default`
- **THEN** the prompt is sent to "Trip plan" in `work`

### Requirement: Answer in place

The intent SHALL wait for the reply up to 25 seconds after it started, including the time needed to start Hermes in the background and connect. When the reply completes in time, the intent SHALL return its text: Siri speaks it with Markdown formatting removed, and Shortcuts receives the full text, cut at 4000 characters with an ellipsis, as the intent's output. A reply with no text SHALL be answered "Hermes replied without any text." A reply that fails SHALL be answered "Hermes couldn't answer." without the error text. When the agent asks for an approval, a clarifying answer, a secret or another input during the turn, the intent SHALL answer "Hermes needs your answer. Open the chat in Hermes." at once and SHALL post the request's notification as the notifications spec defines it.

#### Scenario: Quick reply

- **WHEN** the reply "**Three** tickets are open." completes 6 seconds after the ask
- **THEN** Siri says "Three tickets are open." and the Shortcuts output is "**Three** tickets are open."

#### Scenario: Approval during the turn

- **WHEN** the agent asks for approval to run a command during the ask
- **THEN** the intent answers "Hermes needs your answer. Open the chat in Hermes.", the "Waiting for your approval" notification is posted, and the command is not spoken

#### Scenario: Failed reply

- **WHEN** the reply completes with failure
- **THEN** the intent answers "Hermes couldn't answer."

### Requirement: Replies that take longer

When the reply has not completed 25 seconds after the ask started, the intent SHALL answer "Still working — I'll notify you." and the prompt SHALL stay sent. The system SHALL go on waiting for the reply for as long as iOS keeps Hermes running in the background, and SHALL then post the "Reply ready" (or "Reply failed") notification for the chat as the notifications spec defines it; tapping it opens the chat. A reply that finishes after iOS stopped Hermes SHALL be announced by the background check for finished replies when that runs. A reply answered in place SHALL NOT also be announced by a notification.

#### Scenario: Long reply

- **WHEN** the reply completes 40 seconds after the ask, while iOS still lets Hermes run
- **THEN** Siri said "Still working — I'll notify you." at 25 seconds, and a "Reply ready" notification with the reply's preview appears at 40 seconds

#### Scenario: No duplicate notification

- **WHEN** the reply completes within 25 seconds
- **THEN** Siri speaks the reply and no "Reply ready" notification is posted

### Requirement: Locked device and App lock

The intent SHALL run on a locked device without asking to unlock, once the device has been unlocked at least once since it started. The intent SHALL handle each outcome of the headless runtime explicitly and SHALL NOT send anything in any of them: before that first unlock (secure storage unreadable) it SHALL answer "Unlock your iPhone first."; when nobody is signed in it SHALL answer "Sign in to Hermes first."; when the server cannot be reached it SHALL answer "Can't reach your Hermes server."; when Hermes cannot start in the background at all it SHALL answer "Hermes isn't available right now. Open Hermes to check." When Hermes' App lock is on, the intent SHALL NOT answer in place: it SHALL ask to continue in the app, which requires unlocking the device, and SHALL then open the link `hermes://new?profile=<profile>&prompt=<question>`: a new chat in the Profile (or the Chat's profile) with the Question in the composer, unsent, behind the app's own lock screen. Nothing SHALL be sent to the server before the user sends it in the app.

#### Scenario: Locked phone

- **WHEN** the phone is locked, App lock is off, and the user asks Hermes a question
- **THEN** the answer is spoken without unlocking

#### Scenario: App lock on

- **WHEN** App lock is on and the user asks Hermes a question
- **THEN** iOS asks to unlock, Hermes opens on `hermes://new?prompt=…` behind its lock screen, and after unlocking a new chat shows the question in the composer without sending it

#### Scenario: Signed out

- **WHEN** nobody is signed in to Hermes and the user asks a question
- **THEN** the intent answers "Sign in to Hermes first." and nothing is sent

#### Scenario: Before the first unlock

- **WHEN** the phone restarted and has not been unlocked yet, and the user asks a question
- **THEN** the intent answers "Unlock your iPhone first." and nothing is sent

#### Scenario: Server unreachable

- **WHEN** the saved server does not answer
- **THEN** the intent answers "Can't reach your Hermes server." and nothing is sent

### Requirement: Telemetry for asks

The system SHALL record each ask as a `background.task` span with `task` = `intent.ask`, `outcome` (`answered`, `still_working`, `needs_you`, `failed`, `signed_out`, `device_locked`, `unreachable`, `unavailable`, `app_locked`), `engine` (`foreground` or `headless`) and `continued` (true when a Chat was given); a log event `intent.ask` with `outcome` and `waited_s` (`<5`, `<15`, `<25` or `late`); and, when the app's own engine ran it, the breadcrumbs `intent.ask.started` and `intent.ask.ended` with `outcome`. None of them SHALL carry the question, the reply, a chat title, a profile name, a server address or an id. All of it SHALL be off when telemetry is off.

#### Scenario: Nothing personal recorded

- **WHEN** an ask about "my salary" is answered in place with telemetry on
- **THEN** the span and log event carry `outcome: answered` and no text

### Requirement: Gateway contract for asks

The intent SHALL use the dashboard's `/api/ws` JSON-RPC gateway exactly as the chat sends a prompt: `session.create` with `profile` and `source: hermes_app` for a new chat, or `session.resume` with `profile` and the stored session id for a Chat; then `prompt.submit` with `session_id` and `text`, whose result `status` is `streaming`, `queued`, `steered` or `redirected`; the reply arrives as `message.delta` events and ends with `message.complete` (or an idle `session.info`), and `approval.request`, `clarify.request` and the other request events mark a request. These methods and events exist in the Hermes version pinned by `HERMES_REF`; no newer version is required.

#### Scenario: New chat source

- **WHEN** an ask starts a new chat
- **THEN** `session.create` is sent with `source: hermes_app`, so Hermes stores the chat as an app chat
