# Spec Delta

## ADDED Requirements

### Requirement: Inline reply to a finished reply

On iOS, iPadOS and macOS, a notification for a completed reply in a chat, posted by the running app or by the background check, SHALL offer a "Reply" action with a text field when App Lock is off and loaded. A non-empty text SHALL be sent once, exactly as typed, as a new prompt into that chat and profile with `queued: true`, without opening the app, whether the app is running or not. Empty or whitespace-only text SHALL send nothing.

#### Scenario: Reply from the notification

- **WHEN** the user replies "Yes, book it" to the "Reply ready" notification of chat "Trip plan"
- **THEN** "Yes, book it" is sent to "Trip plan" as a prompt, and the app does not open

#### Scenario: Turn still running

- **WHEN** Hermes is running a turn in that chat when the reply is sent
- **THEN** the prompt is queued behind it and does not redirect it

#### Scenario: Posted by the background check

- **WHEN** the background check announces a finished reply while App Lock is off
- **THEN** that notification offers the Reply action like one the app posted

### Requirement: Where the reply action is not offered

The reply action SHALL NOT be offered on Android, Windows, Linux or watchOS, on "Reply failed", stopped-reply, request, scheduled-task or message notifications, while App Lock is on or its saved setting has not loaded, or when nobody is signed in. Those notifications SHALL keep their existing categories and bodies.

#### Scenario: App Lock on at post time

- **WHEN** a reply completes while App Lock is on
- **THEN** its notification has the generic "Reply ready" body and no Reply action

#### Scenario: App Lock not yet loaded

- **WHEN** a reply completes before App Lock's saved setting has loaded
- **THEN** it is announced without the Reply action

#### Scenario: Failed reply

- **WHEN** a reply fails
- **THEN** the "Reply failed" notification has no Reply action

### Requirement: Inline reply respects the device and App Lock

The action SHALL require the device to be unlocked. App Lock SHALL be read again when a reply arrives. If it is on, or not yet loaded, the system SHALL send nothing, keep nothing, and post "Open Hermes to reply." under the title "Hermes". Turning App Lock on, and signing out, SHALL withdraw notifications that carry the action or a kept text.

#### Scenario: Locked device

- **WHEN** the user tries to reply on a locked iPhone
- **THEN** iOS asks to unlock before the text reaches the app

#### Scenario: App Lock turned on after posting

- **WHEN** the user turns App Lock on, then replies from a notification that was already showing
- **THEN** nothing is sent or kept, and "Open Hermes to reply." is posted

#### Scenario: App Lock turned on with a kept text showing

- **WHEN** a "Reply not sent" notification that holds a kept text is showing and the user turns App Lock on
- **THEN** that notification is withdrawn and the text is gone

### Requirement: Answer to an inline reply

The answer to an inline reply SHALL arrive as the notifications this spec already defines for the chat. If it completes within the background window it SHALL be announced at once. On iOS otherwise the chat SHALL be recorded as a running reply so the background check announces it when the system runs it. On macOS, where no background check runs, a slow answer SHALL be seen when the chat is opened. Closing the work SHALL NOT post "Reply failed".

#### Scenario: Quick answer

- **WHEN** Hermes answers the inline reply within the window
- **THEN** a "Reply ready" notification with the answer's preview replaces the earlier one

#### Scenario: Slow answer on iOS

- **WHEN** the answer takes several minutes
- **THEN** no "Reply failed" is shown when the work stops, and the answer is announced by a later background check, or seen when the app opens

#### Scenario: Slow answer on macOS

- **WHEN** the answer takes several minutes on a Mac
- **THEN** nothing is announced, and the answer is in the chat when it is opened

#### Scenario: Prompt folded into a running turn

- **WHEN** Hermes steers or redirects the prompt into a turn already running
- **THEN** the reply counts as sent, the chat is recorded as running, and no automatic continuation turn is announced as the answer

### Requirement: Reply not sent

When an inline reply cannot be sent (nobody signed in, the stored session unreadable, the server unreachable, the account changed, the chat or profile gone, or the send failed before `prompt.submit` was sent), the system SHALL post a notification for that chat, replacing the earlier one, with the chat's title and the body "Reply not sent. Open Hermes to try again." It SHALL NOT retry, and its title and body SHALL NOT include the typed text.

#### Scenario: Server unreachable

- **WHEN** the user replies while the server cannot be reached
- **THEN** "Reply not sent. Open Hermes to try again." appears for the chat and nothing is sent later

#### Scenario: Every headless outcome handled

