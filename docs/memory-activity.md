# Memory activity in the inspector

“robot-notes — recalled 5 memories” means robot-notes supplied matching notes
as context for the agent. It does not identify those notes, say that five notes
were written, or mean that the same five notes were used on every turn.

The current robot-notes plugin requests at most five results, merges scoped
results under the same cap, then reports how many notes it injected. A positive
recall byte budget can reduce that count further. The number is a retrieval cap
in the plugin, not a display limit in Hermes App.

## What reaches the client

As inspected at robot-notes commit `9a5ee0c3e384e475f8e23cd1481c4ad41632bd4a`:

- `hermes-plugin/robot_notes/__init__.py`: `_recall_items` requests `limit=5`;
  `_search_and_format` selects at most five and formats titles, IDs, paths and
  snippets for the model. `prefetch` records the count actually injected.
- `hermes-plugin/robot_notes/recall.py`: `RecallCache.status` returns only
  `RecallStatus(provider_label, count)`.
- `robotnotes_health` is deliberately content-free. It is not an inspection API
  for the note identities used by an earlier turn.

Hermes' `agent/memory_provider.py` defines `RecallStatus` with provider label,
count and glyph. `MemoryManager.describe_recall()` turns that into the indicator.
`agent/turn_context.py` emits it through the lifecycle status callback. The
session gateway forwards `status.update` with `kind` and `text`. The app receives
no titles, note IDs or excerpts in that event.

Changing only the app cannot recover that missing information. A new search
would be a different observation and must not be shown as the original recall.

## Current app behavior

Recognized recall indicators are reference activity under **Activity → This
session**, on both the inspector and phone sheet. They no longer occupy the
transcript's working-status strip. Expanding explains what the count means and
that Hermes did not include note details, instead of repeating the indicator.

The app retains the latest 20 received recall events for the current runtime,
including repeated counts as separate observations. Receipt times are labeled
as such. Status clears do not erase them; runtime/profile retirement clears them.
Old recall history is not reconstructed after restarting the app.

Background review reports also appear here, using the latest report associated
with a finished reply. Their original text is retained. Reports can describe
proposals requiring approval, so the UI does not label everything as “saved”.
Actual approval/clarification requests keep their existing interactive UI.

## Required to show the actual recalled notes

This needs a coordinated plugin and Hermes host change before the app can render
real note details. The host's current count-only contract is the missing link:

1. The plugin must expose the exact sources that survived scope checks and the
   final injection budget, including cached-prefetch paths. Reporting the first
   five raw search hits would be inaccurate when some were not injected.
2. Hermes must publish a structured recall event on the owning session, correlated
   with its turn/runtime and a stable event ID. Include source IDs, titles, paths,
   revisions when available and explicitly bounded optional excerpts. Keep legacy
   status text for older clients; preserve profile and session isolation.
3. The app can then expand that event to show the supplied sources. Missing or
   redacted fields must remain visibly unavailable rather than guessed.

This PR changes the app presentation and documents that boundary. It does not
change robot-notes retrieval, the Hermes gateway protocol, or server credentials.
