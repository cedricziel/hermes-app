# Tasks

Design (done): canvas published, local render reviewed

Canvas: https://claude.ai/artifact/XJvFv9KZFAGCTNDLNFyFnS (private; ask its owner for access). 11 boards: five phone states (title known, title not loaded, opening, deleted, unreachable), largest text, dark, Android with a long title, the list rows on phone and Mac, the Mac window, and the notice as a component. Checked in a local render, not in the claude.ai viewer; see the brief's "Local render review".

Four PRs, each under about 500 changed lines. The catalog PR comes first (`docs/design-briefs/chat-branch-header.md`).

## 1. PR 1 - `feat(chat): branched-from notice in the catalog`

Plain-model widgets only: no controller, no repository, no screen.

- [x] 1.1 Acceptance first: a catalog use case per state (`title`, `unknown`, `opening`, `deleted`, `unreachable`) in light and dark, phone and desktop width, largest text; `test/widgetbook_test.dart` builds them.
- [x] 1.2 `ChatBranchNotice(state, parentTitle, onTap)` in `lib/src/chat/widgets/`: one button (not for `deleted`), 44 pt (48 dp Material, 32 pt Mac), title wraps to two lines, status as icon plus words, semantics label "Branched from <title>. Opens the original chat." ARB keys in en and de under the `chat/widgets` anchor (`chatWidgets…`).
- [x] 1.3 The branch glyph on a thread row model (`SidebarRow` child, `MacThreadRow`, search rows): a `branch` flag, glyph 14 pt (12 pt Mac), "Branch" in the semantics label. Use cases for each row.

## 2. PR 2 - `feat(chat): read the branch parent from session rows`

- [x] 2.1 Failing tests first, with `FakeHermesServer` rows: `_branched_from` gives `ChatThread.branchParentId`; `_reset_from` set gives none; `parent_session_id` without a marker gives none (a compression continuation and a sub-agent row); a blank marker gives none; a row of the wrong type is skipped.
- [x] 2.2 `HermesChatRepository` parses it leniently; `BranchedThread` carries the gateway result's `parent` and `ChatController._branchImpl` seeds the new thread with it.
- [ ] 2.3 (written, not run until `scripts/verify.sh contract`; leave open until it has) Contract test in `test/real_backend_contract_test.dart` (skips without `HERMES_DEV_URL`): branch a chat on a throwaway Hermes, read the list row and the detail row, assert the marker and its value; delete the parent and assert the marker stays and `latest-descendant` answers 404 `Session not found`; compress a parent and assert what its list row carries (id, `_lineage_root_id`) against the marker, to decide whether the title can be matched without a tap. This also settles "Not verified" in `design.md`.

## 3. PR 3 - `feat(chat): open the original chat from a branch`

- [x] 3.1 Failing controller tests first: tap with a loaded parent opens it (one `latest-descendant`, then the open); not loaded opens through `fetchMissing`; `changed: true` opens the tip and the row then names it; 404 `Session not found` ends in `deleted` and a second tap sends nothing; 5xx, no answer and a 10 s wait (simulated clock) end in `unreachable` with nothing resent; a tap while opening is ignored; a read that finishes under the App Lock cover leaves the selection unchanged; a read that finishes after the user selected another chat opens nothing (`dropped`); sign-out and server change drop the state; a profile switch (through the list load) clears the `deleted` set and an in-flight open.
- [x] 3.2 `ChatController.openBranchParent` and a `branchNotice` parameter of `boundChatThreadView` beside `workspaceNotice`, passed only by `ChatScreen`; a test that a conversation window builds none (the quick panel passes none, untested).
- [x] 3.3 Mac: `MacCommand.openParentChat` in the Chat menu, no chord, disabled without a parent or when `deleted`.
- [x] 3.4 Privacy check: a test that the `chat.branch_parent.open` breadcrumb's payload keys are exactly `outcome`; the surface snapshot test sees no parent id or title.
- [x] 3.5 Workflow test screenshot of a branched chat on phone and desktop (`workflow-screenshots`).

## 4. PR 4 - `feat(chat): mark branches in the chat list`

- [x] 4.1 `ThreadSidebar` rows, the Mac source list and both search views pass the glyph flag from `ChatThread.branchParentId`.
- [x] 4.2 Docs: `docs/architecture/chat.md` Branching bullet, `openspec/specs/chat/spec.md` (scenarios under "Thread list loading" and "Thread search").
- [x] 4.3 Archive this change, in the last of the four PRs to merge. (Done in PR 5.)

## 5. PR 5 - `feat(chat): send an idempotency key with every branch and hide Branch when the server lacks it`

- [x] 5.1 Failing tests first: one key per tap; the key kept after a lost answer for the same tap and not after any answer; the same key on the `session.branch` fallback; a gateway that refuses the field gets the request without it; a branch is sent once.
- [x] 5.2 `ChatTransport.branchSupported` (false once neither method exists, true once one worked, null unknown, forgotten with the connection); no reply Branch action and no Mac menu entry when false.
- [x] 5.3 Archive this change.
