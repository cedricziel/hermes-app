# Design

## Context

Facts about Hermes this design relies on, first read from the source at Hermes `71d34bad` and then checked against a throwaway backend at `d923a5eb` (the revision `openapi/HERMES_REF` pins). Where the two differ, the text below gives `d923a5eb`:

- With `memory.write_approval` on, every foreground memory write in an app or gateway session is staged, never asked inline. With it off, background-review replace and remove are still staged and adds are written directly. Skill writes are staged under `skills.write_approval`.
- There is no REST route or gateway event for proposals. The only interface is gateway slash commands: `/memory pending`, `/memory approve <id|all>`, `/memory reject <id|all>`, `/skills pending`, `/skills approve|reject <id|all>`, `/skills diff <id>`.
- `/memory pending` answers:

  ```text
  Pending memory writes (N):
    <id>[ [auto]]  <summary>
        <action>s entry: <full matched entry>

  Apply: /memory approve <id>   Reject: /memory reject <id>
  ```

  or "No pending memory writes.". Ids are 8 hex characters; `[auto]` marks a background review, its absence a chat. A detail line (six spaces) appears for replace, patch and remove: `replaces entry:`, `patchs entry:` (Hermes appends an "s" to the action) and `removes entry:` hold the whole pinned entry, one line per destructive operation of a batch. A write staged before entries were pinned has `replace: unpinned legacy target — reject and recreate before approving` instead. A chat write's summary is `<action> to|in|from <label>: <detail cut at 120 characters>`, where the label is `user profile` or `memory`; a replace's detail is `entry matching: X` and, on an unindented line, `whole entry becomes: Y`; a patch's is `entry matching: X` and `span 'X' becomes: Y (rest of the entry is kept)`; a batch's summary is `apply N op(s) to <label>: - add: …` with one `- <op>` line each. Continuation lines of a summary carry no indent. A background review's summary is `background review consolidation (<action> on <target>): <detail>` cut at 200 characters in all, with `<target>` `memory` or `user` and the detail `- replace: Y`, `- add: Y`, `- remove: X` or `- patch span 'X' -> 'Y' (rest of the entry is kept)`. So id, origin, action, target and the full old entry are recoverable, and the new text may be cut; approving applies all of it.

- `/skills pending` and every other `/skills` answer start with a progress line `⏳ Processing skills command...`, then `Pending skills writes (N):`, the same item lines and an extra footer line `Review full diff: /skills diff <id>`. An unknown command answers the plain text `Unknown command /x — nothing was sent.` (not an error).

- Approve answers "Approved N memory write(s)." ("skills" for a skill), then for a replace, patch or remove a block such as `Overwrote entire entry (re-add anything you still need):` / `Patched entry (as it was before the edit):` / `Removed entry (re-add anything you still need):` with `  <id>: <entry>` lines, and, when something failed, "Failed:" with `  <id>: <error>` lines (for example "Entry changed since it was staged, so this write was not applied: '…' is no longer in memory as reviewed. …" when the pinned entry changed; the record stays pending). Only the lines under "Failed:" are failures. Approving an id while nothing is pending answers "No pending memory writes."; with other records pending, "No pending memory write with id '<id>'.". Reject answers "Rejected pending memory write '<id>'." ("skills write" for a skill). Skill gists read like `create 'name' — <description> (N chars)`, `rewrite 'name' …` or `patch 'name' SKILL.md (+a/-r lines)`; `/skills diff <id>` answers `# Pending skill write <id>: <gist>`, a blank line and the new content (create) or a unified diff. Newer Hermes calls replace "patch"; both are read.
- `memory.write_approval` is read at every write, so the toggle applies at once.

