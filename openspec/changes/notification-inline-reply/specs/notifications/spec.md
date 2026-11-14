# Spec Delta

## MODIFIED Requirements

### Requirement: Tapping a notification opens its chat

The system SHALL open the chat a notification was posted for when the user taps it while the app is running. When the Chat and Kanban destinations are shown, the system SHALL select Chat on every tap, including a tap whose chat cannot be opened, so that the user is not left on the Kanban board, and SHALL dismiss the screens pushed over the board (a task, board management, the create form). When the tap started the app, the system SHALL select Chat and open that chat once the chat list has loaded. A tap that arrives while the chat list is still loading SHALL be held and applied when the list has loaded, and SHALL take precedence over the notification that launched the app. A notification carries the chat's thread id and, when known, its profile; a notification without a profile SHALL match on the thread id alone (so a notification posted by an earlier build, whose payload is a bare thread id, still works). A notification for a message from Hermes, and the summary of several, SHALL open as the agent-messages spec defines (switching profile and fetching the chat); for every other notification, if the target chat cannot be opened, because it belongs to a different profile than the one currently shown or is not in the loaded list, the selection SHALL NOT change (for a launch, the welcome view for a new chat is shown instead) and the system SHALL tell the user with the message "Could not open that chat." Opening a chat from a notification SHALL close the chat list drawer when it is open, and SHALL NOT close or pop any other screen the user has open, except the screens pushed over the Kanban board. A "Reply not sent" notification that holds a kept text is an exception: its tap SHALL switch to the chat's profile and open the chat with the text in the composer, never sent.

#### Scenario: Tap while running

- **WHEN** the user taps a notification for chat s2 while chat s1 is open
- **THEN** chat s2 opens

#### Scenario: Tap while Kanban is shown

- **WHEN** the user taps a notification for chat s2 while the Kanban destination is selected
- **THEN** the Chat destination is selected
- **AND** chat s2 is open

#### Scenario: Tap while a task is open over the board

- **WHEN** the user taps a notification while a task, board management or the create form is open over the Kanban board
- **THEN** that screen is dismissed and the Chat destination is selected

#### Scenario: Tap for an unknown chat

- **WHEN** a tapped notification other than a message from Hermes names a chat that is not in the list
- **THEN** the open chat stays as it was
- **AND** the message "Could not open that chat." is shown

#### Scenario: Tap made under another profile

- **WHEN** the profile of a notification other than a message from Hermes differs from the profile currently shown
- **THEN** the open chat stays as it was
- **AND** the message "Could not open that chat." is shown

#### Scenario: Tap while the list is loading

- **WHEN** the user taps a notification for chat s2 while the chat list is still loading
- **THEN** chat s2 is selected as soon as the list has loaded

#### Scenario: Tap while another screen is open

- **WHEN** the user taps a notification for chat s2 while a secondary screen such as Profiles or Bots is open over the chat
- **THEN** chat s2 is selected
- **AND** the secondary screen stays open

#### Scenario: Cold start from a notification

- **WHEN** the app was launched by tapping a notification for chat s2
- **THEN** chat s2 is selected once the list has loaded

#### Scenario: Tap on a kept unsent reply from another profile

- **WHEN** the profile of a "Reply not sent" notification that holds a kept text differs from the profile currently shown
- **THEN** the profile is switched and the chat opens with the text in the composer, never sent

## ADDED Requirements

### Requirement: Inline reply to a finished reply

On iOS, iPadOS and macOS, a notification for a completed reply in a chat, posted by the running app or by the background check, SHALL offer a "Reply" action with a text field when App Lock is off and loaded. A non-empty text SHALL be sent once, exactly as typed, as a new prompt into that chat and profile with `queued: true`, without opening the app, whether the app is running or not. Empty or whitespace-only text SHALL send nothing.

#### Scenario: Reply from the notification

- **WHEN** the user replies "Yes, book it" to the "Reply ready" notification of chat "Trip plan"
- **THEN** "Yes, book it" is sent to "Trip plan" as a prompt, and the app does not open

#### Scenario: Turn still running

- **WHEN** Hermes is running a turn in that chat when the reply is sent
- **THEN** the prompt is queued behind it and does not redirect it

#### Scenario: Empty reply

- **WHEN** the user sends an empty or whitespace-only reply
- **THEN** nothing is sent and nothing is posted

#### Scenario: Posted by the background check

