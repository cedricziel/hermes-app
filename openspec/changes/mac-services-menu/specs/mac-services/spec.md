## Purpose

Lets a Mac user select text in any app and choose Ask Hermes from the Services menu, which opens a new chat with the text quoted in the composer for the user to add a question. Nothing is sent until the user sends it.

## ADDED Requirements

### Requirement: Ask Hermes is a macOS service for text

On macOS the app SHALL offer a service named "Ask Hermes" for plain text, available from the Services menu and the context menu of any app that has selected text. The service SHALL accept text only and SHALL NOT return anything to the calling app. It SHALL have no default keyboard shortcut. On iOS, Android, Windows, Linux and watchOS no service SHALL exist and the app SHALL be unaffected.

#### Scenario: Text selected in another app

- **WHEN** the user selects text in another app and chooses Services > Ask Hermes
- **THEN** Hermes comes to the front with a new chat whose composer holds the selection as a quote

#### Scenario: Nothing usable selected

- **WHEN** the service is invoked and the text is missing or only whitespace
- **THEN** no chat is created, the composer is unchanged and the calling app is not changed

### Requirement: The quote fills the composer and is never sent

The app SHALL open a new chat and put the selected text in its composer as a Markdown block quote (each line prefixed `> `), followed by an empty line, with the cursor after it and the composer focused. The app SHALL NOT send it, attach it as a file or add the name of the source app or window. If the composer already holds text, that text SHALL stay above the quote. A selection longer than 20,000 characters SHALL be cut at a character boundary and end with a line saying it was shortened. When several quotes wait at once, only the most recent SHALL be used.

#### Scenario: Short selection

- **WHEN** the selection is two lines
- **THEN** the composer holds both lines, each starting with `> `, then an empty line, and no message has been sent

#### Scenario: Existing draft

- **WHEN** the composer holds "Summarize:" and the service delivers a selection
- **THEN** the composer holds "Summarize:", an empty line and the quote, and no text is lost

#### Scenario: Very long selection

- **WHEN** the selection is longer than 20,000 characters
- **THEN** the quote holds the first 20,000 characters and a final line saying the selection was shortened

### Requirement: App not running, signed out or locked

If Hermes is not running, invoking the service SHALL start it and deliver the quote after launch. If the app is not connected or not signed in, the quote SHALL be held while the user goes through server setup and sign-in, and SHALL open the new chat once the chat screen is shown. If app lock is on and the app is locked, the quote SHALL NOT be visible before unlock. A held quote SHALL be kept in memory only and SHALL NOT survive the process.

#### Scenario: Cold start

- **WHEN** Hermes is not running and the user invokes the service
- **THEN** Hermes launches and, once signed in, shows a new chat with the quote

#### Scenario: Signed out

- **WHEN** the user is signed out and invokes the service
- **THEN** the sign-in screen shows as usual, and after sign-in the new chat holds the quote

#### Scenario: Locked

- **WHEN** app lock is on, the app is locked and the user invokes the service
- **THEN** only the lock screen shows until unlock, then the new chat with the quote

#### Scenario: Sign out with a quote waiting

- **WHEN** a quote is waiting and the user signs out
- **THEN** the quote is discarded and the next signed-in user does not see it

### Requirement: Window states on macOS

Invoking the service SHALL bring the main window to the front, showing it again if it is hidden, closed to the Dock or minimized. The quote SHALL always go to a new chat in the main window. When a conversation window is key, the conversation window SHALL NOT receive the quote and the chat shown in it SHALL NOT change.

#### Scenario: Main window hidden

- **WHEN** the main window was closed and a conversation window is open, and the user invokes the service from another app
- **THEN** the main window appears with a new chat holding the quote

#### Scenario: Conversation window in front

- **WHEN** a conversation window is key and the user invokes the service
- **THEN** the main window comes forward with the new chat and the conversation window keeps its chat and its draft

### Requirement: Privacy

The selected text SHALL be held in memory only until the chat screen takes it, and SHALL NOT be written to the App Group container, preferences or telemetry. The app SHALL send nothing to the Hermes server because of the service call alone. The service SHALL need no entitlement beyond those the app has.

#### Scenario: Text on disk

- **WHEN** the service delivers a selection
- **THEN** no file in the App Group container or preferences holds it

### Requirement: Backend contract

The service SHALL use no Hermes Agent route or RPC method until the user sends the message. Sending uses the existing chat path. No minimum Hermes version applies to this feature.

#### Scenario: Quote not sent

- **WHEN** the service delivers a quote
- **THEN** no `session.create` or `prompt.submit` is made for it
