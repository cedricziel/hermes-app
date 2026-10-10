# Spec Delta

## Purpose

Describes the items shown when the user long-presses the Hermes app icon on iOS and Android: New Chat, Dictate and the recent chats, what each opens, how the list follows the app's state, and what happens when nobody is signed in.

## ADDED Requirements

### Requirement: App Lock clears recent chats from the menu

While App Lock is on, the long-press menu SHALL hold only "New Chat" and "Dictate"; recent chats SHALL be removed and SHALL return once App Lock is turned off and the snapshot is written again.

#### Scenario: App Lock turned on

- **WHEN** the user turns App Lock on and the snapshot is written
- **THEN** the long-press menu shows only New Chat and Dictate

### Requirement: App icon items

On iOS and Android the app icon's long-press menu SHALL list, in this order: "New Chat", "Dictate", and up to two recent chats, newest first across profiles, each titled with the chat's title. A chat without a title SHALL be left out. The menu SHALL hold at most four items, the iOS limit. On iOS a recent chat SHALL show its profile under the title when chats of more than one profile are listed. No item SHALL show a message snippet. The items SHALL NOT be offered on macOS, Windows or Linux.

#### Scenario: Long-press on Android

- **WHEN** the user has chats "Trip plan", "Groceries" and "Taxes" and long-presses the icon on Android
- **THEN** the menu shows New Chat, Dictate, Trip plan and Groceries, four items in all

#### Scenario: Long-press on iPhone

- **WHEN** the user long-presses the icon on iPhone
- **THEN** the menu shows New Chat, Dictate and the two newest chats

### Requirement: What an item opens

"New Chat" SHALL open a new chat in the app's current profile. "Dictate" SHALL open a new chat in the current profile and start dictation, or, where dictation is not available, open the new chat with the composer focused. A recent chat SHALL open that chat in its profile, loading it if it is not among the loaded chats; when it cannot be opened the app SHALL show "Could not open that chat." An item SHALL behave the same whether the app was running or was started by it.

#### Scenario: Recent chat from a cold start

- **WHEN** Hermes is not running and the user picks "Trip plan" from the icon menu
- **THEN** Hermes starts and opens "Trip plan" in its profile

#### Scenario: Dictate

- **WHEN** the user picks "Dictate"
- **THEN** Hermes opens a new chat and the microphone starts

#### Scenario: Deleted chat

- **WHEN** the user picks a recent chat that was deleted on the server since
- **THEN** Hermes shows "Could not open that chat."

### Requirement: Items follow the app

The recent chats SHALL be updated whenever the app records new state for its surfaces (chat list loaded, reply finished, profile switched). When nobody is signed in, the app SHALL remove all its items, and sign-in SHALL bring them back.

#### Scenario: New chat becomes recent

- **WHEN** the user finishes a reply in a new chat "Recipes" and then long-presses the icon
- **THEN** "Recipes" is the first recent chat

#### Scenario: Sign-out

- **WHEN** the user signs out and long-presses the icon
- **THEN** no Hermes item is listed

### Requirement: Backend contract

The app icon items SHALL rely on no Hermes route, RPC method or minimum version of their own; the recent chats come from the surface snapshot the app writes from the routes it already uses.

#### Scenario: Any supported server

- **WHEN** the app is connected to the oldest Hermes it supports
- **THEN** the items work without any server change
