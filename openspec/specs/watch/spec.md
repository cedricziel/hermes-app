# Watch Specification

## Purpose

Describes the watchOS companion app and what it asks of the phone: how the watch lists chats, reads a chat and sends a message by relaying every request through the paired phone, which holds the session and the dashboard connection; how chats are identified across Hermes profiles; the limits and timeouts of the relay; what happens when the agent asks for something the watch cannot answer; and how a failure is worded. The watch has no network of its own and holds no token. Notifications for a turn sent from the watch are described in the notifications spec.

## Requirements

### Requirement: Relay through the phone

The system SHALL let the watch app read and send chats by asking the paired phone, which holds the signed-in session and the connection to the Hermes dashboard. The watch SHALL NOT hold tokens, and SHALL hold the server address only to pass it on for Handoff, never to connect to it. The phone SHALL serve the watch from whoever is signed in on the phone at that moment. A request is a `threads`, `messages` or `send` operation, and the answer is either success or one of the error codes in "Watch errors". The relay SHALL exist on iOS only.

#### Scenario: Signed out on the phone

- **WHEN** the watch asks for anything while nobody is signed in on the phone
- **THEN** the phone answers `signed_out` and the watch tells the user to sign in on the iPhone first

#### Scenario: Unknown or malformed request

- **WHEN** the phone gets an operation it does not know, or one missing what it needs (a `messages` request without a thread id, a `send` with blank text)
- **THEN** it answers `bad_request`

### Requirement: Watch relay diagnostics

When iPhone telemetry is enabled, the system SHALL export `watch.request.started` and `watch.request.completed` events for each request received by the Dart relay. Both events SHALL include the operation and current phone authentication state. The completion event SHALL include the result code and elapsed milliseconds. Unknown operations SHALL be recorded as `unknown`. Events SHALL NOT include message text, audio, thread identifiers, tokens, or request payloads. A telemetry failure SHALL NOT prevent the relay from replying.

The watch SHALL write local Apple logs for activation, reachability changes, request starts, reply results, and delivery failures. The native iPhone relay SHALL write local Apple logs for activation, background-task expiry, a missing Dart handler, and invalid Dart replies. These local logs SHALL NOT contain request payloads or exception messages.

When the phone cannot read its saved session from secure storage, it SHALL export `auth.session.read_failed` through its configured event logger, with the exception type only. The stored session SHALL remain untouched.

#### Scenario: Signed-out relay reply

- **WHEN** the phone answers a watch request with `signed_out` while telemetry is enabled
- **THEN** the completion event records `signed_out`, the phone authentication state, and elapsed milliseconds

#### Scenario: Secure storage unavailable

- **WHEN** secure storage throws while the phone restores its session
- **THEN** the phone records `auth.session.read_failed` without token contents or exception details

#### Scenario: Watch cannot deliver a request

- **WHEN** WatchConnectivity fails to deliver a request to the phone
- **THEN** the watch writes a local delivery-failure log with the operation and numeric error code

### Requirement: Watch thread list

The system SHALL answer a `threads` request with at most 20 of the most recent chats of the active Hermes profile, in the order the dashboard lists them. Each carries an id, a title, the time it was last active (whole seconds) and whether it is pinned. The watch SHALL show each title on up to two lines, mark pinned chats with a pin, refresh on pull, and offer a control to start a new chat. It SHALL show "No chats yet." for an empty list.

#### Scenario: Recent chats

- **WHEN** the watch app opens and the profile has chats
- **THEN** the chats appear most recent first, with pinned ones marked

#### Scenario: More chats than fit

- **WHEN** the dashboard returns more than 20 chats, for example because it appends every pinned chat to a page
- **THEN** only the first 20 are sent to the watch

#### Scenario: Row without an id or title

- **WHEN** a row the watch receives has no id or no title
- **THEN** the watch skips that row and shows the rest

### Requirement: Profile-scoped thread ids

The system SHALL tie every thread id it gives the watch to the Hermes profile the chat was listed under, in the form `<percent-encoded profile>/<session id>`, because a session id is only unique within a profile. The watch SHALL treat the id as opaque and hand it back unchanged. The system SHALL answer `bad_request` to a `messages` or `send` request whose id is malformed or whose profile is no longer the active one. A send into such a chat SHALL NOT reach the gateway.

#### Scenario: Profile switched since the list was loaded

- **WHEN** the active profile is switched on the phone and the watch then opens a chat listed under the old one
- **THEN** the phone answers `bad_request` and nothing is read or sent

#### Scenario: Same session id in two profiles

- **WHEN** two profiles each have a session with the id `s1`
- **THEN** the watch sees two different ids and each request reads or writes only its own profile's session

### Requirement: Reading a chat on the watch