The app runs slash commands through `ChatTransport.runSlashCommand({threadId, profile, command})`. With `threadId: null` the gateway transport calls `session.create` with the profile (source `hermes_app`), then `slash.exec` (or `command.dispatch` on error 4018), and returns the plain-text `output`. Whether that leaves an empty stored session that the chat list (this app's or another client's) shows is not known. `memory-tool-calls` adds `MemoryDecisions` and the approve/reject answer parser; `memory-settings` adds the config writer; `memory-navigation` adds the Memory entries with an empty detail slot.

Platforms: iOS, iPadOS, Android, macOS, Windows, Linux. No native, entitlement, manifest or Xcode project change.

## Goals / Non-Goals

**Goals:**

- Every staged write of the profile is visible and decidable, whatever produced it.
- Nothing is approved that the user did not see.
- A change in Hermes' wording degrades to raw text, never to a crash or a wrong decision.

**Non-Goals:**

- Editing proposals, notifications, cross-profile lists.

## Decisions

**Where the commands run (decided).** Task 1.1 checked this against a throwaway backend at Hermes `d923a5eb`, with records staged under `<HERMES_HOME>/pending/`:

- `runSlashCommand(threadId: null, profile:)` (`session.create` with source `hermes_app`, then `slash.exec`) leaves no stored session. `GET /api/sessions?profile=` stayed `{"sessions": [], "total": 0}` and `state.db` held no `sessions` row before or after, across about 30 commands (the real-backend contract test repeats this on every run).
- Running a command in an existing chat was therefore not needed and not tried.

So the app uses option 1: `threadId: null`, one new gateway session per command. Options 2 and 3 are not built. The choice lives in `MemoryProposalSession`, so the inbox, the count and Approve all share it. Cost: each command opens its own session and takes about 1.5 to 4 seconds on a local backend, so Approve all over N items takes N rounds plus a read.

**Lenient parser.** `parseMemoryPending(text)` and `parseSkillsPending(text)` return items, the unknown lines and whether the answer is unreadable; they never throw.

- Leading `⏳` progress lines are dropped. "No pending memory writes." (or any text starting "No pending") and a blank answer → empty.
- A line matching `^\s{2}([0-9a-f]{8})(\s+\[auto\])?\s{2,}(.*)$` starts an item: id, origin (`auto` → background review, else chat), raw summary.
- A line matching `^\s{6}(\w+?)s? entry: (.*)$` under an item is a replaced or removed entry (several for a batch; replace and patch → Replace, remove → Remove). Another six-space line is kept as the item's warning. A line after an entry line with no indent continues that entry.
- The header line ("Pending … writes (N):"), blank lines and the "Apply:" and "Review full diff:" footer lines are skipped; any line after the footer is unknown.
- Any other line after an item's first line continues its summary (a replace's second line); before any item it is counted as unknown.
- From the summary: a chat write's action is its first word (`add`, `replace`, `patch` → Replace, `remove`) and its target the label before ": " (a label containing "user" or "profile" → About you, "memory" or "notes" → Agent notes); a background summary's action and target come from the parenthesis (`user` → About you). The new text is the detail after the first ": " for an add, the part after "whole entry becomes: " for a replace, the span after "becomes: " for a patch, the text after `- replace:`, `- add:` or inside `-> '…'` for a background one, and none for a remove. It is marked possibly shortened when it ends in "…", when a chat detail reaches 120 characters or when a background summary reaches 200.
- An item whose action cannot be read (a batch, or wording the app does not know) keeps its raw summary and shows the badge "Change"; its target is shown when the label can be read. It can still be approved and rejected by id.
- Skill items: the badge is Skill, the target the first quoted name, the gist is shown as written.
- A non-empty answer that yields no item and is not an empty answer is unreadable: "Hermes answered in a way the app doesn't understand", with the raw text and a retry.

**Reading.** `MemoryProposalsRepository.load(profile)` runs `/memory pending` and `/skills pending` in parallel; a failure of one shows the other's items with a note that the other kind could not be read. A command the server does not know (an older Hermes) answers `Unknown command …` and reads as unsupported: the card is hidden and the inbox says proposals cannot be read on this server. It is read when the Memory screen opens, when the inbox opens, after every decision, after a failure, and on pull to refresh.

