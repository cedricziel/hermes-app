## Why

Two things showed up when the message queue was tried against a real backend. A queued message sent after a long reply ended up below the fold. And a reply the user stopped after its text had streamed looked like a finished answer, so "Queue paused" under it read as if nothing had happened.

## What Changes

- A stopped reply that kept streamed text shows "Stopped" in the action row under it. A stopped reply with no text still reads "Stopped.".
- The transcript follows a queued message into view when it is sent while the reader is at the bottom. The list-following fix from "keep a streaming reply in view" already does this; a test now covers the queued case.

## Impact

- Chat: `ChatMessage` gains a `stopped` flag, set in `applyReplyEvent`; the mapper carries it to the text message; `MessageActions` shows the mark.
- Widgetbook: a "Stopped" use case for `MessageActions` and a stopped thread.
- No backend change. The mark is local: a thread loaded again from the server does not know the reply was stopped.

## Non-goals

- Keeping the stopped mark across a reload. Hermes' stored messages do not say a turn was interrupted.
- Scrolling a reader who has scrolled up back down when a queued message goes out.

## Security and privacy impact

None.

## Telemetry

None.
