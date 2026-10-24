# Verify Memory inspection

Complete the client-isolation prerequisite in [the shared guide](../SKILL.md)
before launching. Use synthetic data in a throwaway Hermes home and profiles.
The inspected backend baseline is `167e9fdb84248cd0fff80762dc57b6a914b6e930`.
Use `test/memory/memory_fixtures.dart` for response subsets and opaque IDs.

1. Seed one profile's `memories/MEMORY.md` and `memories/USER.md` through the
   pinned backend's memory-store format. Include a memory longer than the
   graph's 1,200-character preview and a synthetic URL. Give a second profile
   different content. Keep each file under its configured memory limit.
2. Open Settings, then Memory. Check the Memory and User profile source labels.
   Open the long entry and check its final text beyond the preview. Text stays
   selectable and inert; opening the entry does not launch its URL.
3. Change the Memory profile. Check that the learning graph and node requests
   use the selected profile, without changing the backend's active profile.
   Skill nodes stay out of the list. A valid graph with no memory nodes shows
   the empty state.
4. Change or remove an entry in the throwaway backend before opening its old
   list row. Check the stale-detail message and refresh action. An unsupported
   graph route reports unavailable, and a deleted profile reports its own
   failure instead of an empty list.
5. Hold a detail response, then sign out or replace the API connection. Release
   the response and check that old content stays cleared. Replace the signed-in
   owner while retaining the API object; the open route must require reopening
   Memory for the current account.
6. Enable App Lock in the isolated client. Check that the existing lock gate
   covers Memory and its controls. A submitted request can complete behind
   that gate; unlocking must not expose a previous account's content.
7. Inspect telemetry with synthetic content. `memory.fetch`,
   `memory.fetch_failed`, and `memory.open` contain only fixed operations,
   outcomes, and inherited connection attributes. IDs, labels, profile names,
   URLs, response bodies, and memory content must be absent.

Record screenshots and the outcomes actually observed. Report unsupported or
unverified native behavior separately from unit and widget test results.

## Verify memory changes after inspection lands

Use only throwaway memories. Editing and deletion are deliberately absent from
inspection; apply the dependent mutation change before these checks.

1. Open a full-content detail and choose Edit. Save changed, non-blank content.
   Check matching opaque ID and profile in the PUT body and profile query.
   A confirmed response closes stale detail and refreshes the list. Select the
   refreshed entry again; do not infer a replacement ID from its list position.
2. Enter whitespace. Save must stay unavailable. Choose Delete, then Cancel;
   no DELETE request is sent. Confirm deletion of a throwaway entry and check
   permanent-removal copy, exact scoped identity, and refreshed list contents.
3. Change the same entry in the backend before save or delete preflight. The
   app must preserve the draft, report conflict, and send no mutation. Refresh
   and another explicit selection are required before trying again.
4. Reject a write, then drop a response after a fixture write completes.
   Confirmed rejection preserves the draft. A lost response remains uncertain
   and performs read-only reconciliation. Absence of the old ID does not prove
   which actor changed it. No PUT or DELETE repeats automatically.
5. Leave a dirty editor or switch its profile while a request is pending.
   Check explicit discard confirmation and the warning that the original
   request may still finish. Sign-out clears the draft, and a late result
   cannot populate another account's view.
6. Inspect `memory.mutate`, `memory.mutation_outcome`, `memory.edit.open`, and
   `memory.delete.confirm`. Content, opaque IDs, labels, profiles, and backend
   error strings must be absent. A telemetry failure must not break the action.

## Verify waiting memory and skill changes

Stage records by hand in the throwaway home; Hermes lists whatever is in
`<HERMES_HOME>/pending/memory/` and `<HERMES_HOME>/pending/skills/`.
`test/real_backend_contract_test.dart` ("staged memory and skill writes") has
the record shapes. A record is `{id (8 hex), subsystem, action, summary,
origin (foreground | background_review), created_at, payload}`; a replace,
patch or remove needs `payload.matched_entry` to equal an entry of
`memories/MEMORY.md` or `USER.md` (entries are separated by `\n§\n`) or
approving fails with "Entry changed since it was staged".

1. Stage a chat add, a chat replace (`summary` of `replace in memory: entry
matching: X` + newline + `whole entry becomes: Y`), a background patch
   (`origin: background_review`, `summary` of `background review consolidation
(patch on memory): - patch span 'X' -> 'Y' (rest of the entry is kept)`), a
   background remove and a skill `create`. Open Memory: the card reads "N
   changes waiting for you" and opens Waiting for you with the right badges,
   targets and origins; the replaced entry is struck through.
2. In a window of 900 points or wider (macOS) and on an iPad simulator, the
   list sits beside the first proposal's detail; on a phone, a row opens a
   page. Approve one: "Saved to <target>", the list is read again and the file
   on disk changed. Reject one: the file did not. A skill shows "Show changes".
3. Change the entry a record is pinned to on disk, then approve it: Hermes'
   "Entry changed since it was staged" shows and the record stays.
