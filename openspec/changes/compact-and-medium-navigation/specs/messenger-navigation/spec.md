## MODIFIED Requirements

### Requirement: Chats is the compact home

On compact iOS and Android layouts, the signed-in app SHALL initially present a full-page Chats list unless an explicit launch action targets another screen. The list SHALL provide search and New message. The other shell destinations SHALL be reached through the destination bar, which is shown on the list and hidden while a conversation is open. Existing profile scope, ordering, paging, housekeeping, loading, empty, and retry behavior SHALL remain available. Opening the list SHALL NOT send a message or mark an unseen conversation as read.

#### Scenario: Ordinary launch

- **WHEN** the user opens the signed-in app without an explicit target on a compact phone layout
- **THEN** Chats is visible with the current profile's conversations and no conversation detail covering the list

#### Scenario: Empty or failed list

- **WHEN** the profile has no conversations or its list cannot load
- **THEN** Chats shows the existing empty or error/retry state and retains New message and the destination bar

#### Scenario: Reach another destination

- **WHEN** the user taps Kanban, Schedules, Bots or More in the destination bar from Chats
- **THEN** that destination is shown under existing capability gates, and tapping Chats returns to the list with its search and scroll position kept
