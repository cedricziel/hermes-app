# Watch Specification

## Purpose

Describes the watchOS companion app and what it asks of the phone: how the watch lists chats, reads a chat and sends a message by relaying every request through the paired phone, which holds the session and the dashboard connection; how chats are identified across Hermes profiles; the limits and timeouts of the relay; what happens when the agent asks for something the watch cannot answer; and how a failure is worded. The watch has no network of its own and holds no token. Notifications for a turn sent from the watch are described in the notifications spec.

## Requirements

### Requirement: Relay through the phone

The system SHALL let the watch app read and send chats by asking the paired phone, which holds the signed-in session and the connection to the Hermes dashboard. The watch SHALL NOT hold tokens or the server address. The phone SHALL serve the watch from whoever is signed in on the phone at that moment. A request is a `threads`, `messages` or `send` operation, and the answer is either success or one of the error codes in "Watch errors". The relay SHALL exist on iOS only.

#### Scenario: Signed out on the phone

- **WHEN** the watch asks for anything while nobody is signed in on the phone
- **THEN** the phone answers `signed_out` and the watch tells the user to sign in on the iPhone first

#### Scenario: Unknown or malformed request

- **WHEN** the phone gets an operation it does not know, or one missing what it needs (a `messages` request without a thread id, a `send` with blank text)
- **THEN** it answers `bad_request`

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

The system SHALL end a send at once when the agent asks for an approval, a question's answer, or something the app cannot answer (a secret value or a sudo password) during a turn sent from the watch. It SHALL answer success with `failed` false and the text "Hermes asked for something the watch can't answer. Ask again on your iPhone." The text SHALL NOT include the command, the question or anything about a secret. The watch SHALL show it as Hermes's reply. The phone SHALL close the connection that raised the request, since nothing can answer it.

#### Scenario: Approval during a watch turn

- **WHEN** the agent asks for approval to run `rm -rf build` during a turn sent from the watch
- **THEN** the send ends at once, the watch shows the fixed text, and no command text reaches the watch

#### Scenario: Question during a watch turn

- **WHEN** the agent asks a clarifying question during a turn sent from the watch
- **THEN** the send ends at once with the same text

### Requirement: Watch errors

The system SHALL report a failed request with one of these codes and the watch SHALL word each for the user. `signed_out`: "Sign in to Hermes on your iPhone first." with no retry. `unavailable`, answered by the iOS app when Dart has not registered its handler yet: "Open Hermes on your iPhone, then try again." `phoneUnreachable`, raised on the watch when its connection to the phone is not active within about three seconds, the phone cannot be reached, or delivery fails: "Can't reach your iPhone." `failed`, for any other failure, including a request whose reply is malformed: "Something went wrong." `bad_request` reaches the watch as `failed`. Every error except `signed_out` SHALL offer "Try again".

#### Scenario: Phone out of reach

- **WHEN** the watch is not connected to its phone
- **THEN** it shows "Can't reach your iPhone." with a "Try again" control

#### Scenario: Phone app not ready

- **WHEN** the phone's Hermes app has not registered its handler
- **THEN** the phone answers `unavailable` and the watch asks the user to open Hermes on the iPhone
