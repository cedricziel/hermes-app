# Design

## Context

Facts about Hermes this design relies on, verified at Hermes `71d34bad`:

- With `memory.write_approval` on, every foreground memory write in an app or gateway session is staged, never asked inline. With it off, background-review replace and remove are still staged and adds are written directly. Skill writes are staged under `skills.write_approval`.
- There is no REST route or gateway event for proposals. The only interface is gateway slash commands: `/memory pending`, `/memory approve <id|all>`, `/memory reject <id|all>`, `/skills pending`, `/skills approve|reject <id|all>`, `/skills diff <id>`.
- `/memory pending` answers:

  ```text
  Pending memory writes (N):
    <id>[ [auto]]  <summary>
        <action>s entry: <full matched entry>

  Apply: /memory approve <id>   Reject: /memory reject <id>
  ```

  or "No pending memory writes.". Ids are 8 hex characters; `[auto]` marks a background review, its absence a chat. The detail line appears for replace and remove only and holds the whole old entry. A chat write's summary is `<action> to|in <label>: ` followed by the content cut at 120 characters; a replace summary may contain a newline (`entry matching: X` / `whole entry becomes: Y`). A background consolidation's summary is `background review consolidation (<action> on <target>): …` cut at 200. So id, origin, action, target and the full old entry are recoverable, and the new text may be cut; approving applies all of it.

- Approve answers "Approved N memory write(s)." optionally followed by "Failed:" and `  <id>: <error>` lines (for example when the pinned entry changed since staging). Reject answers "Rejected pending memory write '<id>'.". Skill gists read like `create 'name' — <description> (N chars)` or `patch 'name' SKILL.md (+a/-r lines)`; `/skills diff <id>` answers a unified diff. Newer Hermes calls replace "patch"; both are read.
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

**Where the commands run (decided before implementation).** Task 1.1 checks on a real backend (`scripts/dev-backend.sh`, `verify-in-app`) whether `runSlashCommand(threadId: null, profile:)` leaves a stored session that `GET /api/sessions?profile=` lists, and whether running `/memory pending` on an existing thread changes that thread's messages, title or `last_active`. The result, with the Hermes revision, is written into this section before any other task starts. The app then uses the first of these that the check allows:

1. `threadId: null`, when no stored session is left behind (or it is never listed).
2. Otherwise the profile's most recently active stored chat, when running a command there leaves its history and ordering untouched; with no chat in the profile, option 3.
3. Otherwise one session per profile, created on first use with the title "Memory review", found again by that title through `GET /api/sessions?profile=` (the way Bot Mode resolves its hidden Bot Chat registry) and left out of the app's chat list and search by id. Its id is held in memory only and resolved again after a restart.

The option is chosen in one place (`MemoryProposalSession`), so the inbox, the count and Approve all share it.

**Lenient parser.** `parseMemoryPending(text)` and `parseSkillsPending(text)` return items and a count of unknown lines; they never throw.

- "No pending memory writes." (or any text starting "No pending") → empty.
- A line matching `^\s{2}([0-9a-f]{8})(\s+\[auto\])?\s{2,}(.*)$` starts an item: id, origin (`auto` → background review, else chat), raw summary.
- A line matching `^\s{6}(\w+?)s? entry: (.*)$` under an item is its old entry (action from the verb: replaces/patches → Replace, removes → Remove).
- The header line ("Pending … writes (N):"), blank lines and the "Apply:" footer are skipped.
- Any other line before the footer continues the current item's summary (a replace summary's second line); before any item it is counted as unknown.
- From the summary: a chat write's action is its first word (`add`, `replace`, `patch`, `remove`) and its target the label before ": " (a label containing "user" or "profile" → About you, "memory" or "notes" → Agent notes); a background summary's action and target come from the parenthesis. The new text is what follows the first ": " (for a replace, the part after "whole entry becomes: " when present). It is marked possibly shortened when it ends in "…" or reaches the cut length (120 for a chat write, 200 for a background one).
- An item whose action or target cannot be read keeps its raw summary and shows the badge "Change" with no target; it can still be approved and rejected by id.
- Skill items: the badge is Skill, the target the quoted name, the gist is shown as written.
- A non-empty answer that yields no item and is not an empty answer is shown as "Hermes answered in a way the app doesn't understand", with the raw text and a retry.

**Reading.** `MemoryProposalsRepository.load(profile)` runs `/memory pending` and `/skills pending` in parallel; a failure of one shows the other's items with a note that the other kind could not be read. A command the server does not know (an older Hermes) reads as unsupported: the card is hidden and the inbox says proposals cannot be read on this server. It is read when the Memory screen opens, when the inbox opens, after every decision, after a failure, and on pull to refresh.

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
