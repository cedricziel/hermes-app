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
