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

### Requirement: Support check that fails

When the device's support check fails without an answer (an error rather than "not supported"), the system SHALL NOT offer the switch, but SHALL keep a lock that is already on: the app stays locked and "Unlock" checks again. A platform with no implementation of the check (such as Linux) counts as a device without support. If the check still cannot tell and the device reports that it cannot confirm anyone (no passcode or biometrics set up, or no implementation), rather than that the confirmation failed or was cancelled, the lock SHALL NOT be enforced for that run, so the user is never locked out of their own app.

#### Scenario: The check fails once

- **WHEN** app lock is on, the support check fails at launch and the device then confirms the person
- **THEN** the app stays locked until that confirmation, and opens after it

#### Scenario: The check fails and nobody can be confirmed

- **WHEN** app lock is on, the support check keeps failing and the device reports that it cannot confirm anyone
- **THEN** the app unlocks without enforcing the lock

#### Scenario: The check fails while app lock is off

- **WHEN** the user opens the App lock dialog after the support check failed
- **THEN** the switch is disabled and the note is shown

### Requirement: Locking and unlocking

While app lock is on, the system SHALL lock the app at launch and whenever it leaves the screen (hidden or in the background), and SHALL ask the device to confirm the person at launch and when the app returns. While locked, the system SHALL show a lock screen with an "Unlock" button that asks again, and SHALL keep the app's content out of sight, without discarding its state. Until the saved choice has loaded the app SHALL stay covered. Losing focus alone SHALL NOT lock the app. On iOS and Android the system SHALL also cover the content as soon as the app loses focus, other than to the device prompt, so that the system's app switcher snapshot, taken after that, shows the cover. The cover is drawn by the app, so a snapshot taken before its next frame can still hold the content. The cover SHALL lift without asking when the app regains focus without having left the screen.

#### Scenario: Launch

- **WHEN** the app starts with app lock on
- **THEN** the lock screen shows and the device is asked to confirm the person

#### Scenario: Returning to the app

- **WHEN** the app goes to the background and comes back
- **THEN** it shows the lock screen until the device confirms the person

#### Scenario: App switcher

- **WHEN** app lock is on and the person opens the app switcher on a phone
- **THEN** the app covers its content as soon as it loses focus, before the system takes the preview

#### Scenario: Confirmation cancelled

- **WHEN** the person cancels the device prompt
- **THEN** the lock screen stays and "Unlock" asks again

### Requirement: The lock hides the interface only

App lock SHALL NOT change how tokens are stored or how the session behaves. It SHALL emit no telemetry.

#### Scenario: Session while locked

- **WHEN** the app is locked
- **THEN** the connection and the signed-in session are unchanged
