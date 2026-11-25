# Design

## Server surface

Verified in the Hermes source at `d923a5eb` (`openapi/HERMES_REF`), read only. The `hermes` command is not installed in this environment, so no response was recorded (see "Not verified").

- **REST rows carry the parent.** `GET /api/sessions` and `GET /api/sessions/{id}` return the session row with its `parent_session_id` column. The list uses compact rows, which leave out only `system_prompt`, `system_prompt_hash` and `git_metadata_generation` (`hermes_state_sessions.py: _SESSION_COMPACT_EXCLUDED`). `SessionDB._session_row_dict` (`hermes_state.py`) also lifts `_branched_from` and `_reset_from` out of `model_config`, so list rows, which drop `model_config`, still carry them. The OpenAPI spec has no response schema for either route (the generated client returns untyped JSON), so the spec says nothing about these keys, and the app reads none of them today (no `parent_session_id` in `lib/`).
- **`parent_session_id` alone does not mean "branch".** It is also set on compression continuations, sub-agent runs and `/new` resets (`hermes_state_sessions.py`, the comment above `_session_filter_where`). The branch marker is `_branched_from`, a non-empty string written by `/branch` at creation. Hermes' own desktop app decides the same way (`apps/desktop/src/lib/session-branch-tree.ts: forkParentId`): a row with `_reset_from` is not a fork, else `_branched_from` is the parent, else `parent_session_id` (legacy forks minted before the marker). The app uses `_branched_from` only. A legacy fork shows as an ordinary chat, which is wrong in a harmless direction; reading `parent_session_id` would label compression continuations and sub-agents as branches.
- **What the list shows.** Compression continuations and sub-agent runs are hidden from the default list (the first is projected onto its root row, with `continuation_kind: "compression"`); branch and reset children are listed as ordinary rows. A projected row keeps the root's `_branched_from`, and its `id` is the tip's.
- **The gateway tells at once.** `session.branch`, `session.branch_whole` (what the app sends, `hermes_gateway_transport_branching.dart: _branchThread`) and `session.branch_stored` answer with `parent`, the parent's stored id, next to `stored_session_id` and `title` (`openrpc/hermes-gateway.openrpc.json`: `SessionBranchResult`, `SessionBranchWholeResult`). `BranchedThread` carries only the new id today.
- **Deleting a parent leaves the marker.** `delete_session` sets `parent_session_id = NULL` on the remaining children "so the FK is satisfied" (`hermes_state_sessions.py`, the `UPDATE sessions SET parent_session_id = NULL` before the delete). The `_branched_from` marker in `model_config` stays, so the child still names a parent that is gone. Deleting every empty session orphans children the same way (the OpenAPI description of that route: "Children of deleted parents are orphaned, not cascade-deleted").
- **One probe finds the parent, follows compression and tells if it is gone.** `GET /api/sessions/{session_id}/latest-descendant?profile=` (`web_routers/sessions.py: get_session_latest_descendant`, in the OpenAPI spec) answers `{requested_session_id, session_id, path, changed}`, where `session_id` is the tip of the parent's compression chain, or 404 with `Session not found`. A parent that auto-compressed since the branch was made is still the same conversation; opening its old root would show a sealed segment.
- **Archived parents resolve.** The same route reads by id, archived or not; the list is what hides archived rows.

## What the app has

- `ChatThread` has no parent. `HermesChatRepository` parses session rows leniently; it skips what it does not know.
- `ChatController._branchImpl` ends with `open(NotificationTarget(threadId: branch.id, profile: profile), fetchMissing: true)`. `fetchMissing` reads a chat that is not in the loaded list by id and puts it on top.
- `MessageActions.onBranch` is offered on finished replies only (`canBranch`), and the Mac thread menu has "Branch in New Chat".
- A thread row is a `SidebarRow` (phone, iPad, Material), a `MacThreadRow` (Mac source list, single line, 28 pt), and `MacSearchResults` rows. None has a leading mark except a Bot Chat's avatar (Mac).
- App Lock is an `Offstage` cover over the whole in-app UI (`AppLockGate`); the screen stays mounted underneath. Titles in the app are therefore hidden as a whole while locked; what App Lock additionally blanks are the surfaces outside the app.

