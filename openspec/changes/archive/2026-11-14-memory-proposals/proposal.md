# Proposal

## Why

Hermes stages memory and skill writes for the user's approval: every foreground memory write while "Ask before saving" is on, a background review's replace or remove even when it is off, and skill writes under `skills.write_approval`. Staged writes are not saved until someone approves them, but nothing in the app lists them: the tool card of change `memory-tool-calls` appears only for writes made in a chat the user is looking at, and only while tool progress is shown. Background-review proposals never appear anywhere, so they wait forever.

## What Changes

- On the Memory screen, a card "N changes waiting for you · Not saved until you approve them", hidden when nothing waits, opens a **Waiting for you** inbox.
- The inbox lists memory and skill proposals read from Hermes' `/memory pending` and `/skills pending` commands: a badge (Replace, Add, Remove, Skill), the target (About you, Agent notes, or the skill), the origin ("from a chat" or "from a background review"), the replaced entry in full and struck through, and the new text, which may end in "…" with the note "Long new text is shortened in this list; approving applies all of it".
- Approve and Reject per item, Approve all and Reject all, and "Show changes" for a skill item (`/skills diff <id>`). After an approval: "Saved to About you · Hermes uses it from the next chat". The list is read again after every action and after a failure.
- A row "Ask before saving" at the bottom, with "Off: Hermes saves new entries itself and only asks before a background review replaces or removes one".
- The waiting count also appears on the Memory entries of change `memory-navigation`: "Memory · 2 waiting" in the sidebar, "2 waiting" on the Mac Profiles page.
- At 900 points or wider on macOS, Windows and Linux, and 700 points or wider on iPad, the list sits beside the selected proposal's detail.
- The parser is lenient: a line it does not understand keeps the raw text, and it never crashes.
- Before implementation, a check against a real backend settles whether reading proposals through a new gateway session leaves an empty chat in the chat list, and the design's mitigation is applied if it does.

Non-goals:

- Editing a proposal's text before approving it. Hermes has no command for it.
- Notifications or background checks for new proposals.
- Showing proposals of other profiles in one list; the inbox is per profile like the rest of Memory.
- A REST route or gateway event for proposals; none exists, so the app uses the slash commands.
- Clearing proposals on reset (Hermes keeps them).

## Capabilities

### New Capabilities

- `memory-proposals`: reading, parsing and deciding staged memory and skill writes, the inbox and its layout, the waiting count on the Memory entries, and the session the commands run in.

### Modified Capabilities

None. The navigation count is specified here as its own requirement on the entries `memory-navigation` adds.

## Impact

- Code: `lib/src/memory/` (proposals parser, repository on `ChatTransport.runSlashCommand`, inbox controller, the decision parser from `memory-tool-calls`), new widgets in `lib/src/memory/widgets/` (waiting card, inbox list, detail, diff), `memory_screen.dart`, the navigation entries' detail texts (`thread_sidebar.dart`, `chat_screen_layout.dart`, `mac_profiles_page.dart`), Widgetbook use cases.
- Backend: no new route. The gateway's `session.create`, `slash.exec` / `command.dispatch` with `/memory pending|approve|reject` and `/skills pending|approve|reject|diff`, and `PUT /api/config?profile=` for the toggle (from `memory-settings`).
- Delivery: two PRs (see tasks.md).
- Security and privacy: the inbox shows memory and skill text that Hermes already holds; it stays in memory and is cleared on sign-out, connection and profile change. Approve all and Reject all decide the listed ids one by one instead of sending `all`, so a proposal the user never saw is not decided. No token or secret handling changes.
- Observability: spans `memory.proposals.fetch` (`kind`, `count`, `outcome`), `memory.proposals.decide` (`choice` approve | reject | approve_all | reject_all, `kind`, `surface: inbox`, `outcome`) and `memory.proposals.diff` because each crosses the socket; logs `memory.proposal_decided` (`choice`, `kind`, `outcome`, `surface`) and `memory.proposals.parse_lenient` (`kind`, `unknown_lines` count) so format drift shows up; breadcrumbs `memory.inbox.opened` (`count`) and `memory.inbox.decide` (`choice`). No memory text, skill names, ids or profile names.
