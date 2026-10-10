# Spec Delta

## ADDED Requirements

### Requirement: Inline reply to a finished reply

On iOS and macOS, a notification for a completed reply (its body a reply preview or "Reply ready") SHALL offer a "Reply" action with a text field. The action SHALL require the device to be unlocked and SHALL NOT open the app. Sending a non-empty text SHALL send it once, exactly as typed, as a new prompt into that notification's chat in its profile, queued behind any turn still running there. An empty or whitespace-only text SHALL send nothing. "Reply failed", request and scheduled-task notifications SHALL NOT offer the action. The same SHALL happen whether the app is running, suspended or not running when the user replies.

#### Scenario: Reply from the notification

- **WHEN** the user replies "Yes, book it" to the "Reply ready" notification of chat "Trip plan"
- **THEN** "Yes, book it" is sent to "Trip plan" as a prompt, and the app does not open

#### Scenario: Locked device

- **WHEN** the user tries to reply on a locked iPhone
- **THEN** iOS asks to unlock before the text is sent

#### Scenario: Turn still running

- **WHEN** Hermes is running a turn in that chat when the reply is sent
- **THEN** the prompt is queued behind it and does not redirect it

### Requirement: Answer to an inline reply

The answer to an inline reply SHALL arrive as the notifications this spec already defines for the chat ("Reply ready" with its preview, "Reply failed", or a request notification). When the answer completes while Hermes still runs in the background it SHALL be announced at once; otherwise it SHALL be announced by the background check for finished replies when that runs. Closing the background work SHALL NOT itself produce a "Reply failed" notification.

#### Scenario: Quick answer

- **WHEN** Hermes answers the inline reply within 20 seconds
- **THEN** a "Reply ready" notification with the answer's preview replaces the earlier one

#### Scenario: Slow answer

- **WHEN** the answer takes several minutes
- **THEN** no "Reply failed" is shown when the background work stops, and the answer is announced by the next background check

### Requirement: Reply not sent

When an inline reply cannot be sent because nobody is signed in, the stored session cannot be read yet (device not unlocked since restart), the server cannot be reached, the chat or its profile no longer exists, or the send fails before Hermes accepted the prompt, the system SHALL post a notification for that chat with the chat's title and the body "Reply not sent. Open Hermes to try again.", replacing the chat's earlier notification. Its title and body SHALL NOT include the typed text, and it SHALL NOT retry by itself. Tapping it SHALL open the chat through `hermes://chat?profile=<p>&id=<id>&prompt=<typed text>`, with the typed text in the composer and not sent.

#### Scenario: Server unreachable

- **WHEN** the user replies while the server cannot be reached
- **THEN** a "Reply not sent. Open Hermes to try again." notification for the chat appears, and nothing is sent later

#### Scenario: Unsent text restored

- **WHEN** the user taps a "Reply not sent" notification after typing "Yes, book it"
- **THEN** the chat opens with "Yes, book it" in the composer, and nothing is sent

#### Scenario: Every headless outcome handled

- **WHEN** the headless runtime reports signed out, locked or unreachable
- **THEN** each posts "Reply not sent" with outcome `unavailable`, and none is dropped silently

### Requirement: Telemetry for inline replies

The system SHALL record each inline reply as a `background.task` span with `task` = `notification.reply`, `outcome` (`sent`, `answered`, `failed`, `unavailable`) and `engine`, and a log event `notification.reply` with `outcome`; when the running app's engine handled it, also a `notification.reply` breadcrumb with `outcome`. None SHALL carry the typed text, a chat title, a profile name, a server address or an id.

#### Scenario: Failed send recorded

- **WHEN** an inline reply fails to send with telemetry on
- **THEN** a `notification.reply` log event with `outcome: failed` is recorded and holds no text

### Requirement: Gateway contract for inline replies

An inline reply SHALL use the dashboard's `/api/ws` gateway as the chat does: `session.resume` with `profile` and the stored session id, then `prompt.submit` with `session_id`, `text` and `queued: true`, whose result `status` is `streaming`, `queued`, `steered` or `redirected`; the answer arrives as `message.delta` events ending with `message.complete` or an idle `session.info`. These exist in the Hermes version pinned by `HERMES_REF`.

#### Scenario: Prompt queued

- **WHEN** an inline reply is sent
- **THEN** `prompt.submit` carries `queued: true`
