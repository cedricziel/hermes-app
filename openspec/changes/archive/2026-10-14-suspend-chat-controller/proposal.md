## Why

Keeping a chat mounted during verified account recovery also keeps its requests, streams and timers alive. The controller needs an activity boundary before the main UI can safely retain local state behind sign-in.

## What Changes

- Suspend chat loads, commands, answers, streams, search and sidebar work synchronously when session activity ends.
- Ignore results and errors from work begun before suspension, including after a later recovery.
- Refresh server state on activity recovery while preserving a valid selected profile and thread, without sending prompts again.
- Retain every queued prompt, including queues whose remote targets fall outside the first page or cannot be restored.
- Retain interrupted external opening metadata for explicit owner recovery after dismissal and newer-intent arbitration.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `chat`: Pause protected chat activity and reconcile server state after verified recovery.

## Impact

Changes ChatController and its search/sidebar helpers plus focused tests. Existing generated REST repositories and ChatTransport methods remain the backend contract; no endpoint, RPC or minimum Hermes version changes.

Non-goals: authentication policy, transport renewal, route retention, composer widgets, voice and other route families. Security and privacy: suspended controllers issue no new protected work or notification; token storage and telemetry content are unchanged. Observability: none added because this is an internal lifecycle fence; existing outcome breadcrumbs remain active only for current work.
