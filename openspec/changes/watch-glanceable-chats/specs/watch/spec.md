## ADDED Requirements

### Requirement: Profile and known chat status

The watch SHALL name the active profile used for New Chat when supplied by the phone. Each row SHALL show a compact Running, Approval, or Question state only when supported by current evidence for that exact thread. Missing or failed status data SHALL be Unknown rather than Idle. Cached status SHALL be distinguished from freshly fetched status. After the mandatory context-identity handshake succeeds, optional older metadata payloads SHALL remain readable without those fields. Incompatible identity protocol peers SHALL require an update under watch-context-identity.

#### Scenario: Pending approval

- **WHEN** current phone metadata identifies an approval for a listed thread
- **THEN** that row shows Approval

#### Scenario: Status unavailable

- **WHEN** a status source fails during thread refresh
- **THEN** the chat remains readable and status is not claimed to be idle

#### Scenario: Profile context

- **WHEN** the active profile is work
- **THEN** the list names work as the profile used by New Chat

### Requirement: Watch-local updated markers and cache freshness

The watch SHALL mark a thread Updated on this watch when a fresh known update time exceeds the last successfully read update time for that watch and connection identity. First observation SHALL establish a baseline without claiming all chats unread. Successful fresh message loading SHALL clear the marker for the read update time; failed/cached loading SHALL not clear newer unseen updates. Saved list or messages SHALL show their last successful fetch time and an offline/unavailable explanation when refresh fails. Missing fetch time SHALL be described as unknown freshness.

#### Scenario: New update

- **WHEN** a previously read chat has a later fresh update time
- **THEN** its row is marked Updated on this watch

#### Scenario: Read fresh chat

- **WHEN** the user successfully loads that updated chat
- **THEN** the marker clears for that update

#### Scenario: Cached offline

- **WHEN** refresh fails and saved chats last fetched at 10:42 are shown
- **THEN** the watch identifies saved data and its 10:42 freshness

#### Scenario: Connection changed

- **WHEN** the account or server binding changes
- **THEN** seen markers and cache from the old identity are not applied

### Requirement: Glanceable chats accessibility

All added controls SHALL have meaningful VoiceOver labels and hints describing their action and state. Content and essential actions SHALL remain reachable at the maximum supported watch text size without shrinking essential labels below readability. Status SHALL not depend on color alone. Automatic updates SHALL preserve VoiceOver focus while the user reads or edits.

The existing icon-only new-chat control SHALL have the explicit accessible label "New chat".

#### Scenario: Start a chat with VoiceOver

- **WHEN** the user focuses the new-chat toolbar control with VoiceOver
- **THEN** VoiceOver identifies its action as New chat

#### Scenario: Maximum text size

- **WHEN** the user enables the largest supported watch text size
- **THEN** content can scroll and essential actions remain reachable

#### Scenario: VoiceOver

- **WHEN** the user navigates the new controls with VoiceOver
- **THEN** each action and state has a meaningful label and focus remains stable during updates

### Requirement: Glanceable chats backend compatibility

Watch `threads` SHALL preserve `{ok, threads: [{id,title,updatedAt,pinned,...}]}` and add optional activeProfile, fetchedAt, and per-row status. Existing chat REST reads SHALL continue through the generated client. `/api/ws` `session.active_list` rows provide live `id`, stored `session_key`, and `status`; pending kind comes from already available request metadata. Unavailable sources SHALL omit status, not synthesize idle or server unread fields. No backend unread endpoint or newer minimum version is introduced; compatibility remains the pinned OpenAPI/OpenRPC contracts.

#### Scenario: Compatible relay

- **WHEN** a supported phone serves this watch change
- **THEN** the documented existing backend methods are used and unsupported optional fields degrade safely
