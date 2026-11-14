# Tasks

Six PRs and a design gate, each under about 500 changed lines with tests, merged in order. PRs 1 to 3 add behaviour that has no screen yet (a repository, transport parameters, controllers), so they are `feat` commits under Conventional Commits. Each ends with its own format, analyze and test task.

## 1. PR 1 — `feat(workspaces): repository, models and thread folder fields`

- [ ] 1.1 Add fixtures to `FakeHermesServer` for `GET /api/chat/workspaces` (projects, repos, `default_cwd`, `home`, `scan_enabled`; `scan=1`; unknown profile 404) and `GET /api/fs/list` (entries; 200 with `error`; 403 boundary; 403 `EACCES`; 503; 400), and gateway fakes for `complete.path` and `session.workspace.move` (success, 4007, 4016, 4017, 4064, 5007, `-32601`).
- [ ] 1.2 Write failing repository tests for `HermesWorkspacesRepository`: `catalog(profile:, scan:)` parses the design.md example and skips a project without `id` or `name`, a repo without `root`, a folder without `path`; `listFolders(path, profile:)` keeps directories only, separates the boundary 403 from a per-level 403/`EACCES`, maps 503 to `unreachable`, maps `error` values to `WorkspacesFailure`; `complete(word, profile:)` keeps `meta == "dir"` rows, reports when 30 items came back, and builds each next text from the typed directory plus `display`, never from `text`, with an absolute word as one case; `moveWorkspace(storedId, cwd, profile:)` maps 4017 to `notFound`, 4064 to an unknown profile, `-32601` to `WorkspacesUnsupported`, a lost answer to `unreachable`; 404 on the catalog is `WorkspacesUnsupported`. Implement it with the sealed `WorkspacesResult` through `authController.api!.raw` and the shared gateway requester.
- [ ] 1.3 Write failing pure tests for `WorkspaceProjects.projectFor(path, projects)` (equal, ancestor, longest folder wins, separator and trailing-slash normalisation, archived ignored, none), for the path comparison used by the mismatch notice (trailing separators, a leading `~` with `home`), and for `isServerPath` (starts with `/` or `~`). Implement them.
- [ ] 1.4 Write failing tests that `ChatThread` keeps raw `cwd` as `workingDirectory` and `git_branch` as `branch` next to `folderPath`, that rows without them leave both null, that grouping is unchanged, and that applying a move answer sets `folderPath` to `git_repo_root` or else `cwd`. Implement it in the thread parser.
- [ ] 1.5 Extend `test/real_backend_contract_test.dart`: catalog shape, `fs/list` on a temp directory (including the 200-with-`error` case), a `complete.path` call with an absolute word, a chat created with `cwd` and `cwd_explicit`, a bad `cwd` falling back, a move, a move with a relative path, and which folder a `hermes_app` chat created without `cwd` stores.
- [ ] 1.6 Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze` and `flutter test`, all passing.

## 2. PR 2 — `feat(chat): create chats in a chosen folder and move them`

- [ ] 2.1 Write failing transport tests: `send` with a `WorkspaceChoice` on a new chat sends `cwd` and `cwd_explicit: true` on `session.create`; no choice sends neither; a resumed chat sends none; `sendQueued` never carries one; a 4000 naming `cwd_explicit` retries the create once without it; `info.cwd`, `branch` and `project` come out as `WorkspaceBound`; the create retry rules (3 attempts) are unchanged. Implement it in `ChatTransport`, `SessionChatTransport` and the `session.create` call of `hermes_gateway_transport_sending.dart` (part of `HermesGatewayTransport`), giving every other caller the default.
- [ ] 2.2 Write failing `ChatController` tests in a new `chat_controller_workspace.dart` part: the draft choice lives on the new thread and is cleared on profile switch, sign-out and creation; `WorkspaceBound` sets `workingDirectory`/`branch`; a differing reported folder adds the one-time notice and logs `workspace.cwd_mismatch` with no path; `moveWorkspace` (through the repository) sends once, updates `workingDirectory` and `folderPath`, regroups with selection kept, refuses while replying, for a Bot Chat registry and for an unopened other-profile chat, rejects a path that is not `/` or `~`-led, handles 4017, 5007, unsupported (hides the action for the connection) and a lost answer (re-read of `GET /api/sessions/{id}`, no resend). Implement them.
- [ ] 2.3 Add `WorkspaceCatalogLoader` (one per new-chat recipient profile, kept while the welcome view shows, cleared on profile switch, sign-out and Change Server; loading, ready, failed, unsupported, offline) with tests, and use it from the controller for the row's default folder and project tag.
- [ ] 2.4 Run format, analyze and test, all passing.

## 3. PR 3 — `feat(workspaces): folder picker controller and telemetry`

- [ ] 3.1 Write failing `WorkspacePickerController` tests: loading, ready, partial (catalog failed, browse works), failed, unsupported, offline, rescan only when `scan_enabled`; ordering and de-duplication (a repo under a project folder is not in Recent); search filtering above eight rows; browse stack with the first-read boundary 403 hiding Browse and a later 403 staying per level; typed suggestions keep only the latest answer and never accept a relative path; a profile change closes it; late answers after dispose are dropped; selection. Implement it on top of the catalog loader.
- [ ] 3.2 Add the telemetry (`workspace.picker.opened`, `workspace.chosen`, `workspace.move.confirmed`, spans `workspace.list` and `workspace.move`, events `workspace.move_outcome`, `workspace.cwd_mismatch`) with a test per record that no path, name, branch or profile appears in any attribute.
- [ ] 3.3 Write failing tests that sign-out, Change Server and App Lock clear the draft choice and catalog and close an open picker or confirmation, and that no path reaches shared preferences, the surface snapshot, Spotlight or notification payloads. Implement them.
- [ ] 3.4 Run format, analyze and test, all passing.

## 4. Gate: Claude Design pass

- [ ] 4.1 Hand `docs/design-briefs/chat-working-directory.md` to the Claude Design pass and commit its output under `design/` as the repo does for other features. PR 5 does not start before this is merged; PR 5's use cases follow the design.

## 5. PR 5 — `feat(workspaces): folder row, picker and confirmation widgets`

- [ ] 5.1 Add Widgetbook use cases as plain-model widgets in `lib/src/workspaces/widgets/` (`WorkingDirectoryRow`, `WorkingDirectoryLine`, `WorkingDirectoryDetails`, `WorkspacePickerView`, `FolderBrowserView`, `PathEntryView`, `ChangeFolderConfirmation`, `FolderMismatchNotice`), each in every state (default only, project picked, repo picked, home-folder note, long path, no branch, loading, empty, partial failure, failed, unsupported, offline, locked browse, unreadable level, missing folder, moving, move failed, Current marker) in both themes at phone and desktop width and at 2.0 text scale. `test/widgetbook_test.dart` must build them all.
- [ ] 5.2 Mirror the use cases in `design/web` as the bot-screen-card change did (`.design-sync/NOTES.md`).
- [ ] 5.3 Add widget tests: 44 pt targets, semantics labels, selected state, keyboard order on desktop, Escape and Return, no overlapping targets at 2.0 scale.
- [ ] 5.4 Run format, analyze and test, all passing.

## 6. PR 6 — `feat(chat): show and choose where a chat runs`

- [ ] 6.1 Wire the row above the composer in `ChatScreen`'s new-chat welcome, the header line and details sheet for an open chat, and the picker through `showAdaptiveSheet` (a dialog on wide layouts and the Mac, a sheet on compact widths including a compact iPad window). Conversation windows get the line and details only. The quick panel shows none.
- [ ] 6.2 Make the folder section headers and the header line use one label function; add a test of the function (same rule, own path, disambiguated basenames) and that a moved chat regroups with selection kept, including a move answer with `git_repo_root: null`.
- [ ] 6.3 Add a workflow test in `test/workflows/` (phone and desktop, light and dark): new chat, pick a project, send, see the folder in the header, move the chat, see the regrouped list; and an old-server run where the row and picker are absent. Look at the screenshots.
- [ ] 6.4 Update `docs/architecture/chat.md` (a **Working directory** paragraph: the row, catalog loader, picker sources, `cwd_explicit`, the mismatch notice, the move, hiding on old servers, no stored paths) and the `verify-in-app` skill (making a project and a repo in the dev backend's `HERMES_HOME`, and `HERMES_DASHBOARD_FILES_ROOT`).
- [ ] 6.5 Run format, analyze and test, all passing.

## 7. PR 7 — `feat(macos): folder button and Change Folder menu`

- [ ] 7.1 Add the Mac toolbar button on `MacToolbar` and `ThreadAction.changeFolder` ("Change Folder…") to the thread and sidebar row menus, shown only while allowed; widget tests and a Mac layout check in the workflow test.
- [ ] 7.2 Run format, analyze and test, all passing.

## Not verified on a device

Run after the PRs merge; note in each PR which were done.

- 8.1 `verify-in-app` on macOS against a throwaway backend with a project of two folders and two repos: picker shows them, a pick starts the chat in that folder (`GET /api/sessions` shows its `cwd`), the header matches, Browse and Type work, the mismatch notice appears when the picked folder is removed between pick and send, and a move shows in the list.
- 8.2 Confirm on a live backend that a chat moved with `session.workspace.move` and then resumed runs its next turn in the new folder, and that one created with no `cwd` stores the launch directory (source `hermes_app`).
- 8.3 With `HERMES_DASHBOARD_FILES_ROOT` set, Browse hides itself and Type and projects still work.
- 8.4 A profile with its own `terminal.cwd`: a pick wins (`cwd_explicit`), the default row shows the profile's folder.
- 8.5 iPhone and Android: sheet, large text, VoiceOver and TalkBack reading of the row and picker, keyboard on iPad, Mac dialog keyboard flow, reduced motion.
