## Why

A reply in the chat is text and nothing else. The user cannot copy it without selecting it, cannot ask again after a bad or failed answer without retyping the prompt, and never sees the reasoning that Hermes streams before it answers.

## What Changes

- A finished assistant reply gets an action bar below its text: **Copy** (puts the reply's text on the clipboard; the icon turns into a tick for two seconds) and **Try again** (sends the thread's last prompt again as a new turn). Try again is offered only on the latest reply of the open thread. A failed reply gets Try again but no Copy.
- The model's reasoning shows as a folded "Reasoning" block above the reply (tool calls, then text follow). It reads "Thinking…" while the reply is still being written, and opens on tap. It comes from the gateway's `reasoning.delta` and `reasoning.available` events while streaming and from a `reasoning` string on a session message row when a thread is loaded. While reasoning shows, the three thinking dots are hidden.

- The latest reply also gets three **follow-up chips** ("Explain in more detail", "Give an example", "Summarize this"). Tapping one sends it as a prompt in the open thread. They are the same for every reply and are not shown under a failed one.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `chat`: message rendering, and the streaming and loading of reasoning.

## Impact

- **Code:** `lib/src/chat/`: a `ReasoningUpdated` transport event, `ChatMessage.reasoning`, the mapper's reasoning message and streaming flag, `ReasoningBlock` and `MessageActions` and `FollowUpChips` widgets, a retry path in the chat screen.
- **API:** none new. `reasoning.delta` and `reasoning.available` arrive on the existing socket; `reasoning` is read leniently from the existing session messages route.
- **Dependencies:** none.
- **Platforms:** all but watchOS.

## Non-goals

- A true regenerate. Try again sends the last prompt as a new turn, so the thread keeps the earlier answer and the prompt appears twice. The gateway offers no call that replaces a reply in place.
- Suggestions written for each reply. The gateway sends none, and asking the model for them would cost a turn per reply, so the chips are fixed.
- A scroll-to-bottom button: `flutter_chat_ui` already shows one.
- Editing a sent prompt, feedback (thumbs) and reasoning timing ("Thought for 8s").
- Copying a user message.

## Security and privacy impact

None. Copy writes only the reply text the user is looking at to the system clipboard. Reasoning is shown in the app and never logged or sent to telemetry.

## Telemetry

None.