The system SHALL answer a `messages` request with the last 20 messages of the chat, oldest first, each with an id, a role (user or assistant), its text and its time. A text longer than 4000 characters SHALL be cut there and end with an ellipsis. The watch SHALL show the messages in order and show an indicator while they load.

#### Scenario: Long chat

- **WHEN** a chat holds 30 messages
- **THEN** the watch receives the last 20, in order

#### Scenario: Very long message

- **WHEN** a message holds 5000 characters
- **THEN** the watch receives its first 4000 characters and an ellipsis

### Requirement: Sending from the watch

The system SHALL send a message the user dictates or types on the watch into the chosen chat, or into a new chat when none is chosen, in the active Hermes profile. The text SHALL be trimmed and a blank text SHALL NOT be sent. The phone SHALL answer once the reply is complete, with the chat's thread id, the final text and whether the turn ended in failure; the reply SHALL NOT stream to the watch. When a turn that did not fail completes with a blank final text, the phone SHALL answer with the text that had streamed, or, when nothing streamed either, with "Hermes replied without any text.", so the watch never shows an empty reply; such a reply is not a failure, as for its notification. While waiting the watch SHALL show the user's message and "Hermes is thinking…", and SHALL NOT send another message. The phone SHALL give up and answer `failed` when no event arrives for 60 seconds. When a send fails the watch SHALL remove the message it showed, keep its text, show the reason and offer "Try again", which sends the same text.

#### Scenario: New chat

- **WHEN** the user sends "Hello" from the new chat control
- **THEN** the phone starts a chat, answers with its thread id and the reply, and the watch shows both messages and sends the next one into that chat

#### Scenario: Reply without text

- **WHEN** a turn completes without failure, its final text is blank and nothing streamed
- **THEN** the phone answers success with `failed` false and the text "Hermes replied without any text."

#### Scenario: Final text empty after streaming

- **WHEN** a turn completes without failure with a blank final text after "Hi there" streamed
- **THEN** the phone answers with "Hi there"

#### Scenario: Failed turn

- **WHEN** the reply ends in failure with the message "Model unavailable"
- **THEN** the watch shows that message as the reply

#### Scenario: Connection drops

- **WHEN** the connection to the dashboard drops or the stream ends before a reply
- **THEN** the phone answers `failed` and the watch offers to try again with the same text

#### Scenario: Silent gateway

- **WHEN** no event arrives for 60 seconds
- **THEN** the phone gives up and answers `failed`

### Requirement: Requests the watch cannot answer

The system SHALL keep a send going when the agent asks for an approval or a question's answer during a turn sent from the watch. The phone SHALL post the actionable notification of the notifications spec, which watchOS mirrors, so the user can answer on the watch or the phone. When the watch's request says it can be answered this way (`waits: true`) and an answerable notification was posted, the phone SHALL answer the send at once with success, the chat's thread id and `waiting` set to `approval` or `question`, without the command or the question. Otherwise (an older watch, notifications off or not allowed, App Lock on) the send SHALL end as for a request the watch cannot answer; the notification is posted for an older watch all the same. The watch SHALL then show "Waiting for your approval" or "Hermes has a question" in place of "Hermes is thinking…" and send the same request again with the same send id, the chat's thread id and `retry` set, for at most 20 minutes. A phone that no longer knows a send asked with `retry` (for example because iOS ended the app meanwhile) SHALL NOT send the prompt again: it SHALL answer with the chat's latest reply, or "Hermes is still replying. Open the chat again in a moment." when it has none, and `failed` when the retry names no chat. A retry of a waiting send SHALL be answered with the final reply once the turn completes, at once with the new state when it differs from the one the watch was told last (`working` once the turn goes on), and otherwise with the same waiting answer after 20 seconds. The send SHALL wait while any of the turn's requests is open: an expired or withdrawn request leaves the others, and the turn going on closes a request only when it is the only one open. When a retry fails, the watch SHALL keep the message and offer "Try again", which asks again with `retry` instead of sending the message again. While it waits the watch SHALL offer "Stop waiting", which ends the wait on the watch, keeps the message and lets the user send again. While the send waits the phone SHALL give up only after 15 minutes without an event, instead of 60 seconds. Any event that continues the turn SHALL end the waiting state.

The system SHALL end a send at once when the agent asks for something the app cannot answer (a secret value, a sudo password or a vault prompt) during a turn sent from the watch. It SHALL answer success with `failed` false and the text "Hermes asked for something the watch can't answer. Ask again on your iPhone." The text SHALL NOT include anything about what is asked for. The watch SHALL show it as Hermes's reply. The phone SHALL close the connection that raised the request, since nothing can answer it.

#### Scenario: Approval during a watch turn

- **WHEN** the agent asks for approval to run `rm -rf build` during a turn sent from the watch
- **THEN** the phone answers with `waiting` set to `approval`, the watch shows "Waiting for your approval", and no command text reaches the watch's reply