**Deciding.** Approve and Reject per item run `/memory approve|reject <id>` or `/skills approve|reject <id>` through `MemoryDecisions` (from `memory-tool-calls`). Approve all and Reject all send the per-item command for each id on screen, one after another, never `all`, so a proposal staged after the list was read is not decided unseen; they stop at the first transport error. Reject all asks first. After any decision the list is read again. Banners: memory approve → "Saved to <target> · Hermes uses it from the next chat" (no target → "Saved · Hermes uses it from the next chat"); reject → "Rejected"; a failure → Hermes' text for that id.

**Skill diff.** "Show changes" runs `/skills diff <id>` and shows the answer in the existing diff body (`ToolDiffBody`); an answer that is not a diff is shown as plain text.

**Inbox layout.** At 900 points or wider on macOS, Windows and Linux and 700 points or wider on iPad, the list sits beside the selected item's detail (first item selected); narrower, the list opens the detail as a pushed page. The detail shows the badge, target, origin, the old entry in full and struck through, the new text with the shortening note when it applies, and the buttons. "Ask before saving" sits at the bottom of the list as a `GroupedSwitchRow` with the subtitle "Off: Hermes saves new entries itself and only asks before a background review replaces or removes one", written through the `memory-settings` writer (optimistic, reverted on failure).

**Waiting card.** On the Memory screen above the tabs: "N changes waiting for you · Not saved until you approve them" (memory plus skill items), hidden at 0 and while the list could not be read.

**Count on the entries.** The sidebar's Memory entry shows "Memory · N waiting" and the Mac Profiles page's Memory value "N waiting" (in place of the entry count) when N > 0. The sidebar count is read for the chat's profile when the chat loads its threads, on app resume at most every five minutes, and after a decision; the Profiles page reads it when a profile is selected. A failed read shows no count.

**Privacy.** Items, texts and diffs live in the inbox controller and are cleared on sign-out, connection change and profile change; late answers of an old scope are dropped, as the learned-memory specs require. Nothing is persisted.

**Invariants touched.** API layering: no REST call except the config writer from `memory-settings`; the commands go over the gateway socket through `ChatTransport`. Auth: unchanged. Telemetry: no text or id.

**Observability.**

- Span `memory.proposals.fetch` per command (`kind`: `memory` | `skill`, `count`, `outcome`: `ok` | `unreadable` | `failed`), from `MemoryProposalsRepository`, with `hermes.*` attributes.
- Span `memory.proposals.decide` (`choice`: `approve` | `reject` | `approve_all` | `reject_all`, `kind`, `surface: inbox`, `outcome`), from `MemoryDecisions`.
- Span `memory.proposals.diff` (`outcome`).
- Log `memory.proposal_decided` (`choice`, `kind`, `outcome`, `surface`) after each decision.
- Log `memory.proposals.parse_lenient` (`kind`, `unknown_lines`) when a parse counts unknown lines, at most once per read.
- Breadcrumbs `memory.inbox.opened` (`count`) and `memory.inbox.decide` (`choice`).

None holds memory text, skill names, proposal ids, session ids or profile names.

## Risks / Trade-offs

- [The check finds that every option leaves something visible to other clients] → option 3 limits it to one session per profile, titled so the user can tell what it is. Accepted, and stated in the PR.
- [Hermes rewords its output] → unknown lines keep their raw text and are counted in `memory.proposals.parse_lenient`; decisions still work by id.
- [Approve all over many items is one round trip per item] → profiles hold few proposals; the buttons show progress. Chosen over `all`, which could approve a write the user never saw.
- [The sidebar count costs a gateway round trip] → only on thread load, resume (throttled) and decisions.

## Migration Plan

None. Nothing is stored on the device.
