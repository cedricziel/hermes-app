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
- [ ] 2.2 Write failing `ChatController` tests in a new `chat_controller_workspace.dart` part: the draft choice lives on the new thread and is cleared on profile switch, sign-out and creation; `WorkspaceBound` sets `workingDirectory`/`branch`; a differing reported folder adds the one-time notice and logs `workspace.cwd_mismatch` with no path; `moveWorkspace` (through the repository) sends once, updates `workingDirectory` and `folderPath`, regroups with selection kept, refuses while replying, for a Bot Chat registry and for an unopened other-profile chat, rejects a path that is not `/` or `~`-led, handles 4017, 5007, unsupported (hides the action for the connection) and a lost answer (re-read of `GET /api/sessions/{id}`, no resend; with no re-read answer after 10 s on a fake clock the state is "could not confirm", the move action is offered again and nothing was resent). Implement them.
- [ ] 2.3 Add `WorkspaceCatalogLoader` (one per new-chat recipient profile, kept while the welcome view shows, cleared on profile switch, sign-out and Change Server; loading, ready, failed, unsupported, offline, and a loading that has had no answer for 10 s, which the row shows as "Runs in the server's default folder") with tests, and use it from the controller for the row's default folder and project tag.
- [ ] 2.4 Run format, analyze and test, all passing.

## 3. PR 3 — `feat(workspaces): folder picker controller and telemetry`

- [ ] 3.1 Write failing `WorkspacePickerController` tests: loading, ready, partial (catalog failed, browse works), failed, unsupported, offline, rescan only when `scan_enabled`; ordering and de-duplication (a repo under a project folder is not in Recent); search filtering above eight rows; browse stack with the first-read boundary 403 hiding Browse and a later 403 staying per level; typed suggestions keep only the latest answer and never accept a relative path; a profile change closes it; late answers after dispose are dropped; selection; with a fake clock, each wait ends after 10 s without a resend (catalog loading becomes the partial failure, a browse level becomes "Couldn't open" with retry, a typed-path check becomes "Couldn't check" with the action disabled, a scan ends with the list unchanged) and a late answer afterwards still applies; a later-level 403 with the boundary detail is "outside" with Use disabled, any other 403 or `EACCES` is "not allowed" with Use enabled; in a move the current folder is marked and added to the top of Projects (or Recent) when no list holds it. Implement it on top of the catalog loader.
- [ ] 3.2 Add the telemetry (`workspace.picker.opened`, `workspace.chosen`, `workspace.move.confirmed`, spans `workspace.list` and `workspace.move`, events `workspace.move_outcome`, `workspace.cwd_mismatch`) with a test per record that no path, name, branch or profile appears in any attribute.
- [ ] 3.3 Write failing tests that sign-out, Change Server and App Lock clear the draft choice and catalog and close an open picker or confirmation, and that no path reaches shared preferences, the surface snapshot, Spotlight or notification payloads. Implement them.
- [ ] 3.4 Run format, analyze and test, all passing.

## 4. Gate: Claude Design pass

- [x] 4.1 Claude Design pass: https://claude.ai/artifact/JypA8yLhwweV9b6uZA2jpp; decisions, corrections and added copy in the brief's "Design (done)" section and design.md's "Design pass (decided)", which the widgets below follow. PR 5's use cases follow the canvas.

## 5. PR 5 — `feat(workspaces): folder row, picker and confirmation widgets`

- [ ] 5.1 Build these plain-model widgets in `lib/src/workspaces/widgets/` (models and callbacks only, no controller or repository), each with Widgetbook use cases in `widgetbook/workspaces_use_cases.dart` before any screen uses it, in both themes, at phone, iPad and desktop width, with Apple and Material chrome, and at 2.0 text scale plus the largest accessibility size (no cap). Reuse the shared widgets other wave 4 changes add rather than a second copy: the shared `Banner` (moved from `McpBanner`, with its neutral tone), `LoadingSkeleton`, `StateMessage`, `GroupedChoiceRow` and `showConfirmDialog`; whichever change lands first adds them. Verify `flutter test test/widgetbook_test.dart` passes.
  - `WorkingDirectoryRow` (new; builds on the composer column, `AppIcons.folder` (new, `Icons.folder_outlined` / `CupertinoIcons.folder`) and `AppIcons.branch`, `Tag`, `Spinner`, `LoadingSkeleton`): use cases server default, project picked, recent folder without branch, home folder, looking up, looked up too long (server-default wording), offline, long names, Mac density.
  - `WorkingDirectoryLine` (new; a subtitle slot added to `ChatHeader` on touch and Material, today Mac-only): folder and branch, folder only, offline, and its accessibility-size form, a full-width row under the bar.
  - `WorkingDirectoryDetails` (new; builds on `showAdaptiveSheet`, `GroupedSection`, `GroupedRow` and its warning line, `Banner`, an outlined `Button`, and `ServerPathText`): normal, home folder, replying, offline, old server (no button), conversation window, changing, changed, refused, server error, lost answer checking, could not confirm, path selected (desktop).
  - `ServerPathText` (new; tokens only): monospace path plus "· on your server", middle-truncated on one line or wrapped in full, selectable on the desktop. Use cases: short, long, wrapped, largest text.
  - `WorkspacePickerView` (new; builds on `SettingsScaffold` in `showAdaptiveSheet`, `GroupedChoiceRow`, `GroupedRow`, `SettingsSearchField`, `StateMessage`, `Banner`, `BusyBar`, `LoadingSkeleton`, the bar's More menu): ready, more than eight rows, search, no match, loading, empty, projects failed, offline, unknown profile, browsing locked, More menu, scanning, found, nothing new, scan too slow, move with Current.
  - `FolderBrowserView` (new; builds on `SettingsScaffold`, `FolderBreadcrumb`, `GroupedRow`, `StateMessage`, `LoadingSkeleton`, a filled `Button`): a level, `/`, opening, empty, not allowed, outside the boundary, missing, connection lost.
  - `FolderBreadcrumb` (new; tokens and text buttons): full path on wide layouts, collapsed "… / me / code" on a phone, the current segment bold, 44 pt (Mac 28 pt) targets.
  - `PathEntryView` (new; builds on `TextField` (monospace), `GroupedRow`, `Spinner`): suggestions, relative path, checking, check too slow, missing, not allowed, 30 suggestions, no suggestions, server cannot check, found.
  - `ChangeFolderConfirmation` (builds on `showConfirmDialog`): Apple, Material, Mac, largest text.
  - `FolderMismatchNotice` (new; tokens, `AppIcons.warning`, a text `Button`): default, dark, largest text.
  - `FolderToolbarButton` (new; the Mac toolbar's button style with a title, since `MacToolbarButton` is icon-only): new chat, open chat, long name, disabled.
  - `ThreadSectionHeading` (change): a folder label that is a path is cut in the middle.
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