#### Scenario: Approved from the notification

- **WHEN** the user picks "Allow once" on the mirrored notification and the turn completes with "Done."
- **THEN** the watch's next retry of the send gets "Done." as the reply

#### Scenario: Still waiting

- **WHEN** a waiting send is retried and nothing happens for 20 seconds
- **THEN** the phone answers with the same waiting state and the watch keeps waiting

#### Scenario: Phone app ended while waiting

- **WHEN** iOS ends the phone app while a watch send waits, and the watch asks again with `retry`
- **THEN** the phone reads the chat instead of sending the prompt again

#### Scenario: Stop waiting

- **WHEN** the user picks "Stop waiting" while the watch shows "Waiting for your approval"
- **THEN** the message stays, the watch asks the phone no more, and the user can send another message

#### Scenario: Older watch

- **WHEN** a watch that does not send `waits` sends a message and the agent asks for approval
- **THEN** the send ends with the fixed text, as before

#### Scenario: Question during a watch turn

- **WHEN** the agent asks a clarifying question during a turn sent from the watch
- **THEN** the watch shows "Hermes has a question"

#### Scenario: Sudo password during a watch turn

- **WHEN** the agent asks for a sudo password during a turn sent from the watch
- **THEN** the send ends at once with the fixed text and the connection is closed

### Requirement: Watch errors

The system SHALL report a failed request with one of these codes and the watch SHALL word each for the user. `signed_out`: "Sign in to Hermes on your iPhone first." with no retry. `unavailable`, answered by the iOS app when Dart has not registered its handler yet: "Open Hermes on your iPhone, then try again." `phoneUnreachable`, raised on the watch when its connection to the phone is not active within about three seconds, the phone cannot be reached, or delivery fails: "Can't reach your iPhone." `failed`, for any other failure, including a request whose reply is malformed: "Something went wrong." `bad_request` reaches the watch as `failed`. Every error except `signed_out` SHALL offer "Try again".

#### Scenario: Phone out of reach

- **WHEN** the watch is not connected to its phone
- **THEN** it shows "Can't reach your iPhone." with a "Try again" control

#### Scenario: Phone app not ready

- **WHEN** the phone's Hermes app has not registered its handler
- **THEN** the phone answers `unavailable` and the watch asks the user to open Hermes on the iPhone

### Requirement: Handoff from a watch chat

The phone SHALL add `serverUrl` (the canonical server address), `profile` and `sessionId` (the raw session id, not the bound thread id) to each chat of a `threads` answer and to every `send` answer that names a thread, and SHALL leave all three out when it has no server address or no profile. While a chat that has them is open, the watch SHALL advertise an activity of the Handoff type the apps declare (`HERMES_HANDOFF_TYPE`) whose user info is the apps' version 1 payload (`version`, `serverUrl`, `profile`, `threadId` = the session id), and SHALL withdraw it when the chat closes. The activity SHALL carry no title text beyond the generic one, no message text and no credentials. A chat without the fields SHALL NOT be advertised.

#### Scenario: Open a listed chat

- **WHEN** the user opens a chat that the phone listed with its server address and profile
- **THEN** the watch advertises a Handoff activity with that address, profile and the chat's raw session id, and an iPhone or Mac signed in to that server can continue it

#### Scenario: Chat started on the watch

- **WHEN** the user's first message starts a new chat and the phone answers it
- **THEN** the answer carries the fields and the watch advertises the chat without reloading the list

#### Scenario: Close the chat

- **WHEN** the user leaves the chat
- **THEN** the activity is withdrawn

#### Scenario: Phone cannot name the server or profile

- **WHEN** the phone's answer has no `serverUrl` or no `profile`
- **THEN** the watch advertises nothing for that chat

### Requirement: Quick replies and double tap

The watch SHALL show the fixed quick replies "Continue", "Yes", "No" and "Summarize" above the reply field of a chat. Tapping one SHALL send its text as a message under the rules of "Sending from the watch", and the quick replies SHALL be disabled whenever the field is, in particular while a reply is pending. They SHALL NOT be shown while a voice message is being recorded. On watchOS 11 and later, the double-tap gesture SHALL start a voice message when the chat is idle, and stop and send the recording while one is being made; it SHALL do nothing while the voice button is disabled.

#### Scenario: Tap a quick reply

- **WHEN** the user taps "Yes" in an idle chat
- **THEN** the watch sends "Yes" into that chat and shows "Hermes is thinking…"

#### Scenario: Reply pending

- **WHEN** a reply is pending
- **THEN** the quick replies are disabled and a tap sends nothing

#### Scenario: Double tap while idle

- **WHEN** the user double taps in an idle chat
- **THEN** a voice message starts recording

#### Scenario: Double tap while recording

- **WHEN** the user double taps while recording
- **THEN** the recording stops and is sent as a voice message
