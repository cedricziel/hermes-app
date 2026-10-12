## ADDED Requirements

### Requirement: Shared macOS modals use restrained desktop presentation

Shared confirmation dialogs, command-server execution reviews, and optional platform-hint prompts SHALL use desktop dialog presentation on macOS, including compact windows. Dialog content SHALL use a stationary 150 ms fade without slide or scale motion and SHALL appear immediately under reduced motion. Caller themes, confirmation results, and busy dismissal guards SHALL remain intact. Existing non-macOS presentation choices SHALL remain unchanged.

These presentation changes SHALL require no backend route, RPC method, response shape, or minimum Hermes Agent version change. Existing confirmation callbacks SHALL retain their backend contracts.

#### Scenario: Compact Mac window
- **WHEN** a command-server review or platform-hint prompt opens in a compact Mac window
- **THEN** it appears as a desktop dialog rather than a mobile bottom sheet

#### Scenario: Dialog motion
- **WHEN** a shared Mac modal opens or closes
- **THEN** its content remains stationary and changes opacity over 150 ms

#### Scenario: Reduced motion
- **WHEN** reduced motion is enabled
- **THEN** shared Mac dialog content appears immediately without slide or scale motion

#### Scenario: Confirmation cancellation
- **WHEN** a cancellable shared Mac confirmation receives Escape or barrier dismissal
- **THEN** it returns false without invoking the confirmed operation

#### Scenario: Busy prompt
- **WHEN** a shared Mac prompt refuses dismissal while saving
- **THEN** Escape, Back, and barrier interaction leave it open

### Requirement: Common macOS alert actions support keyboard navigation

Enabled common macOS alert actions SHALL be keyboard focusable and activatable with Enter or Space, with visible focus feedback. Disabled actions SHALL not activate or receive traversal focus. Focus SHALL remain within the modal, and an action from a dismissed or superseded dialog SHALL not pop an underlying route.

#### Scenario: Keyboard confirmation
- **WHEN** the user moves focus to an enabled common Mac alert action and presses Enter or Space
- **THEN** that action runs once

#### Scenario: Disabled action
- **WHEN** a common Mac alert action is disabled
- **THEN** keyboard traversal skips it and activation cannot invoke it

#### Scenario: Dismissed action
- **WHEN** a dialog starts closing before another activation arrives
- **THEN** its old action does not dismiss the underlying screen