- **WHEN** the background check announces a finished reply while App Lock is off
- **THEN** that notification offers the Reply action like one the app posted

#### Scenario: Two isolates, one reply

- **WHEN** the app is running and the background isolate receives the response
- **THEN** exactly one of them sends the prompt, once

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

The action SHALL require the device to be unlocked. When a reply arrives, App Lock SHALL be read from its saved setting before anything is sent. If it is on, or cannot be read, the system SHALL send nothing, keep nothing, and post "Open Hermes to reply." under the title "Hermes". Turning App Lock on, and signing out, SHALL withdraw notifications that carry the action or a kept text.

#### Scenario: Locked device

- **WHEN** the user tries to reply on a locked iPhone
- **THEN** iOS asks to unlock before the text reaches the app

#### Scenario: App Lock turned on after posting

- **WHEN** the user turns App Lock on, then replies from a notification that was already showing
- **THEN** nothing is sent or kept, and "Open Hermes to reply." is posted

#### Scenario: App Lock turned on with a kept text showing

- **WHEN** a "Reply not sent" notification that holds a kept text is showing and the user turns App Lock on
- **THEN** that notification is withdrawn and the text is gone

#### Scenario: Withdrawn on sign-out

- **WHEN** the user signs out while a "Reply ready" notification with the action, or a "Reply not sent" with a kept text, is showing
- **THEN** both are withdrawn

### Requirement: Answer to an inline reply

The answer to an inline reply SHALL arrive as the notifications this spec already defines for the chat. If it completes within the background window it SHALL be announced at once, never while the app is in front and never twice. On iOS otherwise the chat SHALL be recorded as a running reply so the background check announces it. On macOS, where no background check runs, a slow answer SHALL be seen when the chat is opened. Closing the work SHALL NOT post "Reply failed".

#### Scenario: Quick answer

- **WHEN** Hermes answers the inline reply within the window
- **THEN** a "Reply ready" notification with the answer's preview replaces the earlier one

#### Scenario: Answer while the app is in front

- **WHEN** the answer completes while the app is in front
- **THEN** no notification is posted, and returning to the app announces nothing again

#### Scenario: Slow answer on iOS

- **WHEN** the answer takes several minutes
- **THEN** no "Reply failed" is shown when the work stops, and the answer is announced by a later background check, or seen when the app opens

#### Scenario: Slow answer on macOS

- **WHEN** the answer takes several minutes on a Mac
- **THEN** nothing is announced, and the answer is in the chat when it is opened

#### Scenario: Prompt folded into a running turn

- **WHEN** Hermes steers or redirects the prompt into a turn already running
- **THEN** the reply counts as sent, nothing is recorded as running and nothing is announced for it, and the answer is seen when the chat is opened

### Requirement: Reply not sent

When Hermes cannot have received the prompt (nobody signed in, the stored session unreadable, the server unreachable, the account changed, the chat or profile gone, or a failure before `prompt.submit` was sent), the system SHALL post for that chat, replacing its notification, the chat's title and "Reply not sent. Open Hermes to try again." if a text is kept, else "Reply not sent. Open Hermes to write it again." It SHALL NOT retry or put the text in a title or body.

#### Scenario: Server unreachable

- **WHEN** the user replies of 40 characters while the server cannot be reached
- **THEN** "Reply not sent. Open Hermes to try again." appears for the chat and nothing is sent later

#### Scenario: Signed out or locked store

- **WHEN** the headless runtime reports signed out, locked or unreachable before the prompt was sent
- **THEN** "Reply not sent. Open Hermes to write it again." is posted for signed out and "try again" for the others if the text qualifies; none is dropped silently

#### Scenario: Stale notification after a server switch

- **WHEN** the user replies from a notification posted for another account or server
- **THEN** nothing is sent, no text is kept, and "Reply not sent. Open Hermes to write it again." is posted

### Requirement: Reply that may have been sent

Once `prompt.submit` was written without an answer (a session reclaimed before it was written is not this case), the system SHALL NOT resend. Whatever ends the work after that point, whether a lost connection, a timeout, a headless runtime that reports unreachable, signed out or locked, a stream that ends with no acknowledgement or a hand-off that reports nothing in time, SHALL post "Couldn't confirm your reply was sent. Open Hermes to check." without the text, and keep no text.

#### Scenario: Answer lost

- **WHEN** the connection drops after `prompt.submit` went out and before its result
- **THEN** "Couldn't confirm your reply was sent. Open Hermes to check." is posted and nothing is resent

