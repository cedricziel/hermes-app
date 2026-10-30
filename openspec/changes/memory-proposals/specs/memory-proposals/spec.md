## ADDED Requirements

### Requirement: Waiting-for-you card

The Memory screen SHALL show, above its tabs, a card "<N> changes waiting for you · Not saved until you approve them", where N counts the profile's pending memory and skill proposals, and SHALL hide it when N is 0 or the proposals could not be read. A tap SHALL open the Waiting for you inbox for the same profile.

#### Scenario: Two proposals

- **WHEN** `/memory pending` lists one proposal and `/skills pending` one
- **THEN** the card reads "2 changes waiting for you · Not saved until you approve them"

#### Scenario: Nothing waiting

- **WHEN** both commands answer that nothing is pending
- **THEN** no card is shown

### Requirement: Waiting for you inbox

The inbox SHALL list each proposal with a badge (Replace, Add, Remove, Skill, or Change when the action cannot be read), its target (About you, Agent notes, or the skill's name), its origin ("from a chat" or, for an `[auto]` proposal, "from a background review"), the entry it replaces or removes in full and struck through, and the new text. When the new text may have been shortened by Hermes (it ends in "…" or reaches Hermes' cut length), the inbox SHALL show "Long new text is shortened in this list; approving applies all of it". Each item SHALL offer Approve and Reject; the inbox SHALL offer Approve all and Reject all, Reject all asking first. A skill item SHALL offer "Show changes", which shows the answer of `/skills diff <id>` as a diff. At the bottom the inbox SHALL show an "Ask before saving" switch for `memory.write_approval` with the subtitle "Off: Hermes saves new entries itself and only asks before a background review replaces or removes one", changed as the memory-settings spec describes.

#### Scenario: Replace from a background review

- **WHEN** `/memory pending` lists `  1a2b3c4d [auto]  background review consolidation (replace on memory): - replace: Prefers spaces` with the detail line `      replaces entry: Prefers tabs in Go`
- **THEN** the item shows Replace, Agent notes, "from a background review", "Prefers tabs in Go" struck through and "Prefers spaces"

#### Scenario: Shortened new text

- **WHEN** a chat proposal's new text is 120 characters long
- **THEN** the item shows the shortening note

#### Scenario: Skill diff

- **WHEN** the user taps "Show changes" on a skill item
- **THEN** `/skills diff <id>` runs and its unified diff is shown

### Requirement: Inbox layout

At 900 points or wider on macOS, Windows and Linux, and 700 points or wider on iPad, the inbox SHALL show the list beside the selected proposal's detail, with the first proposal selected. Narrower, the list SHALL open a proposal's detail as its own page.

#### Scenario: Wide Mac window

- **WHEN** the inbox opens in a 1000 point wide Mac window with three proposals
- **THEN** the list and the first proposal's detail are shown side by side

#### Scenario: Phone

- **WHEN** the user taps a proposal on a phone
- **THEN** its detail opens as a page with Approve and Reject

### Requirement: Deciding proposals

Approve and Reject SHALL run `/memory approve <id>` or `/memory reject <id>` (`/skills approve|reject <id>` for a skill item) for the profile, read as the memory-tool-calls spec describes. Approve all and Reject all SHALL run the per-item command for each listed id in turn and SHALL NOT send `all`, so that a proposal staged after the list was read is not decided unseen. After every decision and after every failure the list SHALL be read again. A memory approval SHALL show "Saved to <target> · Hermes uses it from the next chat" ("Saved · Hermes uses it from the next chat" without a target); a rejection "Rejected"; a failure Hermes' text for that id.

#### Scenario: Approve about you

- **WHEN** the user approves an About you proposal and Hermes answers "Approved 1 memory write(s)."
- **THEN** the inbox shows "Saved to About you · Hermes uses it from the next chat" and reads the list again

#### Scenario: Pinned entry changed

- **WHEN** an approval's answer has a "Failed:" line for the id
- **THEN** the inbox shows that line's reason and reads the list again

#### Scenario: Approve all

- **WHEN** the inbox lists two memory proposals and the user taps Approve all
- **THEN** `/memory approve <id>` runs once for each of the two ids and `/memory approve all` is not sent

### Requirement: Lenient proposal parsing