- **WHEN** the headless runtime reports signed out, locked or unreachable
- **THEN** each posts "Reply not sent"; none is dropped silently

#### Scenario: Stale notification after a server switch

- **WHEN** the user replies from a notification posted for another account or server
- **THEN** nothing is sent, no text is kept, and "Reply not sent" is posted

### Requirement: Reply that may have been sent

When `prompt.submit` was sent but its answer did not arrive, including a connection lost after it and a hand-off to the running app that reports nothing in time, the system SHALL NOT resend. Within the background window it SHALL post for the chat "Couldn't confirm your reply was sent. Open Hermes to check." without the typed text, and SHALL keep no text.

#### Scenario: Answer lost

- **WHEN** the connection drops after `prompt.submit` went out and before its result
- **THEN** "Couldn't confirm your reply was sent. Open Hermes to check." is posted and nothing is resent

#### Scenario: Hand-off timeout

- **WHEN** the background isolate has handed the reply to the running app and no report comes back in time
- **THEN** "Couldn't confirm your reply was sent. Open Hermes to check." is posted, not "Reply not sent"

### Requirement: Typed text is not stored

Typed reply text SHALL be held in memory only while it is sent. Except as "Unsent text can be restored" allows, it SHALL NOT be written to preferences, files, logs, telemetry, breadcrumbs, or a notification's title or body, and SHALL NOT be kept when the reply ended `sent`, `unconfirmed`, `locked` or signed out.

#### Scenario: Reply sent

- **WHEN** a reply is sent and answered
- **THEN** its text is stored nowhere

### Requirement: Unsent text can be restored

After "Reply not sent", the text SHALL be kept only if it is at most 120 user-perceived characters, App Lock is off and loaded, and the user is signed in, and only in that notification's payload. Tapping the notification SHALL open the chat, under its own profile, as `hermes://chat?profile=<p>&id=<id>&prompt=<text>` does: the text in the composer, never sent. Longer text SHALL NOT be kept, and the body reads "Reply not sent. Open Hermes to write it again."

#### Scenario: Unsent text restored

- **WHEN** the user taps a "Reply not sent" notification after typing "Yes, book it"
- **THEN** the chat opens with "Yes, book it" in the composer, and nothing is sent

#### Scenario: Other profile

- **WHEN** the chat belongs to a profile other than the one shown
- **THEN** the tap switches to that profile and opens the chat with the text in the composer

#### Scenario: Long text not kept

- **WHEN** a reply of 300 characters could not be sent
- **THEN** the notification says to write it again, and its payload holds no text

### Requirement: Reply response at cold launch on macOS

When macOS starts the app for a Reply response, the response SHALL be handled once, as a reply and not as a tap that opens the chat, however many screens ask for the launch target.

#### Scenario: App not running on the Mac

- **WHEN** the user replies on a Mac while the app is not running
- **THEN** the text is sent once and the chat does not open

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

### Requirement: An ending is told only when notifications are allowed

The notifications "Reply not sent", "Couldn't confirm" and "Open Hermes to reply." SHALL be posted only while notifications are on and permitted. If they are off or revoked, nothing SHALL be posted and no text kept.

#### Scenario: Permission revoked

- **WHEN** the user revokes notification permission and then a queued reply cannot be sent
- **THEN** nothing is posted and no text is kept

### Requirement: Telemetry for inline replies

Each inline reply SHALL record a `background.task` span with `task` = `notification.reply` and `engine`, annotated `reply.outcome` (`answered`, `sent`, `failed`, `unavailable`, `unconfirmed`), a log event `notification.reply` with `outcome` and `route`, and a breadcrumb when the running app handled it. A reply refused for App Lock (`locked`) SHALL end its span without a run. None SHALL carry the typed text, a chat title, a profile name, a server address or an id.

#### Scenario: Failed send recorded

- **WHEN** an inline reply fails with telemetry on
- **THEN** a `notification.reply` log event with `outcome: failed` is recorded and holds no text

### Requirement: Gateway contract for inline replies

An inline reply SHALL use the dashboard's `/api/ws` gateway as the chat does: `session.resume` with `profile` and the stored session id, then `prompt.submit` with `session_id`, `text` and `queued: true`, whose result `status` is `streaming`, `queued`, `steered` or `redirected`. These are in the Hermes OpenRPC contract pinned by `openrpc/HERMES_REF`.

#### Scenario: Prompt queued

- **WHEN** an inline reply is sent
- **THEN** `prompt.submit` carries `queued: true`
