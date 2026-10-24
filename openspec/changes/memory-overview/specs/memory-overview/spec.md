## ADDED Requirements

### Requirement: Memory tabs per file

The Memory screen SHALL show a profile's built-in memory in two tabs, "About you" (the entries Hermes keeps in USER.md, `memorySource: profile`) and "Agent notes" (MEMORY.md, `memorySource: memory`), in that order, with About you selected when the screen opens. An entry whose `memorySource` is absent or unknown SHALL be listed under Agent notes. Each entry SHALL be listed by its text only: the screen SHALL NOT show a date, an author or a source chat for an entry, because Hermes keeps none.

#### Scenario: Entries split by file

- **WHEN** the graph lists two `profile` entries and three `memory` entries
- **THEN** About you lists two entries and Agent notes lists three

#### Scenario: Entry without a source

- **WHEN** a memory node has no `memorySource`
- **THEN** it is listed under Agent notes

#### Scenario: No provenance

- **WHEN** an entry is listed or opened
- **THEN** no time, author or chat is shown for it, although the graph carries timestamps

### Requirement: Fill level per file

Each tab SHALL head its list with the file's usage: "<used> of <limit> characters" with the numbers grouped by thousands, the number of entries, and a bar filled to `used / limit`. Usage SHALL be computed in the app as the sum of the entries' lengths in Unicode code points plus 3 for each separator between two entries (0 for a file with no entries), which is how Hermes counts. The limit SHALL be `memory.user_char_limit` for About you and `memory.memory_char_limit` for Agent notes from the profile's config. At 95% of the limit or more the bar SHALL take the warning style and say "Hermes has to shorten or remove entries before it can add one". When the limit is unknown the tab SHALL show "<used> characters" and the entry count with no bar and no warning. When an entry's full text could not be read, the usage SHALL be shown as "at least <used>".

#### Scenario: Normal usage

- **WHEN** USER.md holds entries of 300, 300 and 306 characters and the limit is 1375
- **THEN** About you shows "912 of 1,375 characters" and "3 entries", without the warning

#### Scenario: Nearly full

- **WHEN** Agent notes uses 2,100 of 2,200 characters
- **THEN** the bar is in the warning style and says "Hermes has to shorten or remove entries before it can add one"

#### Scenario: Characters beyond the Basic Multilingual Plane

- **WHEN** an entry is a single emoji
- **THEN** it counts as one character

#### Scenario: Config cannot be read

- **WHEN** the config request fails
- **THEN** the entries are listed, the tab shows "<used> characters" and the entry count, and no bar or warning appears

### Requirement: Entry editor shows its place and budget

When an entry is open, the editor SHALL say "Entry <K> of <N> in <tab> (<file>)", where K is the entry's position within its tab in the order the graph lists them and the file is USER.md or MEMORY.md. While the user edits, it SHALL show "<N> left in <tab>", computed as the limit minus the tab's usage with the draft in place of the original entry, and "<N> over the limit in <tab>" in the warning style when that is negative; it SHALL not show either when the limit is unknown. The editor SHALL say "Used from the next chat". Saving and deleting SHALL keep the rules of the learned-memory-mutations spec; the app SHALL NOT refuse a save because of the count.

#### Scenario: Editing an entry

- **WHEN** the user opens the second of four About you entries with 1,375 as the limit and 912 characters used, and adds 10 characters
- **THEN** the editor shows "Entry 2 of 4 in About you (USER.md)", "453 left in About you" and "Used from the next chat"

#### Scenario: Draft over the limit

- **WHEN** the draft makes the tab's usage exceed its limit
- **THEN** the editor shows how many characters are over in the warning style and Save stays available

### Requirement: Nothing remembered yet

A tab with no entries SHALL say "Nothing remembered yet" and that the user can tell Hermes in a chat to remember something. An unavailable route, a failed read or a malformed response SHALL keep their own states and SHALL NOT be shown as empty.

#### Scenario: Empty file

- **WHEN** the graph lists no `profile` entries
- **THEN** About you says "Nothing remembered yet" with the hint, and its bar shows 0 characters

### Requirement: Memory overview backend contract

The overview SHALL rely on `GET /api/learning/graph?profile=` (memory nodes and the `memory` cards, whose `body` is cut at 1200 characters), `GET /api/learning/node?id=&profile=` for an entry whose card body is 1200 characters or longer or cannot be matched to its node, and `GET /api/config?profile=` with defaults included for `memory.memory_char_limit` and `memory.user_char_limit` (positive integers; defaults 2200 and 1375 on the server). These shapes were verified at Hermes `71d34bad`; earliest release support is unverified. A failing config read SHALL NOT fail the list.

#### Scenario: Long entry

- **WHEN** a card's body is exactly 1200 characters
- **THEN** the app reads that entry's detail and counts its full content

### Requirement: Memory overview telemetry

The config read SHALL be traced as a `memory.fetch` span with `operation: limits`, and a failed read SHALL log `memory.fetch_failed` with that operation and its failure category. Switching tab SHALL add a `memory.tab` breadcrumb carrying only `tab` (`about_you` or `agent_notes`). None of them SHALL carry memory text, ids, labels or profile names.

#### Scenario: Tab switch

- **WHEN** the user selects Agent notes
- **THEN** a `memory.tab` breadcrumb with `tab: agent_notes` is recorded and nothing else about the entries
