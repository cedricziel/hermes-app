# Spec Delta

## Purpose

Lets a user find the app's own version and get to the project's public issue
tracker to report a bug, whether they are signed in or still trying to
connect or sign in.

## ADDED Requirements

### Requirement: About entry in the account menu

The system SHALL show an "About" entry in the account menu, alongside
Appearance, Notifications and App lock. Selecting it SHALL open an "About"
dialog.

#### Scenario: Opening About from the account menu

- **WHEN** the user opens the account menu and selects "About"
- **THEN** the system shows a dialog titled "About"

### Requirement: About dialog shows the app version

The About dialog SHALL show the app's version.

#### Scenario: Version is shown

- **WHEN** the About dialog opens
- **THEN** it shows the app's version number

### Requirement: Report a bug opens the issue tracker

The About dialog SHALL offer a "Report a bug" action. Selecting it SHALL open
`https://github.com/cedricziel/hermes-app/issues` in the system's external
browser, without collecting or sending any app or device data.

#### Scenario: Reporting a bug

- **WHEN** the user selects "Report a bug" in the About dialog
- **THEN** the system opens `https://github.com/cedricziel/hermes-app/issues`
  in the external browser

#### Scenario: The browser cannot be launched

- **WHEN** the user selects "Report a bug" and the external browser fails to
  launch
- **THEN** the system leaves the About dialog open and does not crash

### Requirement: Report a bug on the setup and sign-in screens

The server-setup screen and the sign-in screen SHALL each show a "Report a
bug" link that opens `https://github.com/cedricziel/hermes-app/issues` in the
external browser, so a user can report a problem before they can reach the
account menu.

#### Scenario: Reporting a bug while setting up the server

- **WHEN** the user is on the server-setup screen and selects "Report a bug"
- **THEN** the system opens `https://github.com/cedricziel/hermes-app/issues`
  in the external browser

#### Scenario: Reporting a bug while signing in

- **WHEN** the user is on the sign-in screen and selects "Report a bug"
- **THEN** the system opens `https://github.com/cedricziel/hermes-app/issues`
  in the external browser
