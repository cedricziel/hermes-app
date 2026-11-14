# Proposal

## Why

When Hermes saves something to memory during a reply, the chat shows a generic `memory` tool card with raw JSON. Three different outcomes look alike or wrong: a saved entry, a write that Hermes staged for the user's approval (with "Ask before saving" on, every write is staged and nothing tells the user), and a write refused because the file is full, which the card marks as failed although it is a soft warning that Hermes usually resolves itself. The background-review notes in the Activity panel say "Memory updated" but lead nowhere.

## What Changes

- The `memory` tool call gets its own body in the tool card, by outcome:
  - **Saved**: "Saved to memory · About you · 66% full", with the saved text.
  - **Waiting for your approval** (staged): the proposed text from the call's arguments as + and − lines, "Not saved yet.", and Approve and Reject buttons that run `/memory approve <id>` or `/memory reject <id>` on the chat's thread and then show Saved, Rejected or Hermes' failure text.
  - **Memory is full**: a warning, not a failure: "Agent notes are at X of Y characters, so this entry did not fit. Nothing was saved; Hermes usually makes room and tries again."
- A memory-full call is no longer shown as a failed tool.
- The Activity panel's background-review notes get a "Memory" link that opens the Memory screen for the chat's profile.

Non-goals:

- The proposals inbox and the waiting count (change `memory-proposals`).
- Bodies for the skill tools or for staged skill writes.
- Showing memory tool calls when Hermes does not send them: `tool.complete` for a successful call is only emitted while the profile's tool progress display is not off. The inbox covers that case.
- Changing what Hermes stages or how it retries a full file.

## Capabilities

### New Capabilities

- `memory-tool-calls`: the memory tool card's outcomes, the approve and reject actions in the chat, and their backend contract.

### Modified Capabilities

- `chat`: tool call cards treat a full memory as a warning; the Activity panel's background-review notes link to Memory.

## Impact

- Code: `lib/src/chat/widgets/tool_call_bodies.dart` (`memory` case), a new `lib/src/chat/widgets/memory_tool_body.dart`, a small result parser in `lib/src/memory/`, the decision runner (`lib/src/memory/memory_decisions.dart`, reused by `memory-proposals`), `chat_thread_bindings.dart` (actions for the body), `memory_activity_card.dart` and `bound_activity_panel.dart` (the review notes now live in the Activity panel, not under the reply), Widgetbook use cases.
- Backend: no new route. The `memory` tool's `tool.complete` frame (already received) and the gateway's `slash.exec` / `command.dispatch` through the existing `ChatTransport.runSlashCommand`.
- Security and privacy: the card shows memory text the agent already sent in the chat stream. The commands carry a proposal id and nothing else. No token or secret handling changes.
- Observability: a `memory.proposals.decide` span around each command (`choice`, `surface: tool_card`, `outcome`), because it crosses the socket; a `memory.proposal_decided` log event (`choice` approve | reject, `outcome`, `surface`) to count decisions and failures; a `memory.tool_card.decide` breadcrumb (`choice`). No memory text, proposal ids or profile names.
