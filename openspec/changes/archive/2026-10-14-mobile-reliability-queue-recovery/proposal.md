## Why

The existing chat requirement intentionally discards local queued prompts on reload, including profile switches. Users need those unsent prompts restored without sending work they have not reviewed.

## What Changes

- Persist queued prompt text and attachments before clearing the composer, using `mobile-reliability-durable-queue-store`.
- Restore local queues for their exact account, profile, and conversation, paused until the user reviews them.
- Offer explicit send and remove actions. Normal live queues retain FIFO and existing session-settle behavior.
- Show submission-started records with an unknown outcome separately from unsent records. Never retry them automatically.
- Separate locally unsent prompts from prompts Hermes already accepted, including server status `queued`.

Non-goals: automatic restored-queue draining, exactly-once backend submission, queue synchronization between devices, direct offline sends, and background sends.

Security and privacy impact: queue views remain behind App Lock. Explicit sign-out, server/account removal, and confirmed conversation deletion discard the corresponding local data. Credential expiry retains encrypted records, revokes access and visible queue DTOs, and requires the same verified owner before paused recovery. No prompts enter telemetry or system surfaces.

Observability: controller outcome event `chat.queue.recovery` records outcome and count. Breadcrumbs `chat.queue.reviewed`, `chat.queue.send_requested`, and `chat.queue.removed` record counts and fixed states. Existing send spans remain unchanged. Storage signals belong to the dependency.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `chat`: replace the memory-only queue requirement with durable, reviewed recovery and explicit uncertain-submission handling.

## Impact

`lib/src/chat/chat_controller.dart`, queued-prompt UI, profile reload and sign-out wiring, queue tests, and Widgetbook cases. Depends on `mobile-reliability-durable-queue-store`. No backend or generated-client changes. Ship transport proof boundaries and main-engine broker/persistence adapters as separate prerequisites before the controller/composer integration. Keep the ownership state machine together and record its review-size exception; use the storage adapter rather than duplicating persistence logic.
