## ADDED Requirements

### Requirement: Memory tool card outcomes

An opened tool card for the `memory` tool SHALL show one of three bodies, chosen from the call's result:

- **Saved** (`success: true`, not staged): "Saved to memory · <tab> · <P>% full", where the tab is About you for `target: user` and Agent notes for `target: memory` and P is the leading percentage of `usage`; without a readable percentage the line ends after the tab. Below it the saved text.
- **Waiting for your approval** (`staged: true` with a `pending_id`): the proposed change as lines prefixed "+" (new text) and "−" (replaced or removed text) from the call's arguments, one block per operation, and "Not saved yet."
- **Memory is full** (`success: false`, an `error` starting "Memory at " and a `usage` of the form "X/Y"): "<tab> are at X of Y characters, so this entry did not fit. Nothing was saved; Hermes usually makes room and tries again."

A result of any other shape SHALL get the generic tool body. Both `replace` and `patch` SHALL be read as replacing an entry. Memory text SHALL be shown as inert, selectable text.

#### Scenario: Saved

- **WHEN** the memory tool completes with `{success: true, target: "user", usage: "66% — 912/1,375 chars"}`
- **THEN** the card reads "Saved to memory · About you · 66% full" with the saved text

#### Scenario: Staged replace

- **WHEN** the call's arguments are `{action: "patch", target: "memory", old_text: "Uses tabs", content: "Uses spaces"}` and the result is `{success: true, staged: true, pending_id: "1a2b3c4d"}`
- **THEN** the card shows "− Uses tabs", "+ Uses spaces", "Not saved yet." and the Approve and Reject buttons

#### Scenario: Full

- **WHEN** the result is `{success: false, error: "Memory at 2,180/2,200 chars; …", usage: "2,180/2,200"}` for `target: memory`
- **THEN** the card reads "Agent notes are at 2,180 of 2,200 characters, so this entry did not fit. Nothing was saved; Hermes usually makes room and tries again."

#### Scenario: Other failure

- **WHEN** the result is `{success: false, error: "No entry matched"}`
- **THEN** the card shows the generic body and the failed status

### Requirement: Deciding a staged write in the chat

A staged memory card SHALL offer Approve and Reject while the chat has a stored thread. Approve SHALL run `/memory approve <pending_id>` and Reject `/memory reject <pending_id>` on the chat's thread and profile, one decision per proposal at a time, the buttons disabled while it runs. The answer SHALL be read as follows: an approve answer starting "Approved " with no "Failed:" line naming the id is Saved; a "Failed:" line naming the id is a failure showing the text after "<id>: "; a reject answer starting "Rejected pending memory write" is Rejected; any other answer is a failure showing Hermes' text. After Saved or Rejected the card SHALL show that state instead of the buttons. A failure SHALL keep the buttons. When Hermes cannot be reached the card SHALL say "Couldn't reach Hermes. Try again." The decision SHALL be held in memory for the open chat only.

#### Scenario: Approved

- **WHEN** the user taps Approve and Hermes answers "Approved 1 memory write(s)."
- **THEN** the command sent was `/memory approve 1a2b3c4d` on the chat's thread and the card shows Saved

#### Scenario: Entry changed since staging

- **WHEN** Hermes answers "Approved 0 memory write(s).", then "Failed:" and "1a2b3c4d: <reason>" because the entry changed after the write was staged
- **THEN** the card shows "<reason>" and keeps Approve and Reject

#### Scenario: Rejected

- **WHEN** the user taps Reject and Hermes answers "Rejected pending memory write '1a2b3c4d'."
- **THEN** the card shows Rejected

#### Scenario: Chat without a stored thread

- **WHEN** the chat has no stored thread id yet
- **THEN** the buttons are not offered

### Requirement: Memory tool calls backend contract

The cards SHALL rely on the `memory` tool's `tool.complete` frame carrying `args` (`action` of `add`, `replace`, `patch` or `remove`; `target` of `memory` or `user`; optional `content`, `old_text`, `operations`) and a parsed `result` as described above, and on the gateway slash commands `/memory approve <id>` and `/memory reject <id>` run through `slash.exec` / `command.dispatch` on an existing session. Proposal ids are 8 hexadecimal characters. Hermes emits `tool.complete` for a successful call only while the profile's tool progress display is not off; with it off no card appears. These shapes were verified at Hermes `71d34bad`; earliest release support is unverified.

#### Scenario: Tool progress off

- **WHEN** the profile's tool progress display is off and Hermes saves a memory
- **THEN** no memory card appears and nothing else changes in the reply

### Requirement: Memory tool calls telemetry

Each decision SHALL be traced as a `memory.proposals.decide` span with `choice` (`approve` or `reject`), `surface: tool_card` and `outcome` (`saved`, `rejected`, `failed` or `unreachable`), SHALL log `memory.proposal_decided` with the same `choice`, `outcome` and `surface`, and a button press SHALL add a `memory.tool_card.decide` breadcrumb carrying only `choice`. None SHALL carry memory text, proposal ids, thread ids or profile names.

#### Scenario: Approve logged

- **WHEN** an approve from the card succeeds
- **THEN** `memory.proposal_decided` is logged with `choice: approve`, `outcome: saved` and `surface: tool_card`, and no id
