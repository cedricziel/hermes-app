## Purpose

Keep pending request alerts eligible for later background checks when posting fails, while deduplicating notification attempts accepted by the operating system.

## ADDED Requirements

### Requirement: Acceptance-aware request announcement

A background request notification SHALL mark its request or generic wait announced only after the OS notification API accepts the posting attempt. A failed or unavailable attempt SHALL remain unannounced. An accepted attempt SHALL NOT be described as proof of user-visible delivery. Existing foreground suppression, permissions, App Lock content rules, notification categories, and generic-wait versus approval deduplication SHALL remain in effect. An accepted per-chat notification SHALL mark only requests represented by that notification, not requests for chats whose attempts failed.

#### Scenario: OS posting failure

- **WHEN** a pending approval notification cannot be accepted by the OS
- **THEN** its request remains eligible for the next background check

#### Scenario: Partial batch failure

- **WHEN** one chat's notification is accepted and another chat's notification fails
- **THEN** only the accepted chat's represented requests are marked announced

#### Scenario: Generic wait followed by approval

- **WHEN** the OS accepted a generic notification for a wait and a later check resolves that wait to an approval
- **THEN** the same wait does not produce another notification merely because more detail became available

### Requirement: Retry replacement and live request verification

A check interrupted after OS acceptance but before announcement persistence SHALL retry with the same per-chat notification identity, replacing an existing notification instead of adding a second one. Each later check SHALL read current pending state before retrying. It SHALL NOT post alerts for requests already resolved. A posting failure SHALL NOT stop snapshot refresh or unrelated background checks. If announcement persistence fails after an accepted post, the request SHALL remain eligible for a later live check, and the app SHALL continue attempting alerts for other chats. In-memory deduplication SHALL NOT treat failed persistence as a committed mark.

#### Scenario: Interrupted after post

- **WHEN** the task stops after posting but before saving its mark
- **THEN** the next live check replaces the same chat notification if the request remains pending

#### Scenario: Mark write fails for one chat

- **WHEN** an accepted notification's announcement mark cannot be saved
- **THEN** other chats still receive posting attempts and the unmarked request remains eligible for replacement on a later live check

#### Scenario: Resolved before retry

- **WHEN** the failed notification's request has since been answered
- **THEN** the next check posts no retry for that request

### Requirement: Existing backend compatibility

The feature SHALL use the existing gateway `session.active_list` session identity and status data and `approval.pending` pending-request data over `/api/ws`. It SHALL add no RPC field, REST route, or minimum version beyond the app's existing supported contract. The reference contract is bundled Hermes revision `167e9fdb84248cd0fff80762dc57b6a914b6e930`, not a newly required minimum release. A refused pending-approval read SHALL retain the current generic-wait behavior and existing error handling.

#### Scenario: Pending approval read refused

- **WHEN** the gateway reports a waiting session but refuses its pending-approval read
- **THEN** the app follows its existing generic-wait behavior without marking a failed notification accepted
