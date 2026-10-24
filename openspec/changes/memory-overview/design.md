# Design

## Context

Facts about Hermes this design relies on, verified at Hermes `71d34bad` (the routes are also in the bundled contract, `openapi/HERMES_REF`):

- Built-in memory is two files in the profile's home: MEMORY.md (learning-graph `memorySource: memory`, limit `memory.memory_char_limit`, default 2200) and USER.md (`memorySource: profile`, limit `memory.user_char_limit`, default 1375).
- A file's entries are joined by `"\n§\n"`. Hermes counts usage as the sum of the entries' lengths plus 3 per separator: `Σ len(entry) + 3·(n−1)`, with Python's `len`, which counts code points.
- Hermes injects the files as a frozen snapshot when a session starts, so an edit reaches the agent from the next chat.
- `GET /api/learning/graph?profile=` lists memory nodes (`kind: memory`, `memorySource`) and `memory[]` cards whose `body` is cut at 1200 characters. `GET /api/learning/node` returns an entry's full `content`. The graph's timestamps come from the file's modification time and its `createdBy` is constant.
- `GET /api/config?profile=` returns the profile's config with defaults included.

The app already lists, opens, edits and deletes entries (`MemoryRepository`, `MemoryController`, `MemoryScreen`), with the scope, conflict and privacy rules of the learned-memory specs.

Platforms: iOS, iPadOS, Android, macOS, Windows, Linux. No native, entitlement, manifest or Xcode project change.

## Goals / Non-Goals

**Goals:**

- The user sees which file an entry is in, how full each file is, and that changes apply from the next chat.
- Counts match what Hermes enforces, without extra requests for short entries.

**Non-Goals:**

- Provenance per entry (none exists), adding entries, external providers.

## Decisions

**Tabs by `memorySource`.** `profile` goes to About you, `memory` to Agent notes. An entry with no or an unknown `memorySource` goes to Agent notes, which is where Hermes writes by default, so it is never hidden. The tab order is About you, then Agent notes; the screen opens on About you. Alternative: one list with section headers, which hides the per-file limit the user needs to understand.

**Entry text from the graph, full text only when needed.** The list shows each entry's text from its graph card. When a card's body is 1200 characters or longer, or no card can be matched to the node, the app reads the node's detail for the count and for the list text. The card subset (how a card names its node) is recorded from the pinned source in a fixture before code is written; if a card carries no usable link to its node, every entry's text comes from detail. A count that rests on an entry whose full text could not be read is shown as "at least N" and the bar is drawn from that lower bound.

**Counting.** Usage per tab is `Σ runes(entry) + 3·(n−1)` (0 for no entries), using code points (`String.runes.length`), not UTF-16 units, to match Python's `len`. The editor counts the draft the same way: `left = limit − (usage − runes(original) + runes(draft))`; a negative value reads "N over the limit in About you" in the warning style. The app does not block Save on it: Hermes decides, and the existing mutation rules report a refusal.

**Limits from config.** `GET /api/config?profile=<profile>` with defaults included; `memory.memory_char_limit` and `memory.user_char_limit` are read when they are positive integers. When the config cannot be read, or a limit is missing or invalid, the tab shows "912 characters · 4 entries" with no bar and no warning, rather than assuming a default that may not be the server's. Read in parallel with the graph; a failed config read does not fail the list.

**Warning threshold.** `usage ≥ 0.95 · limit` gives the warning style and the sentence "Hermes has to shorten or remove entries before it can add one".

**Editor header.** "Entry K of N in About you (USER.md)", K from the entry's position in the graph's order within its tab, never from parsing its id (the inspection spec keeps ids opaque). Below the field: "N left in About you" and "Used from the next chat".

**Empty state.** "Nothing remembered yet", with "Tell Hermes in a chat to remember something, and it shows up here." The existing unavailable and failure states are kept and never shown as empty.

**Widgets.** `MemoryFillBar`, `MemoryEntryList` and `MemoryEntryEditor` (plain models and callbacks) in `lib/src/memory/widgets/`, catalogued before `MemoryScreen` uses them. Tabs use `SettingsScaffold`'s tabs, so each platform draws its own bar.

**Invariants touched.** API layering: the config read uses the generated `getConfigApiConfigGet`; no spec or client change. Privacy: entry text stays in the controller's memory and is cleared on the existing scope changes; nothing is persisted. Tests run the generated client against `FakeHermesServer`.

**Observability.**

- Span `memory.fetch` with `operation: limits` around the config read, from `MemoryRepository`, with the connection's `hermes.*` attributes and `outcome`.
- Log event `memory.fetch_failed` (`operation: limits`, `category`) when it fails, from `MemoryRepository`.
- Breadcrumb `memory.tab` (`tab`: `about_you` | `agent_notes`), from `MemoryController` when the user switches tab.

None holds memory text, ids, labels or profile names.

## Risks / Trade-offs

- [The card-to-node link is not what the fixture assumes] → the fallback reads every entry's detail; one request per entry on open. Profiles hold a handful of entries, so this is accepted.
- [Hermes changes its counting] → the bar drifts from what Hermes enforces; the contract test and the fixture revision make the change visible.
- [Code points differ from Python for unusual input, such as lone surrogates] → negligible; accepted.

## Migration Plan

None. The screen keeps its route and behaviour; only its layout changes.
