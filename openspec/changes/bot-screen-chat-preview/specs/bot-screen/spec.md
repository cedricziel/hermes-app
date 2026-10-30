# Spec Delta

## ADDED Requirements

### Requirement: Preview while a turn uses computer_use

From the first `computer_use` tool call of a reply until that reply ends, and while the profile's screen is running, the app SHALL show the screen's still preview with a Live badge and the control state right under the run of tool calls that holds the reply's latest `computer_use` call, outside any card: below the group header when the run is folded into a group, otherwise below that call's card. No other run SHALL show it. Of several replies pending at once, only the newest SHALL show it. When the reply completes, fails or is stopped, the preview SHALL leave the transcript. This relies on the `display.*` methods of Hermes v2026.9.24 or later.

#### Scenario: Hermes clicks through a website

- **WHEN** a reply's `computer_use` call is running and the screen is running
- **THEN** the preview appears below that call's card, with a Live badge and "Hermes is in control"

#### Scenario: Consecutive calls fold into a group

- **WHEN** the reply's latest `computer_use` call is part of a run folded behind a group header
- **THEN** the preview appears below the group header while the group stays folded

#### Scenario: A later run

- **WHEN** an earlier run held a `computer_use` call and a later run starts another
- **THEN** only the later run shows the preview

#### Scenario: The reply ends

- **WHEN** the reply completes, fails or is stopped
- **THEN** no run shows the preview and no frame is requested for it

### Requirement: Opening the screen from the preview

Tapping or clicking the transcript preview SHALL open the chat's Activity panel, showing its Bot screen card, and SHALL leave the panel open when it is already open.

#### Scenario: The user taps the preview on a phone

- **WHEN** the user taps the preview
- **THEN** the Activity sheet opens with the Bot screen card in Now

#### Scenario: The inspector is already open

- **WHEN** the user clicks the preview while the inspector is open beside the chat
- **THEN** the inspector stays open

### Requirement: Watching only what is on screen

The transcript preview SHALL ask for frames only while some part of it is on screen, under the card's refresh conditions, and SHALL NOT ask for frames while it is only built off screen.

#### Scenario: Scrolled away

- **WHEN** the user scrolls the transcript so the preview leaves the screen
- **THEN** the preview no longer asks for frames, and if nothing else on screen asks, no `display.thumbnail` request is sent
