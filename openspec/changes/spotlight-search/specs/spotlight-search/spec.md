# Spec Delta

## Purpose

Describes the opt-in Spotlight index on iOS: the setting, which chats are indexed with what, when they are removed, what tapping a result opens, and the domain-based index other features can add to.

## ADDED Requirements

### Requirement: App Lock clears Spotlight

While App Lock is on, the app SHALL remove every Hermes item from Spotlight and SHALL add none. When App Lock is turned off, the next snapshot SHALL index the recent chats again.

#### Scenario: App Lock turned on

- **WHEN** the user turns App Lock on
- **THEN** searching Spotlight for a chat title finds no Hermes result

### Requirement: Spotlight setting

On iOS and iPadOS the app SHALL offer a "Show chats in Spotlight" switch, off by default, in a "Spotlight" dialog reached from the account menu and from the Settings dialog. The dialog SHALL say that the recent chats' titles and latest messages become searchable on the device while it is unlocked, and that turning the switch off removes them. The choice SHALL persist across launches, and a change made while the saved value is loading SHALL win over the loaded value. On other platforms neither the entry nor the switch SHALL be shown.

#### Scenario: Default

- **WHEN** the user opens the Spotlight dialog on a fresh install
- **THEN** "Show chats in Spotlight" is off and no Hermes chat appears in Spotlight

#### Scenario: Other platforms

- **WHEN** the user opens the account menu on Android or macOS
- **THEN** there is no Spotlight entry

### Requirement: What is indexed

While the switch is on and a user is signed in, the system SHALL keep the recent chats of the app's surface snapshot (at most ten, across profiles) in Spotlight, each with the chat's title and its latest-message snippet of at most 120 characters. When the app records a new snapshot, chats that joined it SHALL be added, changed titles or snippets SHALL be updated, and chats no longer in it SHALL be removed. Nothing else SHALL be indexed: no older chat, no full message, no command, question or secret, no token or server address. Indexed items SHALL NOT be searchable while the device is locked.

#### Scenario: Turning it on

- **WHEN** the user turns the switch on with chats "Trip plan" and "Groceries" in the snapshot
- **THEN** searching Spotlight for "Trip" lists "Trip plan" from Hermes with its latest-message snippet

#### Scenario: Chat renamed

- **WHEN** "Trip plan" is renamed "Lisbon trip" and the app records a new snapshot
- **THEN** Spotlight lists "Lisbon trip" and no longer "Trip plan"

#### Scenario: Locked device

- **WHEN** the device is locked
- **THEN** no Hermes chat is found in Spotlight

### Requirement: Removing indexed chats

The system SHALL remove every Hermes item from Spotlight when the user turns the switch off, signs out, or changes the server. When a removal fails, the system SHALL try again on the next launch until it succeeds.

#### Scenario: Sign-out

- **WHEN** the user signs out with the switch on
- **THEN** searching Spotlight finds no Hermes chat

#### Scenario: Switching off

- **WHEN** the user turns the switch off
- **THEN** every Hermes chat disappears from Spotlight

### Requirement: Opening a result

Tapping a Hermes chat in Spotlight SHALL open Hermes on that chat in its profile, loading it if it is not among the loaded chats, whether or not the app was running. When the chat cannot be opened, the app SHALL show "Could not open that chat." Handoff activities SHALL remain ineligible for search.

#### Scenario: From a cold start

- **WHEN** Hermes is not running and the user taps "Trip plan" in Spotlight
- **THEN** Hermes starts and opens "Trip plan" in its profile

#### Scenario: Chat deleted since

- **WHEN** the user taps a result for a chat that was deleted on the server
- **THEN** Hermes shows "Could not open that chat."

### Requirement: Domain-based index

Every indexed item SHALL belong to a named domain and carry an id, a title, a text and a `hermes://` link that opens it. Replacing or removing a domain's items SHALL leave other domains' items untouched. Chats SHALL use the `chat` domain.

#### Scenario: Another domain

- **WHEN** a later feature indexes items in a `memory` domain and the chat set is replaced
- **THEN** the `memory` items stay in Spotlight

### Requirement: Backend contract

Spotlight indexing SHALL rely on no Hermes route, RPC method or minimum version of its own; its data comes from the surface snapshot the app writes from the routes it already uses.

#### Scenario: Any supported server

- **WHEN** the app is connected to the oldest Hermes it supports
- **THEN** Spotlight indexing works without any server change
