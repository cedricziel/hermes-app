# Spec Delta

## Purpose

Describes the Lock Screen and StandBy widgets: the Needs you count in the accessory families, and the New Chat, Dictate and Quick launch widgets, what each shows on a locked device and where a tap goes.

## ADDED Requirements

### Requirement: Needs you on the Lock Screen

The Needs you widget SHALL offer the Lock Screen's circular, rectangular and inline families. Circular SHALL show the number of open requests across profiles with a hand symbol. Rectangular SHALL show the number and the kind of the oldest open request ("Approval", "Question" or "Waiting for you") with its chat title. Inline SHALL read "N waiting in Hermes", or "Nothing waiting" when none is open. A tap SHALL open the chat of the oldest open request, or the chat list when none is open. The count and the labels SHALL stay visible on a locked device; the chat title SHALL be redacted while the device is locked, and SHALL be drawn as a redacted placeholder whenever App Lock is on, since the snapshot then holds no title. Signed out, the families SHALL show "Sign in" and open the app.

#### Scenario: Count on a locked phone

- **WHEN** three requests are open and the phone is locked
- **THEN** the circular widget shows 3 and the rectangular widget shows 3 and "Approval" with the chat title hidden

#### Scenario: App Lock on

- **WHEN** App Lock is on, two requests are open and the phone is unlocked
- **THEN** the rectangular widget shows 2 and the kind label with a redacted placeholder instead of the chat title

#### Scenario: Tap from the Lock Screen

- **WHEN** the user taps the circular widget and unlocks
- **THEN** Hermes opens the chat of the oldest open request

#### Scenario: Nothing waiting

- **WHEN** no request is open
- **THEN** the inline widget reads "Nothing waiting" and a tap opens the chat list

### Requirement: New Chat and Dictate widgets

The New Chat widget SHALL be offered as a Lock Screen circular widget and as a small Home Screen and StandBy widget; a tap SHALL open a new chat in the app's current profile with the composer ready. The Dictate widget SHALL be offered in the same families; a tap SHALL open a new chat in the current profile and start dictation, or, where dictation is not available, open the new chat with the composer focused. A medium Quick launch widget SHALL show both as separate buttons. These widgets SHALL show no chat content. Signed out, they SHALL read "Sign in" and a tap SHALL open the app's sign-in.

#### Scenario: New chat from the Lock Screen

- **WHEN** the user taps the New Chat circular widget and unlocks
- **THEN** Hermes opens a new chat in the current profile

#### Scenario: Dictate from StandBy

- **WHEN** the user taps the Dictate widget in StandBy and unlocks
- **THEN** Hermes opens a new chat and the microphone starts

#### Scenario: Quick launch pair

- **WHEN** the user taps Dictate in the medium Quick launch widget
- **THEN** Hermes opens a new chat with dictation started, not a plain new chat

#### Scenario: Signed out

- **WHEN** nobody is signed in and the user taps New Chat
- **THEN** Hermes opens on its sign-in screen

### Requirement: Backend contract

The Lock Screen and StandBy widgets SHALL rely on no Hermes route, RPC method or minimum version of their own; they read only the surface snapshot the app writes.

#### Scenario: Any supported server

- **WHEN** the app is connected to the oldest Hermes it supports
- **THEN** the widgets work without any server change