#### Scenario: Timeout after submit

- **WHEN** the run's own timeout fires, or the session fails, after `prompt.submit` was written
- **THEN** "Couldn't confirm" is posted, never "Reply not sent"

#### Scenario: Hand-off timeout

- **WHEN** the background isolate has handed the reply to the running app and no report comes back in time
- **THEN** "Couldn't confirm" is posted, and a later report from the app posts nothing that replaces it

### Requirement: Typed text is not stored

Typed reply text SHALL be held in memory only while it is sent. Except as "Unsent text can be restored" allows, it SHALL NOT be written to preferences, files, logs, telemetry, breadcrumbs, or a notification's title or body, and SHALL NOT be kept when the reply ended `sent`, `unconfirmed` or was refused for App Lock, or signed out.

#### Scenario: Reply sent

- **WHEN** a reply is sent and answered
- **THEN** its text is stored nowhere

### Requirement: Unsent text can be restored

After "Reply not sent", the text MAY be kept only if it is at most 120 user-perceived characters, App Lock is off and loaded, and the user is signed in, and only in that notification's payload with its account marker, for as long as the notification lives. Tapping it SHALL open the chat as `hermes://chat?profile=<p>&id=<id>&prompt=<text>` does, with the text in the composer, never sent. In another account it SHALL put nothing in the composer. Longer text SHALL NOT be kept.

#### Scenario: Unsent text restored

- **WHEN** the user taps a "Reply not sent" notification after typing "Yes, book it"
- **THEN** the chat opens with "Yes, book it" in the composer, and nothing is sent

#### Scenario: Other profile

- **WHEN** the chat belongs to a profile other than the one shown
- **THEN** the tap switches to that profile and opens the chat, as an explicit exception to "Tapping a notification opens its chat"

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

Sending an inline reply, in either isolate, SHALL run on the headless runtime. A rejected refresh, a locked store, an unreadable session or a timeout SHALL NOT clear the stored session, and SHALL end in a notification as above.

#### Scenario: Refresh rejected

- **WHEN** the refresh is rejected before the prompt was sent
- **THEN** "Reply not sent" is posted and the user stays signed in

### Requirement: An ending is told only when allowed

"Reply not sent", "Couldn't confirm" and "Open Hermes to reply." SHALL be posted only while notifications are on and permitted. App Lock SHALL be read again right before posting; if it is on, the text and the chat's title SHALL be dropped (title "Hermes") and the body keeps its meaning, so "Couldn't confirm" stays "Couldn't confirm" and a not-sent ending says "write it again". If notifications are off or revoked, nothing SHALL be posted or kept.

#### Scenario: App Lock turned on while sending

- **WHEN** App Lock turns on after the reply was handed over and before the ending is posted
- **THEN** the ending is posted under the title "Hermes" with no text, and "Couldn't confirm" stays "Couldn't confirm"

#### Scenario: Permission revoked

- **WHEN** the user revokes notification permission and then a queued reply cannot be sent
- **THEN** nothing is posted and no text is kept

### Requirement: Telemetry for inline replies

Each inline reply SHALL record a `background.task` span with `task` = `notification.reply` and `engine`. When the body ran it SHALL be annotated `reply.outcome` (`answered`, `sent`, `failed`, `unconfirmed`); when the run ended first, the span keeps the runtime's own outcome. A log event `notification.reply` SHALL carry `outcome` and `route`. A reply refused for App Lock SHALL end a run-less span. None SHALL carry the typed text, a title, a profile name, a server address or an id.

#### Scenario: Failed send recorded

- **WHEN** an inline reply fails before the prompt was sent, with telemetry on
- **THEN** a `notification.reply` log event with `outcome: failed` is recorded and holds no text

### Requirement: Gateway contract for inline replies

An inline reply SHALL use the dashboard's `/api/ws` gateway as the chat does: `session.resume` with `profile` when it has one and the stored session id, then `prompt.submit` with `session_id`, `text` and `queued: true`, whose result `status` is `streaming`, `queued`, `steered` or `redirected`. A result with no status SHALL count as sent. These are in the Hermes OpenRPC contract pinned by `openrpc/HERMES_REF`.

#### Scenario: Prompt queued

- **WHEN** an inline reply is sent
- **THEN** `prompt.submit` carries `queued: true`

#### Scenario: Server without profiles

- **WHEN** the chat has no profile
- **THEN** the reply is still sent
