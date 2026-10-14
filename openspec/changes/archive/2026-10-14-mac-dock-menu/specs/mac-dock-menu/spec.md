## ADDED Requirements

### Requirement: Dock menu content

On macOS the app SHALL show a Dock icon menu with, in this order: **New Chat**, up to five recent chats, a separator, and **Show Main Window**. Recent chats SHALL be saved chats of the profile the chat screen currently shows, excluding hidden Bot Mode registry chats and hosted group rooms, ordered by last update, most recent first, regardless of pinning. Each chat item SHALL show the chat's title, shortened to 40 characters, or "Untitled chat" when it has none. While the app is locked the menu SHALL show only New Chat and Show Main Window. The menu SHALL be built without waiting for the Dart isolate. No Dock menu SHALL be added on iOS, Android, Windows, Linux or watchOS.

#### Scenario: Recent chats

- **WHEN** a signed-in, unlocked user with seven saved chats opens the Dock menu
- **THEN** it shows New Chat, the five most recently updated chats, and Show Main Window

#### Scenario: A reply finishes

- **WHEN** a chat finishes a reply and becomes the most recently updated
- **THEN** the next Dock menu lists it first

#### Scenario: Profile switch

- **WHEN** the user switches the chat screen to another profile
- **THEN** the next Dock menu lists that profile's chats

#### Scenario: Unresolved profile

- **WHEN** the chat screen has no resolved profile
- **THEN** the menu shows no chat items

### Requirement: Picking a chat

Picking a chat SHALL open it in its conversation window when one is open, bringing that window to the front. Otherwise the app SHALL bring the main window forward, even if it was closed or hidden, and open the chat there, including a chat outside the loaded pages. No prompt SHALL be sent and no reply interrupted. If the chat cannot be opened, the app SHALL show the existing chat-open failure and SHALL NOT create a replacement chat.

#### Scenario: Chat in a window

- **WHEN** the user picks a chat that is open in a conversation window
- **THEN** that window comes to the front and the main window is unchanged

#### Scenario: Hidden main window

- **WHEN** the main window is hidden and the user picks a chat that has no window
- **THEN** the main window appears with that chat selected

#### Scenario: Chat gone

- **WHEN** the picked chat was deleted since the menu was built
- **THEN** the app reports that the chat is unavailable and creates nothing

### Requirement: New Chat and Show Main Window

New Chat SHALL bring the main window forward and start a new, unsaved chat in it. While the app is locked, New Chat SHALL bring the main window forward with the unlock prompt and SHALL open the new chat only after a successful unlock; if the unlock fails or is dismissed, the app SHALL do nothing further, and a later manual unlock SHALL NOT run the cancelled action. Show Main Window SHALL bring the main window forward and SHALL work in every state, including signed out, locked, and before Dart has connected.

#### Scenario: New Chat while locked

- **WHEN** app lock covers the app and the user picks New Chat and unlocks successfully
- **THEN** the main window shows an empty new chat

#### Scenario: Unlock fails or is dismissed

- **WHEN** the user picks New Chat while locked and the unlock fails or is dismissed
- **THEN** no chat is created, and unlocking later through the lock screen does not create one

#### Scenario: Cancelled by sign-out or relock

- **WHEN** a New Chat is waiting for the unlock and the user signs out or the app locks again before it ran
- **THEN** the action is dropped

#### Scenario: New chat from a conversation window

- **WHEN** a conversation window is key and the user picks New Chat
- **THEN** the main window shows an empty new chat

### Requirement: No chat titles unless signed in and unlocked

The Dock menu SHALL list recent chats only while the connection is ready and the app is not locked, and New Chat only while the connection is ready, locked or not. When the user signs out, changes server, or loses the connection state, the native copy of the chat list SHALL be discarded and the menu SHALL show only Show Main Window. When the app locks, the copy SHALL be discarded and the menu SHALL show New Chat and Show Main Window. Titles, thread ids and profile names SHALL NOT be persisted, written to preferences or secure storage, or sent to telemetry.

#### Scenario: Sign out

- **WHEN** the user signs out
- **THEN** the Dock menu shows only Show Main Window and the app keeps no chat titles

#### Scenario: App lock

- **WHEN** app lock covers the app
- **THEN** the Dock menu shows New Chat and Show Main Window and no chat titles, and shows the chats again after unlock

### Requirement: Observability without content

Picking a Dock item SHALL record a breadcrumb with the action kind and whether a conversation window handled it. A New Chat that waited for an unlock SHALL record a breadcrumb with its outcome (`completed` or `cancelled`). A failed open SHALL be logged with a failure kind. These signals SHALL NOT contain titles, thread ids, profile names, or server addresses.

#### Scenario: Breadcrumb content

- **WHEN** the user picks a chat from the Dock
- **THEN** the breadcrumb holds `action: open_chat`, a window flag and a deferred flag, and nothing identifying the chat

### Requirement: Backend contract

The Dock menu SHALL use only data the app already holds and the existing chat-opening paths (`GET /api/sessions` and the session history routes through the existing repositories). It SHALL add no Hermes route and no RPC method. The minimum Hermes version is that of the existing chat feature; no new minimum applies.

#### Scenario: No new request

- **WHEN** the Dock menu is built
- **THEN** no network request is made
