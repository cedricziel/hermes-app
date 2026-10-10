# Spec Delta

## Purpose

Describes what the watch advertises for Handoff and what the phone sends for it.

## MODIFIED Requirements

### Requirement: Relay through the phone

The system SHALL let the watch app read and send chats by asking the paired phone, which holds the signed-in session and the connection to the Hermes dashboard. The watch SHALL NOT hold tokens, and SHALL hold the server address only to pass it on for Handoff, never to connect to it. The phone SHALL serve the watch from whoever is signed in on the phone at that moment. A request is a `threads`, `messages` or `send` operation, and the answer is either success or one of the error codes in "Watch errors". The relay SHALL exist on iOS only.

#### Scenario: Signed out on the phone

- **WHEN** the watch asks for anything while nobody is signed in on the phone
- **THEN** the phone answers `signed_out` and the watch tells the user to sign in on the iPhone first

#### Scenario: Unknown or malformed request

- **WHEN** the phone gets an operation it does not know, or one missing what it needs (a `messages` request without a thread id, a `send` with blank text)
- **THEN** it answers `bad_request`

## ADDED Requirements

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
