# Spec Delta

## Purpose

Describes the iOS App Intents that open Hermes from Siri, the Shortcuts app, the Action button and Control Center / Lock Screen controls: which intents exist, the chats and profiles they can be given, the links they open, and what they may show.

## ADDED Requirements

### Requirement: Opening intents

The system SHALL offer on iOS three App Intents that open the Hermes app and do nothing else:

- "Open Chat", with a required Chat parameter, SHALL open that chat in its profile, by the link `hermes://chat?profile=<profile>&id=<thread id>`;
- "New Chat", with an optional Profile parameter, SHALL open a new chat by the link `hermes://new`, with `profile=<profile>` when a profile is given or known;
- "Dictate", with an optional Profile parameter, SHALL open a new chat with the microphone started, by the link `hermes://new?dictate=1`, with the profile as for "New Chat".

Without a Profile, the intents SHALL use the profile the app last reported as current; when none is known, the link SHALL carry no profile. Query values SHALL be percent-encoded and SHALL match the links the app itself builds for the same target. None of these intents SHALL send a prompt, read secure storage or reach the network. Each SHALL be usable from Siri, the Shortcuts app and the Action button.

#### Scenario: New chat from Siri

- **WHEN** the user says "New Hermes chat" and the app's current profile is `work`
- **THEN** Hermes opens on a new chat in the `work` profile

#### Scenario: Dictate from the Action button

- **WHEN** the Action button runs the "Dictate" intent
- **THEN** Hermes opens on a new chat with dictation started, and nothing is sent until the user sends it

#### Scenario: Profile with special characters

- **WHEN** "New Chat" runs with the profile `R&D team`
- **THEN** the link opened is `hermes://new?profile=R%26D%20team`

#### Scenario: Signed out

- **WHEN** an intent runs while nobody is signed in
- **THEN** Hermes opens on its setup or sign-in screen and no chat is opened

### Requirement: Chat entity

The Chat parameter SHALL offer the recent chats the app last shared with the system (at most 10, newest first, across profiles), each shown with its title and, when chats of more than one profile are offered, its profile. Searching SHALL match chat titles ignoring case and diacritics. A chat SHALL be identified by its profile and thread id together, so chats with the same id in two profiles stay apart. A chat that a saved shortcut or control names but that is no longer among the shared chats SHALL still open, shown with the title "Chat". While nobody is signed in the parameter SHALL offer no chats. While App Lock is on, the shared chats carry no titles; each SHALL be shown as "Chat" with its profile, and title search and spoken chat names SHALL match nothing. The chat entity SHALL NOT be indexed in Spotlight.

#### Scenario: App Lock on

- **WHEN** App Lock is on and the user opens the Chat parameter
- **THEN** the recent chats are listed as "Chat" with their profiles, and no title is shown

#### Scenario: Pick a recent chat

- **WHEN** the user adds "Open Chat" in Shortcuts and taps the Chat parameter
- **THEN** the recent chats are listed newest first with their titles

#### Scenario: Older chat in a saved shortcut

- **WHEN** a saved shortcut opens a chat that has dropped out of the recent chats
- **THEN** Hermes opens and loads that chat

#### Scenario: Same id in two profiles

- **WHEN** profiles `default` and `work` each have a recent chat with id `abc`
- **THEN** both are offered, each with its profile, and each opens in its own profile

### Requirement: Profile parameter

The Profile parameter SHALL offer the server's profiles from the snapshot's `profiles` list, the app's current profile first, without duplicates. When that list is missing or empty, it SHALL offer the current profile and those of the recent chats. Leaving it empty SHALL mean the app's current profile.

#### Scenario: Profile without recent chats

- **WHEN** the snapshot's `profiles` is `["default", "work"]` and only `default` has recent chats
- **THEN** the Profile parameter offers both `default` and `work`

#### Scenario: Default profile

- **WHEN** "New Chat" runs without a Profile and the app's current profile is `default`
- **THEN** the new chat opens in `default`

### Requirement: Siri phrases

The system SHALL register App Shortcuts so the intents work by voice without setup: "New Hermes chat" and "Start a Hermes chat" for New Chat; "Talk to Hermes", "Voice chat with Hermes" and "Dictate to Hermes" for Dictate; "Open <chat> in Hermes" for Open Chat, where <chat> is one of the offered chats. The app SHALL ask the system to refresh the offered chats each time it shares a new list of recent chats.

#### Scenario: Open a chat by name

- **WHEN** the user says "Open Trip plan in Hermes" and "Trip plan" is a recent chat
- **THEN** Hermes opens on that chat

#### Scenario: A chat renamed

- **WHEN** a chat is renamed and the app shares its recent chats again
- **THEN** Siri recognizes the new title

### Requirement: Controls

The system SHALL offer on iOS three controls for Control Center, the Lock Screen and the Action button: "New Chat" and "Dictate", which run the intents of the same name, and "Open Chat", which the user configures with a chat and which shows that chat's title (or "Open Chat" before one is chosen). A control SHALL open the app on its link; iOS asks to unlock the device first when it is locked.

#### Scenario: Dictate from the Lock Screen

- **WHEN** the user taps the Dictate control on the Lock Screen and unlocks
- **THEN** Hermes opens on a new chat with dictation started

#### Scenario: Configured Open Chat control

- **WHEN** the user adds the Open Chat control and chooses "Trip plan"
- **THEN** the control shows "Trip plan" and opens that chat

### Requirement: What intents may show

Intents, entities and controls SHALL read only the list of recent chats and profiles the app shares with the system: chat titles, profile names, thread ids and update times. They SHALL NOT hold or show tokens, the server address, message text other than titles, or any request's command or question. The app does not rely on any Hermes route or RPC method for these intents.

#### Scenario: Snapshot unreadable

- **WHEN** the shared list is missing or cannot be read
- **THEN** the Chat and Profile parameters offer nothing, and New Chat and Dictate still open the app without a profile
