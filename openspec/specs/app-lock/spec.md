# App Lock Specification

## Purpose

Describes the optional lock that asks for Face ID, Touch ID, fingerprint or the device passcode before Hermes shows its content: the setting, when the app locks and unlocks, and what happens when the device cannot confirm the person.

## Requirements

### Requirement: App lock setting

The system SHALL offer an "App lock" dialog from the account menu with one switch, off by default. Turning the switch on SHALL first ask the device to confirm the person, and SHALL leave the setting off if the device does not confirm. Turning it off SHALL need no confirmation. The choice SHALL be remembered across launches.

#### Scenario: Turn on

- **WHEN** the user turns the switch on and the device confirms them
- **THEN** app lock is on and the app stays unlocked

#### Scenario: Confirmation fails

- **WHEN** the user turns the switch on and the device does not confirm them
- **THEN** the switch stays off

### Requirement: Device without support

The system SHALL disable the switch and explain why when the device has no biometrics or passcode set up, or the platform cannot check them. A saved "on" SHALL NOT lock the app while the device cannot confirm the person, so the user is never locked out of their own app.

#### Scenario: No biometrics or passcode

- **WHEN** the user opens the App lock dialog on a device that cannot confirm the person
- **THEN** the switch is disabled and a note says to set up Face ID, Touch ID or a passcode

### Requirement: Locking and unlocking

While app lock is on, the system SHALL lock the app at launch and whenever it leaves the screen (hidden or in the background), and SHALL ask the device to confirm the person at launch and when the app returns. While locked, the system SHALL show a lock screen with an "Unlock" button that asks again, and SHALL keep the app's content out of sight, without discarding its state. Until the saved choice has loaded the app SHALL stay covered. Losing focus alone SHALL NOT lock the app.

#### Scenario: Launch

- **WHEN** the app starts with app lock on
- **THEN** the lock screen shows and the device is asked to confirm the person

#### Scenario: Returning to the app

- **WHEN** the app goes to the background and comes back
- **THEN** it shows the lock screen until the device confirms the person

#### Scenario: Confirmation cancelled

- **WHEN** the person cancels the device prompt
- **THEN** the lock screen stays and "Unlock" asks again

### Requirement: The lock hides the interface only

App lock SHALL NOT change how tokens are stored or how the session behaves. It SHALL emit no telemetry.

#### Scenario: Session while locked

- **WHEN** the app is locked
- **THEN** the connection and the signed-in session are unchanged
