## Decisions

**The gateway ends the turn; the app does not.** After `session.interrupt` the gateway finishes the turn and emits `message.complete` with status `interrupted` (`tui_gateway/prompt_turn.py`), so the existing stream ends the reply. The app only maps that status to a new `stopped` flag on the completion event; it does not cancel the stream itself. If the gateway never answered the interrupt, the reply would stay open exactly as it does today.

**A stopped reply is complete, not failed.** It keeps what streamed and its tool calls settle as completed. With no text at all it reads "Stopped." instead of showing an empty bubble.

**The transport finds the runtime session by thread.** `stopReply(threadId)` looks up the runtime session of the reply in flight for that thread, which the transport already holds while a reply streams, and asks the gateway to interrupt it. A thread with no reply in flight, or a closed connection, sends nothing and reports not stopped. A `not_interrupted` result also reports not stopped: the turn had already ended.

**The bar sits in the composer's top slot,** next to the attachment chips, so the composer widget itself is unchanged and the bar is only built while a reply is in flight.

**No notification.** The user just asked for the stop; announcing it would be noise. This applies whether or not the app is focused on the thread.

## Platforms and invariants

All platforms; Dart only. No auth, storage, API-layering or telemetry invariant is touched.

## Risks

The interrupt call and the `interrupted` status come from the Hermes source, not from a run against a live gateway that stops a real turn (that needs a model call).
