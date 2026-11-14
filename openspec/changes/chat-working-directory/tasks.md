# Tasks

Four PRs, each under about 500 changed lines with tests, merged in order. Each ends with its own format, analyze and test task.

## 1. PR 1 — `feat(workspaces): read projects, folders and the chat's working directory`

- [ ] 1.1 Add fixtures to `FakeHermesServer` for `GET /api/chat/workspaces` (projects, repos, `default_cwd`, `home`, `scan_enabled`; `scan=1`; unknown profile 404) and `GET /api/fs/list` (entries; 200 with `error`; 403; 400), and gateway fakes for `complete.path` and `session.workspace.move` (success, 4007, 4016, 4017, 5007, `-32601`).
- [ ] 1.2 Write failing repository tests for `HermesWorkspacesRepository`: `catalog(profile:, scan:)` parses the example in design.md and skips a project without `id` or `name`, a repo without `root`, a folder without `path`; `listFolders(path, profile:)` keeps directories only, maps `error` values and 403 to `WorkspacesFailure`, ignores unknown fields; `complete(word, profile:)` keeps `meta == "dir"` rows, at most 30; `moveWorkspace(storedId, cwd, profile:)` maps 4017 to `notFound`, `-32601` to `WorkspacesUnsupported`, a lost answer to `unreachable`; 404 on the catalog is `WorkspacesUnsupported`. Then implement it with the sealed `WorkspacesResult` through `authController.api!.raw` and the shared gateway requester.
- [ ] 1.3 Write failing pure tests for `WorkspaceProjects.projectFor(path, projects)` (equal path, ancestor, longest folder wins, trailing slash and separator normalisation, archived ignored, no match) and for the path comparison used by the mismatch notice (trailing separators, leading `~` with `home`, relative and remote paths not compared). Implement them.
- [ ] 1.4 Write failing tests that `ChatThread` keeps the raw `cwd` as `workingDirectory` and `git_branch` as `branch` next to `folderPath`, that rows without them leave both null, and that grouping is unchanged. Implement it in the repository's thread parser.
- [ ] 1.5 Extend `test/real_backend_contract_test.dart`: catalog shape, `fs/list` on a temp directory (including the 200-with-`error` case), a `complete.path` call, a chat created with a `cwd` and `cwd_explicit`, a bad `cwd` falling back, a move, and which cwd a `hermes_app` chat created without `cwd` stores.
- [ ] 1.6 Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze` and `flutter test`, all passing.

## 2. PR 2 — `feat(chat): create chats in a chosen folder and move them`

- [ ] 2.1 Write failing transport tests: `send` with a `WorkspaceChoice` on a new chat sends `cwd` and `cwd_explicit: true` on `session.create`; no choice sends neither; a resumed chat sends none; a 4000 about `cwd_explicit` retries the create once without it; `info.cwd`, `branch` and `project` come out as `WorkspaceBound`; the create retry rules (3 attempts) are unchanged. Implement it in `HermesGatewayTransport`, `ChatTransport` and `SessionChatTransport`, giving every other caller the default.
- [ ] 2.2 Write failing `ChatController` tests in a new `chat_controller_workspace.dart` part: the draft choice lives on the new thread, is cleared on profile switch, sign-out and after creation; `WorkspaceBound` sets `workingDirectory`/`branch`; a differing reported folder adds the one-time mismatch notice and logs `workspace.cwd_mismatch` with no path; `moveWorkspace` sends once, updates the thread and regroups it, keeps the selection, refuses while replying, for a Bot Chat registry and for an unopened other-profile chat, handles 4017, 5007, `unsupported` (hides the action for the connection) and a lost answer (re-read of `GET /api/sessions/{id}`, no resend). Implement them.
- [ ] 2.3 Write failing `WorkspacePickerController` tests: loading, ready, partial (catalog failed, browse works), failed, unsupported, offline, rescan only when `scan_enabled`; ordering and de-duplication (a repo under a project folder is not in Recent); search filtering above eight rows; browse stack with a locked-server 403 hiding Browse; typed suggestions keep only the latest answer; late answers after dispose or a profile change are dropped; selection. Implement it.
- [ ] 2.4 Add the telemetry (`workspace.picker.opened`, `workspace.chosen`, `workspace.move.confirmed`, spans `workspace.list` and `workspace.move`, events `workspace.move_outcome`, `workspace.cwd_mismatch`) with a test per record that no path, name, branch or profile appears in any attribute.
- [ ] 2.5 Write a failing test that sign-out and Change Server clear the draft choice and catalog, and that no path reaches shared preferences, the surface snapshot, Spotlight or notification payloads. Implement it.
- [ ] 2.6 Run format, analyze and test, all passing.

## 3. PR 3 — `feat(workspaces): folder row, picker and confirmation widgets` (after the Claude Design pass)

- [ ] 3.1 Hand `docs/design-briefs/chat-working-directory.md` to the Claude Design pass and commit its output under `design/` as the repo does for other features.
- [ ] 3.2 Add Widgetbook use cases as plain-model widgets in `lib/src/workspaces/widgets/` (`WorkingDirectoryRow`, `WorkingDirectoryLine`, `WorkingDirectoryDetails`, `WorkspacePickerView`, `FolderBrowserView`, `PathEntryView`, `ChangeFolderConfirmation`, `FolderMismatchNotice`): each in every state (default only, project picked, repo picked, home-folder note, long path, no branch, loading, empty, partial failure, failed, unsupported, offline, locked browse, unreadable folder, missing folder, moving, move failed) in both themes at phone and desktop width, and with 2.0 text scale. `test/widgetbook_test.dart` must build them all.
- [ ] 3.3 Add widget tests for the plain-model widgets: 44 pt targets, semantics labels, selected state, keyboard order on desktop, Escape and Return, no hit target overlap at 2.0 scale.
- [ ] 3.4 Run format, analyze and test, all passing.

## 4. PR 4 — `feat(chat): show and choose where a chat runs`

- [ ] 4.1 Wire the row above the composer in `ChatScreen`'s new-chat welcome (phone, iPad, Mac), the header line and details sheet for an open chat, and the picker through `showAdaptiveSheet` (dialog on Mac and wide windows). Add the Mac toolbar button on `MacToolbar` and `ThreadAction.changeFolder` ("Change Working Directory…") on the thread and sidebar row menus. Conversation windows show the line and details; the quick panel shows none.
- [ ] 4.2 Make `chat-folder-grouping` headers and the header line share one label function; add a test that the two agree, including disambiguated basenames, and that a moved chat regroups with selection kept.
- [ ] 4.3 Add a workflow test in `test/workflows/` (phone and desktop, light and dark): new chat, pick a project, send, see the folder in the header, move the chat, see the regrouped list; and an old-server run where the row and picker are absent. Look at the screenshots.
- [ ] 4.4 Update `CLAUDE.md` (a **Working directory** paragraph under Chat: the row, picker sources, `cwd_explicit`, the mismatch notice, the move, hiding on old servers, no stored paths) and the `verify-in-app` skill (how to make a project and a repo on the dev backend's `HERMES_HOME`, and the fs-list lock env var `HERMES_DASHBOARD_FILES_ROOT`).
- [ ] 4.5 Run format, analyze and test, all passing.

## Not verified on a device

Run after the PRs merge; note in each PR which were done.

- 5.1 `verify-in-app` on macOS against a throwaway backend with a project of two folders and two repos: picker shows them, a pick starts the chat in that folder (`GET /api/sessions` shows its `cwd`), the header matches, Browse and Type work, the mismatch notice appears when the picked folder is removed between pick and send, and a move shows in the list.
- 5.2 Confirm on a live backend that a chat moved with `session.workspace.move` and then resumed runs its next turn in the new folder, and that one created with no `cwd` stores the launch directory (source `hermes_app`).
- 5.3 With `HERMES_DASHBOARD_FILES_ROOT` set, Browse hides itself and Type and projects still work.
- 5.4 A profile with its own `terminal.cwd`: a pick wins (`cwd_explicit`), the default row shows the profile's folder.
- 5.5 iPhone and Android: sheet, large text, VoiceOver and TalkBack reading of the row and picker, keyboard on iPad, Mac dialog keyboard flow, reduced motion.
