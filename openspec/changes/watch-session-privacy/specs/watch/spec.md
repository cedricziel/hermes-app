## ADDED Requirements

### Requirement: Watch session invalidation clears private state

The phone SHALL check current session availability before serving every relay operation, including remembered send replies. With no usable session it SHALL return `signed_out`, or `unavailable` while restoration is still pending, without returning private content. On confirmed sign-out or expiry it SHALL invalidate remembered sends and send a content-free invalidation to the watch. The watch SHALL process invalidation received through either application context or user info, and `signed_out` received through any operation, as the same cleanup event. Cleanup SHALL remove visible chats, messages, drafts, retry payloads, audio, handoff targets, persisted chat caches, and private status. Cleanup SHALL invalidate asynchronous work before deleting data so late replies cannot restore content or send a transcription. Session-state publications SHALL carry a durable monotonically increasing revision. The watch SHALL persist the last accepted revision, apply each revision once, and ignore older or equal publications. A usable session re-established after sign-out SHALL publish a newer revision before content replies. Cleanup SHALL persist a tombstone before disk deletion and refuse cache reads until deletion succeeds. Transient disconnection, pending restoration, and recoverable refresh failures SHALL NOT count as confirmed sign-out.

#### Scenario: Remembered reply after logout

- **WHEN** the watch retries a previously completed send after the phone signs out
- **THEN** the phone returns `signed_out` without the remembered reply
- **AND** the watch clears private state and shows sign-in guidance without retry

#### Scenario: Open cached conversation receives sign-out

- **WHEN** a conversation displays saved messages and its refresh returns `signed_out`
- **THEN** all private state disappears from memory and persistent cache
- **AND** the conversation displays only sign-in guidance

#### Scenario: Sign-out during transcription

- **WHEN** the watch learns of sign-out while recording or transcription is active
- **THEN** the watch stops recording, removes temporary audio, and discards any later transcription result
- **AND** no send occurs from that transcription

#### Scenario: Delayed reply after cleanup

- **WHEN** a request begun before invalidation completes after cleanup
- **THEN** neither the phone nor the watch returns, displays, or caches its private result

#### Scenario: Phone unreachable at logout

- **WHEN** the phone signs out while the watch cannot receive the invalidation
- **THEN** the phone retains the latest invalidation for eventual WatchConnectivity delivery
- **AND** the watch clears data when invalidation or `signed_out` arrives
- **AND** immediate remote erasure is not promised

#### Scenario: Foreground after queued invalidation

- **WHEN** the watch reopens with a queued session invalidation
- **THEN** it applies that invalidation before showing saved content
- **AND** it checks the phone session when reachable

### Requirement: Session cleanup preserves the existing backend contract

Session cleanup SHALL add no Hermes Agent route, RPC method, or required response field. It SHALL use the existing phone authentication state and watch property-list relay. The minimum supported Hermes version SHALL remain unchanged from the application's existing baseline. Cleanup diagnostics SHALL contain only fixed operation and reason names, flags, counts, and result codes, never content, identifiers, addresses, or credentials.

#### Scenario: Existing supported server

- **WHEN** the phone connects to a server supported before this change
- **THEN** session cleanup requires no backend update

#### Scenario: Previous logout arrives after sign-in

- **WHEN** the watch has accepted a newer usable-session revision and an earlier logout publication arrives
- **THEN** it ignores the earlier publication and keeps current-session data
