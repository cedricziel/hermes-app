# Spec Delta

## Purpose

Gives the Mac app a Settings window of its own, opened and focused with ⌘,, that holds no session.

## ADDED Requirements

### Requirement: Settings is a window on macOS

On macOS, Settings… (⌘, and the sidebar account menu's Settings…) SHALL open one Settings window beside the main window, not a dialog over it. Other platforms SHALL keep the settings dialog.

#### Scenario: Open

- **WHEN** the user presses ⌘, and no Settings window is open
- **THEN** a Settings window opens and the main window stays usable, with no scrim over it

#### Scenario: Already open

- **WHEN** the user presses ⌘, or chooses Settings… while the window is open
- **THEN** that window comes to the front and takes focus, and no second window opens

#### Scenario: Close

- **WHEN** the user presses ⌘W in the Settings window
- **THEN** only the Settings window closes

#### Scenario: Other platforms

- **WHEN** the user opens Settings on iOS, Android, Windows or Linux
- **THEN** the existing settings dialog opens

### Requirement: The window holds no session

The Settings window SHALL NOT hold a token, an authenticated client, an App Lock state or the server address. It SHALL show only on and off values, enum choices and availability received from the main window, and SHALL change anything the main window owns by a command the main window carries out.

#### Scenario: Main-owned setting

- **WHEN** the user turns Spotlight search off in the Settings window
- **THEN** the main window changes the setting and the Settings window shows the answered value

#### Scenario: Lost answer

- **WHEN** the main window does not answer a command
- **THEN** the Settings window shows the previous value and one generic line, and sends the command again only when the user acts again

#### Scenario: No session

- **WHEN** the app has no signed-in session
- **THEN** the rows that need the main window's session are disabled with a line that says why, and Appearance, Dictation and Voice calls still work

### Requirement: App Lock covers Settings

The Settings window SHALL close when App Lock covers the app and SHALL NOT open while the app is covered.

#### Scenario: Lock while open

- **WHEN** App Lock covers the app while the Settings window is open
- **THEN** the Settings window closes and does not reopen on unlock

#### Scenario: Command while locked

- **WHEN** the app is covered and the user presses ⌘,
- **THEN** no Settings window opens

### Requirement: Connection end closes Settings

The Settings window SHALL close when the connection ends by sign-out, server change or session expiry.

#### Scenario: Change server

- **WHEN** the user chooses Change Server in the Settings window
- **THEN** the main window changes the server and the Settings window closes

### Requirement: Preference changes reach the main window

A preference the Settings window writes (theme mode, dictation engine, portable calls) SHALL take effect in the main window without a restart.

#### Scenario: Theme

- **WHEN** the user picks Dark in the Settings window
- **THEN** the main window switches to the dark theme
