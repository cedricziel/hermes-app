# Tasks

Four PRs, each under about 500 changed lines with tests, merged in order. Each ends with its own check. The Claude Design pass (task 2.1) happens between PR 1 and the Widgetbook work in PR 2, from `docs/design-briefs/server-files.md`.

## 1. PR 1 — `feat(files): read a chat's working folder from the server`

- [ ] 1.1 Record fixtures against `scripts/dev-backend.sh` (rules of `verify-in-app`; never the real `~/.hermes`) on Hermes `d923a5eb`: `fs/list` (folders and files, a symlink to a folder, an empty folder, a missing folder 200 with `error`, a file path 200 with `ENOTDIR`), `fs/read-text` (text, truncated, binary, 400 directory, 403 `.env`, 404), `fs/default-cwd`, `fs/git-root` (inside and outside a repo), `fs/download` headers (`Content-Length`, `Content-Disposition`) and a 404 from a server without the routes. Add them to `test/real_backend_contract_test.dart` (skips without `HERMES_DEV_URL`) and as JSON under `test/fixtures/`, with the revision noted.
- [ ] 1.2 Write failing tests, then implement `ServerPath` (`lib/src/files/server_path.dart`): POSIX, Windows drive and UNC styles, `segments`, `parent`, `name`, `isWithin` by components (`/srv/app` vs `/srv/app-secrets`, trailing separators, case on Windows drives), no join.
- [ ] 1.3 Write failing tests, then implement `SecretNames` and `isHidden` (pure functions) for every name in the spec, case-insensitively, including `.ssh/` path components.
- [ ] 1.4 Write failing `HermesFilesRepository` tests against `FakeHermesServer`: lenient parsing (entry without name or path skipped, `isDirectory` missing, non-object body), 200-with-`error` mapped to failure kinds, every status mapped to its kind, `defaultCwd` 404 or 405 is `FilesUnsupported` and a timeout is not, `profile` sent on every call, no `token` in any query, no request outside the highest folder. Then implement it on `authController.api!.raw`.
- [ ] 1.5 Write failing tests, then add `HermesApiClient.downloadFsFile` (stream to a sink, `CancelToken`, progress with unknown total, idle timeout, header read before body) and `MediaStore.stageDownload` (`.part` renamed on success, deleted on error and cancel, one in-flight download per key, safe name, `clear()` and the sweep cover it).
- [ ] 1.6 Write failing tests that `files.list`, `files.preview`, `files.download` spans and `files.unsupported`, `files.list_failed`, `files.download_failed` carry only their fixed attributes and buckets. Then add them.
- [ ] 1.7 Run `/simplify`, then `dart format --output=none --set-exit-if-changed .`, `flutter analyze` and `flutter test`, all passing.

## 2. PR 2 — `feat(files): browser and preview widgets and controller`

- [ ] 2.1 Claude Design pass from `docs/design-briefs/server-files.md`; the result lands as Widgetbook use cases (task 2.2), not as a separate artifact.
- [ ] 2.2 Add Widgetbook use cases as plain-model widgets in `lib/src/files/widgets/`: `FilesBrowserView` (loading, list, empty, empty with hidden files, error kinds, locked deployment, offline, long names, 2,000-row cap note), `FileRow` (folder, file, secret, selected, focused), the path bar, `FilePreviewView` for text, Markdown (rendered and source), code (plain until 4.1), image, PDF, other file, truncated text, size question, secret question, downloading (with and without total), failed. Both themes, phone, iPad and desktop width, largest text size.
- [ ] 2.3 Write failing `FilesController` tests with a fake repository: start folder from `cwd` or `default-cwd`; highest folder from `git-root`; Up disabled at the top; symlink-to-folder retry; late answers dropped by folder, file, profile and connection generation; hidden toggle; secret question before any request; size question at 50 MB from headers and none when the length is unknown; cancel deletes the partial file; Reload restages; profile switch and dispose cancel everything. Then implement it.
- [ ] 2.4 Write failing widget tests for every user-visible string in the spec and the screen-reader labels, and make them pass.
- [ ] 2.5 Run `/simplify`, then format, analyze and test.

