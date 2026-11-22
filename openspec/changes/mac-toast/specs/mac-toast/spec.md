# Spec Delta

## Purpose

Shows short results in the Mac app as a toast that looks and speaks like a Mac message, through one shared block.

## ADDED Requirements

### Requirement: Mac toast for transient messages

On macOS, a transient result message SHALL be shown as a toast in the content pane, not as a full-width bar at the window's bottom edge. Other platforms SHALL keep the floating snack bar.

#### Scenario: Result message on a Mac

- **WHEN** an action ends with a short result, such as a saved export
- **THEN** a toast appears in the content pane, away from the composer and the sidebar, and disappears by itself

#### Scenario: Other platforms

- **WHEN** the same action ends on iOS, Android, Windows or Linux
- **THEN** a floating snack bar appears as before

### Requirement: Status is never colour alone

A toast SHALL show its tone by an icon and by its words, and SHALL NOT rely on colour alone.

#### Scenario: Error and success

- **WHEN** an error toast and a success toast are shown
- **THEN** each has its own icon and its text says what happened, and they are told apart without colour

### Requirement: Announced to VoiceOver

A toast SHALL be announced once by the screen reader with its text, without taking keyboard focus.

#### Scenario: VoiceOver on

- **WHEN** a toast appears while VoiceOver is on
- **THEN** VoiceOver speaks its text once and focus stays where it was

### Requirement: Timing and control

A toast SHALL stay at least three seconds, longer for longer text and for a toast with an action, and SHALL stay while the pointer is over it or it has keyboard focus. With assistive navigation on, it SHALL stay until the user dismisses it. A click or Escape SHALL dismiss it.

#### Scenario: Pointer over the toast

- **WHEN** the pointer is over a toast when its time ends
- **THEN** it stays, and its time restarts when the pointer leaves

#### Scenario: Assistive navigation

- **WHEN** a toast appears with assistive navigation on
- **THEN** it stays until dismissed

### Requirement: One message at a time

A new toast SHALL replace the visible one, except that a neutral toast SHALL NOT replace an error toast within one second.

#### Scenario: Replacement

- **WHEN** a second result arrives while a toast is visible
- **THEN** the second replaces the first

### Requirement: App Lock and connection end clear toasts

A toast SHALL NOT be visible while App Lock covers the app, and queued toasts SHALL be dropped when the cover starts, on sign-out and on server change.

#### Scenario: Lock

- **WHEN** App Lock covers the app while a toast is visible
- **THEN** the toast is hidden and does not return on unlock

### Requirement: One call for every transient message

Code SHALL show a transient message only through the shared toast call. A new direct `showSnackBar` call SHALL fail the architecture check.

#### Scenario: New raw call

- **WHEN** a change adds a `showSnackBar` call outside the shared block
- **THEN** the architecture check fails and names the shared call
