## Why

Local queued prompts currently live in `ChatController._queues` and disappear when threads reload. Recovery needs durable storage that protects prompt text and attachment bytes without involving the backend.

## What Changes

- Add an account-, server-, profile-, and session-scoped local queue store with atomic writes and stable entry IDs.
- Store prompt payloads and app-owned attachment copies under authenticated encryption, with the key in OS secure storage.
- Distinguish queued, submission-started, and accepted records so a crash cannot turn an uncertain submission into an automatic retry.
- Preserve valid records through unavailable storage and isolate corrupt records without dropping an entire queue.

Non-goals: controller integration, queue UI, offline direct sends, background submission, backend queue management, and push notifications. Queue recovery is a dependent change.

Security and privacy impact: prompts and attachments become durable device data. They must not enter preferences, telemetry, snapshots, Spotlight, or backups. Tokens keep their existing secure-storage boundary. Sign-out and explicit server removal clear local records and keys.

Observability: a `chat.queue.storage` span records operation, outcome, entry count, and byte count. `chat.queue.storage_failed` logs fixed operation, reason, and error type. These signals explain persistence failures without user content. No breadcrumb applies to this storage-only change.

## Capabilities

### New Capabilities

- `durable-prompt-store`: protected storage, identity boundaries, attachment retention, and crash-safe submission state.

### Modified Capabilities

None. This store does not replace the existing in-memory chat behavior until `mobile-reliability-queue-recovery` is applied.

## Impact

App-private queue records, retained attachment blobs, OS secure keys, and protected-directory channels on iOS, Android, and macOS. The adapter uses authenticated encryption and adds no route, generated client, or minimum backend version requirement. Controller and recovery UI wiring remain in the dependent change.