## 3. PR 3 — `feat(files): open Files from a chat`

- [ ] 3.1 Add `FilesAvailability` (connection-scoped, from the first `default-cwd`) and the single `openFiles(context, chat)`; provide them where `ChatScreen` can reach them.
- [ ] 3.2 Write failing tests, then wire the entry points: the "Files" row under "This session" in `BoundActivityPanel` (value: folder name), the chat header's menu item, and the Mac View > Show Files command in `menu_layout.dart` with a free chord (check against the existing list) offered by `ChatScreen`'s `MacCommandScope`, including a conversation window's chat. None is shown on an old server.
- [ ] 3.3 Build the page on `SettingsScaffold`: phone (list, preview pushed), iPad at 700 pt and desktop at 900 pt (list beside preview), Mac toolbar (back, path bar, Refresh, Show hidden files) and keyboard navigation. Close it on profile switch, another chat, sign-out, server change and App Lock; close the Quick Look panel it opened on lock.
- [ ] 3.4 Reuse the existing actions: Save, Share, Open with…, Quick Look targets on rows and the preview file, `DragOut` of a staged file (`DragOutKind.file`), the image viewer for images.
- [ ] 3.5 Add a workflow test (`test/workflows/`) on phone and desktop, light and dark: open Files, enter a folder, preview text, image, other file, secret question, empty folder, error. Look at the screenshots (`workflow-screenshots` skill).
- [ ] 3.6 Add breadcrumbs `files.opened`, `files.preview.opened`, `files.saved`, `files.secret.warned`, `files.hidden.toggled` with tests that they carry no path or name.
- [ ] 3.7 Update `CLAUDE.md` (a "Server files" paragraph: the two route families and which the app uses, the highest folder, streaming through `MediaStore.stageDownload`, secrets), the `verify-in-app` skill (a throwaway folder with a `.env`, a symlink, a 60 MB file and an image), `design/web` if it mirrors the Activity panel, and the `docs/` architecture area file if it exists on main. Then format, analyze and test.

## 4. PR 4 — `feat(files): code colours and Markdown polish`

- [ ] 4.1 Compare the syntax highlighters (`re_highlight`, `flutter_highlight`, `highlight`, and `gpt_markdown`'s own code block) on the repo's pub.dev rule: recent releases, publisher, platform coverage, popularity, open issues, size, and light and dark themes that meet AA contrast. Record the choice and the reason in the PR; if none fits, ship plain monospace and say why.
- [ ] 4.2 Write failing tests, then add `CodePreview` using the server's `language` name, an unknown name falling back to plain text, and a size guard (no highlighting above the 512 KB the server sends; highlighting runs off the UI isolate when it exceeds a frame). Update the Widgetbook use cases.
- [ ] 4.3 Run `/simplify`, then format, analyze and test.

## Not verified on a device

These need a device or simulator and a running Hermes, and are listed after the code tasks.

- 5.1 `verify-in-app` on macOS against `scripts/dev-backend.sh`: browse a project folder, a `.env` asks, a symlinked folder opens, a 60 MB file asks and cancels leaving no partial file in the cache, Quick Look on Space, drag a file into Finder, Save, hidden files toggle.
- 5.2 iPhone and iPad simulator: list then preview push, list beside preview on iPad at 700 pt, Share sheet, PDF in Quick Look, App Lock closing the preview, largest text size and VoiceOver reading of rows.
- 5.3 Android emulator: Save dialog, Open with… for a PDF and an archive, back gesture from preview to list, TalkBack.
- 5.4 A profile whose terminal is an SSH workspace (a second container): the folder shown is the SSH machine's, the download shows an indeterminate progress, and a `.env` there still asks before it is read.
- 5.5 A server older than `/api/fs` (or a stub answering 404): no Files row, no menu item, no error.
- 5.6 A locked deployment (`HERMES_DASHBOARD_FILES_ROOT` set to a folder that excludes the chat's folder): the page shows "Hermes only shares files from a fixed folder on this server."
