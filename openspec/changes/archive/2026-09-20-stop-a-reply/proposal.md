## Why

Once a reply is running the user can only wait. A reply that goes the wrong way, or one that stalls, keeps the thread blocked ("Hermes is still replying") until it ends on its own. A stalled connection that stays open can hold a thread indefinitely.

## What Changes

- While a reply is in flight in the open thread, a bar above the composer shows "Hermes is replying…" with a **Stop** button. It disappears when the reply ends.
- Tapping Stop asks the gateway to interrupt the running turn (`session.interrupt`). The gateway ends the turn with a `message.complete` whose status is `interrupted`; the reply keeps whatever had streamed, or reads "Stopped." when nothing had.
- Sending works again once the reply has ended, as after any other reply.
- A reply the user stopped is not announced by a notification.
- A stop that cannot be sent shows "Could not stop the reply. Try again." and Stop stays available.

Non-goals: no stop for a reply that another client started, no queueing or steering of a running turn, no change to how a broken stream ends, no timeout that stops a reply on its own.

Security and privacy impact: None. Only the runtime session id of the reply's own thread is sent.

Telemetry: None added; `session.interrupt` is timed by the existing per-request spans.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `chat`: a new requirement for stopping a reply, and the backend contract (the interrupt call and the `interrupted` status).
- `notifications`: notifiable events (a stopped reply is not announced).

## Impact

The chat transport interface, the gateway transport, the composer, the chat screen, the reply model and the attention policy, with tests. No native, route or generated-client change. All platforms.
