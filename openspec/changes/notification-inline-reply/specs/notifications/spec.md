# Spec Delta

## ADDED Requirements

### Requirement: Inline reply to a finished reply

On iOS and macOS, a notification for a completed reply in a chat SHALL offer a "Reply" action with a text field while App Lock is off. Sending a non-empty text SHALL send it once, exactly as typed, as a new prompt into that chat and profile with `queued: true`, without opening the app. An empty or whitespace-only text SHALL send nothing. This SHALL hold whether the app is running, suspended or not running.

#### Scenario: Reply from the notification

- **WHEN** the user replies "Yes, book it" to the "Reply ready" notification of chat "Trip plan"
- **THEN** "Yes, book it" is sent to "Trip plan" as a prompt, and the app does not open

#### Scenario: Turn still running

- **WHEN** Hermes is running a turn in that chat when the reply is sent
- **THEN** the prompt is queued behind it and does not redirect it

### Requirement: Where the reply action is not offered

The reply action SHALL NOT be offered on Android, Windows, Linux or watchOS, on "Reply failed", stopped-reply, request, scheduled-task or message notifications, or on any notification posted while App Lock is on. Those notifications SHALL keep their existing categories and bodies.

#### Scenario: App Lock on at post time

- **WHEN** a reply completes while App Lock is on
- **THEN** its notification has the generic "Reply ready" body and no Reply action

#### Scenario: Failed reply

- **WHEN** a reply fails
- **THEN** the "Reply failed" notification has no Reply action

### Requirement: Inline reply respects the device and App Lock

The action SHALL require the device to be unlocked. App Lock SHALL be read again when a reply arrives. If it is on, the system SHALL send nothing, keep nothing, and post "Open Hermes to reply." under the title "Hermes". Turning App Lock on SHALL withdraw notifications that carry the action.

#### Scenario: Locked device

- **WHEN** the user tries to reply on a locked iPhone
- **THEN** iOS asks to unlock before the text reaches the app

#### Scenario: App Lock turned on after posting

- **WHEN** the user turns App Lock on, then replies from a notification that was already showing
- **THEN** nothing is sent or kept, and "Open Hermes to reply." is posted

### Requirement: Answer to an inline reply

The answer to an inline reply SHALL arrive as the notifications this spec already defines for the chat. If it completes within the background window it SHALL be announced at once. Otherwise the chat SHALL be recorded as a running reply so the background check for finished replies announces it when the system runs that check. Closing the background work SHALL NOT itself post "Reply failed".

#### Scenario: Quick answer

- **WHEN** Hermes answers the inline reply within the window
- **THEN** a "Reply ready" notification with the answer's preview replaces the earlier one

#### Scenario: Slow answer

- **WHEN** the answer takes several minutes
- **THEN** no "Reply failed" is shown when the background work stops, and the answer is announced by a later background check, or is seen when the app opens

### Requirement: Reply not sent

When an inline reply cannot be sent (nobody signed in, the stored session unreadable, the server unreachable, the chat or profile gone, or the send failed before Hermes accepted the prompt), the system SHALL post a notification for that chat, replacing the earlier one, with the chat's title and the body "Reply not sent. Open Hermes to try again." It SHALL NOT retry, and its title and body SHALL NOT include the typed text.

#### Scenario: Server unreachable

- **WHEN** the user replies while the server cannot be reached
- **THEN** "Reply not sent. Open Hermes to try again." appears for the chat and nothing is sent later

#### Scenario: Every headless outcome handled

- **WHEN** the headless runtime reports signed out, locked or unreachable
- **THEN** each posts "Reply not sent" with outcome `unavailable`; none is dropped silently

### Requirement: Reply that may have been sent

When Hermes may have received the prompt but the answer to `prompt.submit` was lost, the system SHALL NOT resend it and SHALL, within the background window, post for the chat "Couldn't confirm your reply was sent. Open Hermes to check." without the typed text, and SHALL keep no text.

#### Scenario: Answer lost

- **WHEN** the connection drops after `prompt.submit` went out and before its result
- **THEN** "Couldn't confirm your reply was sent. Open Hermes to check." is posted and nothing is resent

### Requirement: Typed text is not stored

Typed reply text SHALL be held in memory only while it is sent. It SHALL NOT be written to preferences, files, logs, telemetry, breadcrumbs, or a notification's title or body, and SHALL NOT be kept at all when the reply ended `sent`, `unconfirmed` or `locked`, or while App Lock is on.

#### Scenario: Reply sent

- **WHEN** a reply is sent and answered
- **THEN** its text is stored nowhere

### Requirement: Unsent text can be restored

After "Reply not sent", the text SHALL be kept only if it is at most 120 characters (the reply preview length), only in that notification's payload. Tapping the notification SHALL open the chat as `hermes://chat?profile=<p>&id=<id>&prompt=<text>` does: the text in the composer, never sent. Longer text SHALL NOT be kept, and the body then reads "Reply not sent. Open Hermes to write it again."

#### Scenario: Unsent text restored

- **WHEN** the user taps a "Reply not sent" notification after typing "Yes, book it"
- **THEN** the chat opens with "Yes, book it" in the composer, and nothing is sent

#### Scenario: Long text not kept

- **WHEN** a reply of 300 characters could not be sent
- **THEN** the notification says to write it again, and its payload holds no text

### Requirement: A reply never answers a request

An inline reply SHALL be sent only as a prompt and SHALL NOT be passed to `request.answer`, `approval.respond` or `clarify.respond`. The action `hermes.action.reply-chat` SHALL be distinct from `hermes.action.reply`. A request notification's buttons SHALL answer only the request id in that notification's payload. A request the reply's turn raises SHALL get its own notification.

#### Scenario: Reply while a request waits

- **WHEN** an approval waits in the chat and the user replies from that chat's earlier "Reply ready" notification
- **THEN** the text is sent as a prompt and the approval stays unanswered

### Requirement: Inline reply never signs the user out

Sending an inline reply SHALL run on the headless runtime. A rejected refresh, a locked store, an unreadable session or a timeout SHALL NOT clear the stored session, and SHALL end in a notification as above.

#### Scenario: Refresh rejected

- **WHEN** the refresh is rejected during an inline reply
- **THEN** "Reply not sent" is posted and the user stays signed in

### Requirement: Telemetry for inline replies

Each inline reply SHALL be recorded as a `background.task` span with `task` = `notification.reply`, `outcome` (`answered`, `sent`, `failed`, `unavailable`, `unconfirmed` or `locked`) and `engine`, plus a log event `notification.reply` with `outcome` and `route`, and a breadcrumb when the running app handled it. None SHALL carry the typed text, a chat title, a profile name, a server address or an id.

#### Scenario: Failed send recorded

- **WHEN** an inline reply fails with telemetry on
- **THEN** a `notification.reply` log event with `outcome: failed` is recorded and holds no text

### Requirement: Gateway contract for inline replies

An inline reply SHALL use the dashboard's `/api/ws` gateway as the chat does: `session.resume` with `profile` and the stored session id, then `prompt.submit` with `session_id`, `text` and `queued: true`, whose result `status` is `streaming`, `queued`, `steered` or `redirected`. These are in the Hermes OpenRPC contract pinned by `openrpc/HERMES_REF`.

#### Scenario: Prompt queued

- **WHEN** an inline reply is sent
- **THEN** `prompt.submit` carries `queued: true`