## Decisions

1. **Where the notice sits.** A fixed row between the header and the transcript, in the slot that `FolderMismatchNotice` already uses, not in the app bar and not as the first item of the transcript. The phone app bar already carries the working-directory line under the title; a second line there crowds it, and it would not wrap at the largest text size. A first transcript item scrolls away and, in a long branch, sits behind several pages of "Load older". A fixed row costs 44 pt of height on a phone and cannot be dismissed; that is accepted because a branch is a decision the user made on purpose, and the row is the only way back.
2. **One row, five states** (`ChatBranchNotice`, a plain-model widget):
   - `title`: "Branched from <title>" with a chevron. The title is looked up in the loaded threads by the parent id. It is an ordinary chat title, ellipsized at two lines.
   - `unknown`: the parent is not in the loaded list, or the loaded row has no title yet: "Branched from another chat", chevron, still tappable.
   - `opening`: "Opening the original chat…" and a spinner. Ends within 10 s.
   - `deleted`: "The original chat was deleted." with an info icon, no chevron, not a button.
   - `unreachable`: "Couldn't reach Hermes. Check your connection." with a warning icon and a "Try again" label; the row stays a button.
   Status is the icon and the words, never colour alone.
   A parent that auto-compressed since the branch reads `unknown`, because its loaded row has the tip's id. After a tap resolves the tip, the controller keeps the tip's title for the session so the row can name it. Projected rows also carry `_lineage_root_id` and `_lineage_ids` (`hermes_state_sessions.py`); matching the marker against them would name the parent without a tap, but whether the marker holds the root id is not observed, so that waits for the contract test (task 2.3).
3. **What a tap does.** It asks `latest-descendant` for the parent id with the chat's profile, then `open(NotificationTarget(threadId: tip, profile: profile), fetchMissing: true)`, which selects the parent as a tap on a search result does. The parent is not changed. 404 `Session not found` ends in `deleted`; any other answer, no answer or the 10 s limit ends in `unreachable`; nothing is resent. A tap while `opening` is ignored. The answer is used only if, when it lands, the app's activity epoch and profile are the ones the tap saw and the selected chat is still the branch; otherwise it is dropped (`outcome: dropped`) and nothing opens, so a user who picked another chat meanwhile is not pulled back. `deleted` is remembered in memory (so the row does not offer a tap that can only fail), keyed by profile and parent id. Sign-out and a server change clear it with the other activity state. App Lock keeps it and drops only the reads in flight (a tap under the cover sends nothing, and the row listens to the lock so it works again when the cover lifts); a tap is also refused while a list read is out, and a read in flight is dropped as soon as another profile's list read starts. A profile switch clears it, and any open still in flight, in the `switched` branch of the list load (`chat_controller_history.dart`), where the controller already clears its other profile-scoped state by hand, because the controller itself survives a switch. An ordinary list read does not clear it.
4. **App Lock.** The row is under the cover like the rest. A parent read that finishes while the cover is up does not change the selection: the row returns to its resting state and `chat.branch_parent.open` is logged with `outcome: dropped`. Titles are not read into anything outside the screen: not the breadcrumb, not the semantics hint outside the widget, not the surface snapshot, a notification, Spotlight, Handoff, a Live Activity or the watch.
5. **List and sidebar.** The row keeps one line. A branch gets a 14 pt branch glyph before the title (12 pt in the Mac source list), muted, with "Branch" added to the row's semantics label (the title stays the label's first words). No nesting under the parent: Hermes' desktop nests branches (`session-branch-tree.ts`), but this app's list is grouped by recency or folder and carries pins, swipe actions and search results, a parent may be on another page or in another section, and a nested row would have to be re-sorted whenever either member is touched. No second line with the parent's title: it would show a title the row does not otherwise show, and a second line costs every row 14 pt. The glyph is also shown on search-result rows (`ThreadSearchResults`'s `_HitRow` and `MacSearchResults`). The search route does not say which chat is a branch, so `ThreadSidebar` marks a hit by matching its id against the loaded threads of the same profile; a branch that is not loaded shows no glyph in the results. The glyph carries no title, so App Lock needs no rule for it.
6. **Prompts.** No "Branch from here" on a user prompt. Hermes' undo (`session.undo`, which the shipped flow uses to cut the copy) removes a prompt together with its reply, so a branch can only end after a reply, and "up to and including this prompt" cannot be made. The thing a prompt action would mean is "branch before this prompt and put its text in the composer", which is "Edit in a new chat", a different feature with its own rule (a draft is never sent). The first prompt of a chat has no reply before it, so it would be a new chat, not a branch. Recommendation if wanted later: a separate item, built on `ChatController.branch` plus the deep link's draft rule.
7. **Mac.** The same row under the toolbar (32 pt). Chat > Open Parent Chat (`MacCommand`, no chord, since the menu owns the chord space), disabled when the open chat has no parent or the parent is `deleted`. No row-menu entry in the source list.
8. **Surfaces without the notice.** Conversation windows and the quick panel build a `ChatController` and call `boundChatThreadView` too, but the notice is a parameter of it that only `ChatScreen` passes (as it passes `workspaceNotice`), so they show none and cannot navigate.
9. **Coming back.** The parent does not list its branches, so there is no "back to the branch". The branch is a recent chat in the list. Listing branches on the parent is a non-goal here.
10. **A branch just made** knows its parent before the first list read: the `parent` of the gateway result seeds `ChatThread.branchParentId`, and the next list read confirms it from `_branched_from`.