The app SHALL read the commands' plain text leniently and SHALL NOT fail on text it does not recognize. "No pending memory writes." and any answer starting "No pending" SHALL read as empty. Progress lines Hermes prints before the answer (starting "⏳") SHALL be skipped. A line of two spaces, an 8-hex-character id, an optional "[auto]" and the summary SHALL start a proposal; a line of six spaces with "<verb> entry: <text>" SHALL give a replaced or removed entry; the header, blank lines and the "Apply:" and "Review full diff:" footer lines SHALL be skipped; other lines SHALL continue the current proposal's summary. Both `replace` and `patch` SHALL read as Replace. An answer starting "Unknown command" SHALL read as the server not knowing the command. A proposal whose action or target cannot be read SHALL keep its raw summary and stay decidable by its id. An answer that yields no proposal and is not an empty answer SHALL be shown as unreadable with its raw text and a retry.

#### Scenario: Unknown line

- **WHEN** a pending answer holds a line the parser does not know before the first proposal
- **THEN** the proposals are still listed and the unknown line is counted

#### Scenario: Replace summary across two lines

- **WHEN** a chat replace summary reads "replace in memory: entry matching: tabs" followed by the line "whole entry becomes: spaces"
- **THEN** the item's new text is "spaces"

#### Scenario: Unrecognized answer

- **WHEN** `/memory pending` answers with text holding no proposal line and not starting "No pending"
- **THEN** the inbox says Hermes answered in a way the app doesn't understand, shows the text and offers a retry

### Requirement: Waiting count on Memory entries

When proposals wait in a profile, the chat sidebar's Memory entry SHALL read "Memory · <N> waiting" for the chat's profile and the Mac Profiles page's Memory row SHALL show "<N> waiting" in place of the entry count for the selected profile. The sidebar count SHALL be read when the chat loads its threads, on app resume at most every five minutes, and after a decision; the Profiles page SHALL read it when a profile is selected. A count that cannot be read SHALL show nothing.

#### Scenario: Sidebar count

- **WHEN** two proposals wait in the chat's profile
- **THEN** the sidebar entry reads "Memory · 2 waiting"

#### Scenario: Count unreadable

- **WHEN** reading the proposals fails
- **THEN** the sidebar entry reads "Memory" and the Profiles page shows the entry count

### Requirement: Session for proposal commands

The proposal commands SHALL each run in a new gateway session of the profile with no thread. Checked against a real backend (Hermes `d923a5eb`), such a command leaves no stored session, so the session list shows nothing for it. The app SHALL NOT leave a new empty chat in the list for any read or decision.

#### Scenario: Reading twice

- **WHEN** the inbox is opened twice in a profile
- **THEN** the app's chat list shows no new chat from either read

### Requirement: Memory proposals backend contract

The inbox SHALL rely on the gateway slash commands `/memory pending`, `/memory approve <id>`, `/memory reject <id>`, `/skills pending`, `/skills approve <id>`, `/skills reject <id>` and `/skills diff <id>`, run through `slash.exec` or `command.dispatch` on a session of the profile, with the answer formats described above, 8-hex-character ids and `[auto]` marking a background review. There is no REST route or gateway event for proposals. The new text in a pending summary may be cut (120 characters for a chat write, 200 for a background one) while approving applies all of it. These formats were verified at Hermes `d923a5eb`; earliest release support is unverified.

#### Scenario: Older server without the command

- **WHEN** `/memory pending` is unknown to the server
- **THEN** the card is hidden, the inbox says proposals cannot be read on this server, and the rest of the Memory screen works

### Requirement: Memory proposals privacy and telemetry

Proposal texts, entries and diffs SHALL be held in memory only and SHALL be cleared on sign-out, connection change and profile change; late answers of an old scope SHALL be dropped. Each command SHALL be traced (`memory.proposals.fetch` with `kind`, `count` and `outcome`; `memory.proposals.decide` with `choice` of `approve`, `reject`, `approve_all` or `reject_all`, `kind`, `surface: inbox` and `outcome`; `memory.proposals.diff` with `outcome`). Each decision SHALL log `memory.proposal_decided` (`choice`, `kind`, `outcome`, `surface`), and a read with unknown lines SHALL log `memory.proposals.parse_lenient` (`kind`, `unknown_lines`) at most once. Opening the inbox SHALL add `memory.inbox.opened` (`count`) and a decision `memory.inbox.decide` (`choice`). None SHALL carry memory text, skill names, proposal ids, session ids or profile names.

#### Scenario: Profile switch while reading

- **WHEN** the pending answer of profile "work" arrives after the user switched to "home"
- **THEN** none of its proposals appear for "home"

#### Scenario: Reject all logged

- **WHEN** the user rejects all of three proposals
- **THEN** `memory.proposal_decided` is logged with `choice: reject_all` and no id or text
