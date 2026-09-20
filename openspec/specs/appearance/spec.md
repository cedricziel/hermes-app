# Appearance Specification

## Purpose

Describes the light and dark appearance choice: the setting, where the user changes it, how it is persisted, and how the app follows it.

## Requirements

### Requirement: Theme mode choice

The system SHALL let the user choose between "Follow system", "Light" and "Dark" from an "Appearance" dialog opened from the account menu. The dialog SHALL show the current choice selected, and picking another option SHALL apply it at once to the whole app. Until the user makes a choice the mode SHALL be "Follow system".

#### Scenario: Default mode

- **WHEN** the user opens the Appearance dialog on a fresh install
- **THEN** "Follow system" is selected

#### Scenario: Switch to dark

- **WHEN** the user picks "Dark" in the dialog
- **THEN** the app switches to its dark theme immediately

### Requirement: Theme mode is remembered

The system SHALL persist the chosen mode across launches, including a return to "Follow system". A saved value that is not one of the known modes SHALL be treated as "Follow system". A choice made while the saved value is still loading SHALL win over the loaded value, and quick successive choices SHALL leave the last one saved.

#### Scenario: Relaunch

- **WHEN** the user chose "Dark" and restarts the app
- **THEN** the app starts in dark mode

#### Scenario: Unknown saved value

- **WHEN** the stored mode is not a known value
- **THEN** the app follows the system

#### Scenario: Choice made while loading

- **WHEN** the user picks "Light" before the saved "Dark" has finished loading
- **THEN** the mode stays "Light" and "Light" is what is saved

### Requirement: The app follows the chosen mode

The system SHALL apply the chosen mode to the app's light and dark themes, and SHALL notify listeners only when the mode actually changes.

#### Scenario: Controller drives the app

- **WHEN** the mode changes to dark
- **THEN** the app's theme mode becomes dark