## Errors and states

| Case | What the user sees | What is sent |
| --- | --- | --- |
| Parent in the loaded list | `title` row; tap opens it | `latest-descendant`, then the open |
| Parent not loaded (other page, archived) | `unknown` row; tap reads it | the same |
| Parent compressed since | `unknown` row (a list row of a compressed chain carries the tip's id, so the lookup by the old id misses); tap opens the tip | the same, `changed: true` |
| Parent deleted | tap ends in `deleted`; row becomes information | one `latest-descendant`, 404 `Session not found` |
| No answer, 5xx, 10 s | `unreachable`, "Try again" | nothing resent; the next tap asks again |
| Server lacks the route (404 other than `Session not found`, 405) | `unreachable` (the same words; there is no better) | one request |
| Row without `_branched_from` | no row | nothing |
| `_reset_from` set | no row (not a branch) | nothing |
| App Lock cover while opening | row at rest, selection unchanged | nothing |
| User selected another chat while the read ran | row at rest, nothing opens, `dropped` | nothing |
| Sign-out, server change | `deleted` set and any open dropped with the activity state | nothing |
| Profile switch | `deleted` set cleared and any in-flight open dropped in the `switched` branch of the list load | nothing |
| Large text | row grows, title wraps to two lines | nothing |

## Platforms

iPhone and iPad: 44 pt row. Android, Windows and Linux: 48 dp row, same words. Mac: 32 pt row, chat menu entry. The glyph is 14 pt on touch and 12 pt on the Mac source list.

## Invariants touched

- `ChatController.open(fetchMissing: true)` stays the one way to open a chat that may not be loaded.
- Nothing about the notice is stored on the device; `branchParentId` is read from the server on every list read.
- `latest-descendant` is a read: sent once per tap, never resent automatically, with the chat's explicit profile.

## Observability

`chat.branch_parent.open` breadcrumb, `outcome` only. No title, id or profile.

## Design pass

See `docs/design-briefs/chat-branch-header.md`. Canvas: https://claude.ai/artifact/XJvFv9KZFAGCTNDLNFyFnS (private; ask its owner for access).

## Not verified

No response was captured: that a real server returns `_branched_from` in compact list rows and in the detail row, what the value holds for a branch made by `session.branch_whole` (read as the parent's id from `_session_row_dict` and `forkParentId`, not observed), that `latest-descendant` answers for an orphaned child's `_branched_from`, and the exact 404 text on older servers. The first task of the implementation is a contract test in `test/real_backend_contract_test.dart` that branches a chat on a throwaway Hermes (`scripts/dev-backend.sh`) and reads both rows.
