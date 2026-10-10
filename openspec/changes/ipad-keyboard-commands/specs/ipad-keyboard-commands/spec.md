# Spec Delta

## Purpose

Describes the commands Hermes adds to the iPadOS menu bar and to the list shown while ⌘ is held: which commands, their shortcuts, how they are enabled by the screen in front, and how they leave text editing keys alone.

## ADDED Requirements

### Requirement: iPad menu bar commands

On iPadOS, and on an iPhone with a hardware keyboard where holding ⌘ lists the app's commands, the system SHALL add these items to the system menus, in this order:

- Hermes: About Hermes; Settings… (⌘,); Connection Details, Sign Out…
- File: New Chat (⌘N)
- View: Back (⌘[)
- Chat: Find… (⌘F); Pin or Unpin (⇧⌘P), Rename…, Copy Transcript; Archive, Delete…
- Help: Hermes Help

The items SHALL do what the same macOS menu items do, including asking before signing out, renaming or deleting. The system's own Find and Format menus and its New Window item SHALL NOT be shown. Open in New Window, Close Window, the list of conversation windows, Show Sidebar and Show Inspector SHALL NOT be offered on iPad.

#### Scenario: Holding Command

- **WHEN** the user holds ⌘ on an iPad with a keyboard while a chat is selected
- **THEN** the list shows New Chat, Find…, Pin, Rename…, Copy Transcript, Archive and Delete… with their shortcuts

#### Scenario: New chat from the keyboard

- **WHEN** the user presses ⌘N on the chat screen
- **THEN** a new chat starts, once

#### Scenario: Settings from the menu bar

- **WHEN** the user picks Settings… in the Hermes menu
- **THEN** the Settings dialog opens

### Requirement: Enablement follows the screen in front

An iPad item SHALL be enabled exactly when the screen on view offers its command, under the same rules as the macOS menu bar: a hidden page offers nothing, the innermost or latest screen wins, and an item's label follows the screen ("New Task" on Kanban, "New Schedule" on Schedules, "Unpin" for a pinned chat). A disabled item's shortcut SHALL NOT be taken by the menu, so the key reaches the app as it would without the menu.

#### Scenario: New Task on Kanban

- **WHEN** the Kanban board is on view and the user opens the File menu
- **THEN** it shows "New Task", and ⌘N opens the new task form

#### Scenario: No chat selected

- **WHEN** no chat is selected
- **THEN** Pin, Rename…, Copy Transcript, Archive and Delete… are disabled

#### Scenario: Back on a settings page

- **WHEN** a settings page such as Skills is open and the user presses ⌘[
- **THEN** the page closes; with no page to leave, Back is disabled

### Requirement: Find on iPad

Find… SHALL put the cursor in the sidebar's chat search field when the sidebar is on screen, and SHALL be disabled when it is not.

#### Scenario: Wide layout

- **WHEN** the iPad shows the chat sidebar and the user presses ⌘F
- **THEN** the sidebar's search field has focus

### Requirement: Text editing keys stay with the text field

The menu SHALL NOT bind ⌘C, ⌘V, ⌘X, ⌘A, ⌘Z, ⇧⌘Z or ⌘⌫. The system's Edit menu SHALL keep acting on the focused text field. Delete… SHALL have no shortcut on iPad, so ⌘⌫ in a text field deletes to the start of the line.

#### Scenario: Copy in the composer

- **WHEN** the user selects text in the composer and presses ⌘C, then ⌘V
- **THEN** the text is copied and pasted

#### Scenario: Command-Delete in the composer

- **WHEN** the composer has focus and the user presses ⌘⌫
- **THEN** the text before the cursor on that line is deleted and the selected chat is kept

### Requirement: Backend contract

The iPad commands SHALL rely on no Hermes route, RPC method or minimum version beyond those the same actions already use.

#### Scenario: Any supported server

- **WHEN** the app is connected to the oldest Hermes it supports
- **THEN** the commands work as the same actions do in the app
