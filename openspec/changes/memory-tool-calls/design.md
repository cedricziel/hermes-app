# Design

## Context

Facts about Hermes this design relies on, verified at Hermes `71d34bad`:

- `tool.complete` for the `memory` tool carries the full `args` `{action: add | replace | patch | remove, target: memory | user, content?, old_text?, operations?}` and a parsed `result`. Newer Hermes renames `replace` to `patch`; both are accepted.
- Result shapes:
  - saved: `{success: true, target, usage: "56% — 1,234/2,200 chars", entry_count, message}`;
  - staged: `{success: true, staged: true, pending_id, message}` (the proposed text is in `args`);
  - full: `{success: false, error: "Memory at X/Y chars; …", current_entries: [...], usage: "X/Y"}`, a soft warning: nothing is saved and the agent usually retries after making room;
  - anything else with `success: false` is an error.
- With `memory.write_approval` on, every foreground memory write in an app or gateway session is staged, never asked inline. With it off, background-review replace and remove are staged; adds write directly.
- `tool.complete` for a successful call is emitted only while the profile's tool progress display is not off.
- Decisions go through gateway slash commands: `/memory approve <id>` answers "Approved N memory write(s)." optionally followed by "Failed:" and lines " <id>: <error>" (for example when the entry it pins changed since it was staged); `/memory reject <id>` answers "Rejected pending memory write '<id>'.". Ids are 8 hex characters.
- `review.summary` text never mentions staged writes.

The app matches tool events into `ToolCall`s (args, result data, status) and renders per-tool bodies in `toolCallBody` (`tool_call_bodies.dart`), a pure function of the call. `ChatTransport.runSlashCommand({threadId, profile, command})` runs a command on a thread and returns its plain-text `output`. The review summary row is `ReviewSummaryNote`.

Platforms: iOS, iPadOS, Android, macOS, Windows, Linux. No native, entitlement, manifest or Xcode project change.

## Goals / Non-Goals

**Goals:**

- The user sees at a glance whether a memory write was saved, waits for them, or did not fit, and can decide a staged write where it appears.

**Non-Goals:**

- The inbox, skill writes, calls Hermes does not report.

## Decisions

**Parse the result into four outcomes.** `MemoryToolOutcome.of(call)` returns `saved`, `staged`, `full` or null (generic body), from `result`: `staged == true` with a string `pending_id` matching `^[0-9a-f]{8}$` → staged; `success == true` → saved; `success == false` with `error` starting "Memory at " and a `usage` of the form "X/Y" → full; anything else → null, so the existing generic card and its failed status apply. `target` comes from `args.target` (`user` → About you, `memory` → Agent notes). The saved percentage is the leading integer of `usage` ("56% — …"); when it cannot be read the line drops the percentage.

**Text as + and − lines.** For add: `+ <content>`. For replace/patch: `− <old_text>` then `+ <content>`. For remove: `− <old_text>`. For `operations` (a list of the same shapes), one block per operation. The text is inert, selectable, and capped by `ToolBodyFrame`'s height.

**Status of a full call.** The tool card's status for a `full` outcome is the new `ToolCallStatus.warning` (a warning icon), not failed (`toolResultStatus(result, name: 'memory')`, used for live events and history alike), so the chat spec's failed rule gets an exception for this case. The body text: "<Tab> are at X of Y characters, so this entry did not fit. Nothing was saved; Hermes usually makes room and tries again." with X and Y from `usage`.

**Actions without making the body stateful in the chat model.** `toolCallBody` stays a pure function of the call; the staged body reads a `MemoryDecisions` object from the widget tree (provided by `chat_thread_bindings.dart` for the chat screen, conversation windows and the quick panel) holding `decide(threadId, profile, pendingId, approve)` and a per-id state (`idle`, `running`, `saved`, `rejected`, `failed(text)`). Without a provider (catalog, tests) the buttons are hidden. The state lives in memory for the open thread and is dropped with it; after the history is read again a staged card shows its actions again, and deciding it twice returns Hermes' own answer, which is shown.

**Running the command.** `MemoryDecisions.decide` calls `runSlashCommand(threadId: <chat's stored thread id>, profile: <chat's profile>, command: '/memory approve <id>')` (or reject). It is disabled while the chat has no stored thread id. One decision per id at a time. The output is parsed:

- approve: "Approved N memory write(s)." with N ≥ 1 and no "Failed:" line for this id → saved; a "Failed:" line for this id → failed with the text after "<id>: "; anything else → failed with the whole output;
- reject: starts with "Rejected pending memory write" → rejected; anything else → failed with the output.

A transport error shows "Couldn't reach Hermes. Try again." and keeps the buttons. The parser lives in `lib/src/memory/memory_decisions.dart` so `memory-proposals` reuses it.

**Review note link.** The review notes no longer render under the reply: `MemoryActivityCard` shows them in the Activity panel. It takes an optional `onOpenMemory`; when set, its review section ends with a "Memory" link button. `BoundActivityPanel` sets it to open `MemoryDestination(profile: <chat's profile>)` when the profile is known and the chat has a repository; `MemoryDestination` gets an optional `profile`.

**Widgets.** `MemoryToolBody` (outcome, decision state, callback) and the link variant of `MemoryActivityCard`, catalogued first in `widgetbook/memory_tool_use_cases.dart`.

**Invariants touched.** API layering: no REST call; the commands go over the existing gateway socket through `ChatTransport`. Privacy: nothing new is stored; texts stay in the chat's memory. Telemetry: no text or id.

**Observability.**

- Span `memory.proposals.decide` around `runSlashCommand`, from `MemoryDecisions`, with `choice` (`approve` | `reject`), `surface: tool_card`, `outcome` (`saved` | `rejected` | `failed` | `unreachable`) and the connection's `hermes.*` attributes.
- Log `memory.proposal_decided` (`choice`, `outcome`, `surface`) after each decision.
- Breadcrumb `memory.tool_card.decide` (`choice`) when a button is pressed.

None holds memory text, the proposal id, the thread id or the profile name.

## Risks / Trade-offs

- [Tool progress is off] → no card, so no buttons; the inbox in `memory-proposals` is the dependable path, and this change says so in its non-goals.
- [The output wording changes] → unknown output is shown as Hermes wrote it and counted as failed; the user can still check the inbox. Parsing is pinned by fixtures from the source.
- [The chat's thread id is the stored session id while Hermes may have compressed the session] → `runSlashCommand` resumes the same way a send does. The design assumes the pending store belongs to the profile, not the session (the inbox lists it from a fresh session); the verify task checks that a proposal staged in one chat is approved from it after a resume.

## Migration Plan

None.
