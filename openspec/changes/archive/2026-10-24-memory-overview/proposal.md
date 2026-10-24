# Proposal

## Why

The Memory screen lists every memory entry of a profile in one flat list, labelled "Memory" or "User profile". Hermes keeps built-in memory in two files with a hard character limit each, MEMORY.md (agent notes) and USER.md (what it knows about the user), and the agent has to shorten or remove entries once a file is nearly full. The user cannot see which file an entry lives in, how full each file is, or that an edit only reaches the agent from the next chat.

## What Changes

- The Memory screen gets two tabs, **About you** (USER.md, `memorySource: profile`) and **Agent notes** (MEMORY.md, `memorySource: memory`).
- Each tab heads its list with a fill bar: "912 of 1,375 characters", the entry count, and the limit from the profile's config (`memory.user_char_limit`, `memory.memory_char_limit`). At 95% or more the bar takes the warning style and says "Hermes has to shorten or remove entries before it can add one".
- The list shows each entry's text only. Hermes keeps no per-entry date, author or source chat, so none is shown.
- The editor says where the entry lives ("Entry 2 of 4 in About you (USER.md)"), counts characters as the user types ("N left in About you") and notes "Used from the next chat".
- An empty tab says "Nothing remembered yet" with a hint that the user can tell Hermes to remember something.
- Character counts are computed in the app from the entries, the way Hermes counts them.
- Editing and deleting keep their current behaviour (learned-memory-mutations).

Non-goals:

- Memory settings, the memory provider and reset (change `memory-settings`).
- New entry points to the screen (change `memory-navigation`).
- Pending memory proposals (change `memory-proposals`).
- Adding an entry from the app. Hermes has no route for it; the hint points to telling Hermes in a chat.
- Showing when or by whom an entry was written, or from which chat. The graph's timestamps are the file's modification time and its author field is constant, so they say nothing about an entry.
- External memory providers. The tabs describe the built-in files only.

## Capabilities

### New Capabilities

- `memory-overview`: the About you / Agent notes tabs, the fill bars and their limits, the editor's location and character budget, and the empty state.

### Modified Capabilities

- `learned-memory-inspection`: the profile-scoped list is shown per memory file, and the empty state names what to do.

## Impact

- Code: `lib/src/memory/` (repository: limits from config, entry texts; controller: per-tab state and counts; screen: tabs, fill bar, editor header and budget), new widgets in `lib/src/memory/widgets/`, `widgetbook/memory_use_cases.dart`.
- Backend: no new route. `GET /api/learning/graph`, `GET /api/learning/node` (already used) and `GET /api/config?profile=`, all in the generated client.
- Security and privacy: none beyond today. Entry text stays in memory only and is cleared on sign-out, connection and profile change, as the existing memory specs require. The config read returns only numbers the app keeps.
- Observability: the config read gets a `memory.fetch` span with `operation: limits` and, on failure, the existing `memory.fetch_failed` log event with that operation, so a missing bar can be explained. A `memory.tab` breadcrumb (`tab`: `about_you` or `agent_notes`) records which file the user looked at before a crash. None holds memory text, ids or profile names.