4. Approve all and Reject all (asks first) decide exactly the listed ids: stage
   one more record after the list was read and check it stays pending.
5. The chat sidebar's Memory entry reads "Memory · N waiting" and the Mac
   Profiles page "N waiting"; the chat list shows no new chat after reading.

## Verify the Memory screen, settings, proposals and tool card on macOS

Run on 2026-10-24 against Hermes `d923a5eb` with the temporary client fixture
from the shared guide. Every step below was observed.

### Seed the throwaway home before `dev-backend.sh start`

- `config.yaml` with the scripted model block from "Scripted tool calls".
- `memories/USER.md` with a few short entries and `memories/MEMORY.md` with
  four entries of 525 characters (2,109 of 2,200: the Agent notes tab shows
  "Full" and its warning). Entries are joined by `"\n§\n"`; the app counts
  characters plus 3 per separator, the same number Hermes' memory tool
  reports (`"usage": "6% — 94/1,375 chars"` matched "94 of 1,375").
- A second profile without the CLI (which writes aliases to
  `~/.local/bin`): create `profiles/work/config.yaml` (any identity marker
  makes it a profile) and `profiles/work/memories/USER.md`. Leave its
  `MEMORY.md` out to see the empty state.

### What to look at

1. Profiles page: Memory sits after Skills with the entry count (7 and 1);
   opening it shows that profile in the subtitle. Settings… has no Memory row.
2. Memory screen: About you / Agent notes tabs, "N entries", "X of Y
   characters", the warning under the bar, "Nothing remembered yet" for an
   empty tab. Open an entry: "Entry 3 of 4 in Agent notes (MEMORY.md)", Edit
   shows a live count and "N left in Agent notes"; Save rewrites the file,
   Delete entry asks "Permanently delete this memory?" and removes it.
3. Learning: tap the switch itself (the row title does not toggle it on the
   Mac) and diff `config.yaml` after each change: `memory.user_profile_enabled`,
   `memory.write_approval`, `memory.nudge_interval` (Review chats) and
   `display.memory_notifications` (`verbose` for With details). The other
   profile's `config.yaml` must stay unchanged. Memory provider reads
   "Built-in · MEMORY.md and USER.md" and opens Plugins on Providers. Reset
   memory… > Reset about you deletes only that profile's `USER.md`.
4. Proposals: stage records with the shapes above (a small Python script that
   writes `<home>/pending/memory/<id8>.json` is enough; a replace or patch
   needs `matched_entry` equal to a whole current entry). Profiles shows "N
   waiting", Memory shows "N changes waiting for you". At 1,512 pt the list
   sits beside the detail. Approve shows "Saved to Agent notes" and the file
   changes; Reject shows "Rejected" and leaves it; editing the pinned entry on
   disk first gives Hermes' "Entry changed since it was staged" and keeps the
   record. Stage one more after the list was read: Approve all (no question)
   and Reject all ("Reject all changes?", "Rejected 2 changes") leave it
   pending. `state.db` gains no session from reading or deciding.
5. Tool card: copy `scripts/fake_tool_model.py` to the scratchpad and add a
   turn that calls `memory` with `{"action": "add", "target": "user",
"content": …}` and one that adds an entry too big for `MEMORY.md`. With
   `write_approval: true` the card shows "Not saved yet." with Reject and
   Approve (also after reopening the chat); off, "Saved to memory · About
   you · 6% full"; too big, the warning icon and "Agent notes are at 1,107 of
   2,200 characters, so this entry did not fit." Turning Ask before saving
   off on the Memory screen applies to the chat that is already open.

### Pitfalls

- Hermes' background review runs on the same scripted model: after a chat
  turn it can stage its own copy of the write (`origin: background_review`),
  and chat-staged records carry `origin: assistant_tool`, not `foreground`.
- The first expansion of a tool card at the bottom of a chat collapses again:
  the expand animation counts as quiet metric changes for
  `BlankListWatchdog`, which remounts the list. A second tap within its 10 s
  cooldown stays open. Seen only as that; reported, not fixed here.
- A background review note (and the Activity panel's Memory link) needs a
  `review.summary` that saved something; staged review writes send none.
- Without Accessibility and Screen Recording for the terminal, a temporary
  `lib/` file can register `ext.verify.*` service extensions (list visible
  texts with their rects, tap by text or point with synthetic mouse events,
  type into the focused field, render `renderViews.first.debugLayer` to PNG)
  and a small `websockets` client in Hermes' venv can call them. Don't drive
  frames by hand: timestamps out of step with the engine's break animations
  (`elapsedInSeconds >= 0.0`).
- `xcodebuild -resolvePackageDependencies` can hang on a keychain prompt
  while SwiftPM downloads a binary artifact (`KeychainAuthorizationProvider`
  in a `sample`). Running it once with `-packageAuthorizationProvider netrc`
  fetches the artifacts; later `flutter build` and `flutter run` then pass.
