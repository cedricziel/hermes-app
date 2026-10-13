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
