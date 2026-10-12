## ADDED Requirements

### Requirement: Renewable session transport boundary

A renewable chat transport SHALL preserve its public identity while replacing a closed delegate. Suspension SHALL synchronously reject new protected operations, invalidate pending operation results, and cancel active stream subscriptions before closing the old delegate. Only explicit renewal SHALL create a fresh delegate. Permanent retirement SHALL prevent renewal. This boundary SHALL NOT independently authorize account recovery or undo already dispatched server effects.

#### Scenario: A request finishes after suspension
- **WHEN** a delegate request completes after its operation epoch has been suspended
- **THEN** the proxy rejects its result as suspended instead of publishing stale success or failure

#### Scenario: A stream is subscribed after suspension
- **WHEN** a stream created before suspension is first listened to afterward
- **THEN** no delegate stream is subscribed and the listener receives a suspended result

#### Scenario: Active streams are suspended
- **WHEN** suspension occurs with active reply or follow-up subscriptions
- **THEN** those subscriptions are cancelled before the old delegate closes and no later event is relayed

#### Scenario: Renewal overlaps old cleanup
- **WHEN** renewal creates a fresh delegate before old asynchronous cleanup finishes
- **THEN** old cleanup cannot clear or close the fresh delegate

#### Scenario: Permanently retired transport
- **WHEN** a retired proxy is asked to renew or perform an operation
- **THEN** it rejects the operation without creating a delegate or dispatching protected work
