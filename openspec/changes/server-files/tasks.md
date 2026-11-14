# Tasks

Four PRs, each under about 500 changed lines with tests, merged in order. Each ends with its own check. The Claude Design pass (task 2.1) happens between PR 1 and the Widgetbook work in PR 2, from `docs/design-briefs/server-files.md`.

## 1. PR 1 — `feat(files): read a chat's working folder from the server`

If PR 1 passes about 500 lines, split it after 1.4 (repository) and 1.5 (streaming).

- [ ] 1.1 Record fixtures against `scripts/dev-backend.sh` (rules of `verify-in-app`; never the real `~/.hermes`) on Hermes `d923a5eb`: `fs/list` (folders and files, a symlink to a folder, an empty folder, a missing folder 200 with `error`, a file path 200 with `ENOTDIR`), `fs/read-text` (text, truncated, binary, 400 directory, 403 `.env`, 404), `fs/default-cwd`, `fs/git-root` (inside and outside a repo), `fs/download` headers (`Content-Length`, `Content-Disposition`) and a 404 from a server without the routes. Add them to `test/real_backend_contract_test.dart` (skips without `HERMES_DEV_URL`) and as JSON under `test/fixtures/`, with the revision noted.
- [ ] 1.2 Write failing tests, then implement `ServerPath` (`lib/src/files/server_path.dart`): POSIX, Windows drive and UNC styles, `segments`, `parent`, `name`, `isWithin` by components (`/srv/app` vs `/srv/app-secrets`, trailing separators, case on Windows drives), no join.
- [ ] 1.3 Write failing tests, then implement `SecretNames` and `isHidden` (pure functions) for every name in the spec, case-insensitively, including `.ssh/` path components.
- [ ] 1.4 Write failing `HermesFilesRepository` tests against `FakeHermesServer`: lenient parsing (entry without name or path skipped, `isDirectory` missing, non-object body), 200-with-`error` mapped to failure kinds, every status mapped to its kind, `defaultCwd` 404 or 405 is `FilesUnsupported` and a timeout is not, `profile` sent on every call, no `token` in any query, no request outside the highest folder. Then implement it on `authController.api!.raw`.
- [ ] 1.4a Add `cwd` to the chat repository's row parsing and `ChatThread` (tests with a row holding both `cwd` and `git_repo_root`).
- [ ] 1.5 Write failing tests, then add a path-based `MediaStore.saveFile(name, File)` and `HermesApiClient.downloadFsFile` (stream to a sink, `CancelToken`, progress with unknown total, idle timeout, header read before body) and `MediaStore.stageDownload` (`.part` renamed on success, deleted on error and cancel, one in-flight download per key, safe name, `clear()` and the sweep cover it).
- [ ] 1.6 Write failing tests that `files.list` and `files.download` spans and `files.unsupported`, `files.list_failed`, `files.download_failed` carry only their fixed attributes and buckets, then add them (`files.preview` follows with its caller in PR 2).
- [ ] 1.7 Run `/simplify`, then `dart format --output=none --set-exit-if-changed .`, `flutter analyze` and `flutter test`, all passing.

## 2. PR 2 — `feat(files): browser and preview widgets and controller`

- [x] 2.1 Claude Design pass: https://claude.ai/artifact/LdWtNMYN1ZhCzZwDJCHXYg; decisions, corrections and added copy in the brief's "Design (done)" section, which the widgets below follow.
- [ ] 2.2 Build these plain-model widgets in `lib/src/files/widgets/` (models and callbacks only, no controller or repository), each with Widgetbook use cases in `widgetbook/files_use_cases.dart` before any screen uses it, in both themes, at phone, iPad and desktop width, with Apple and Material chrome and at the largest text size. Verify `flutter test test/widgetbook_test.dart` passes.
  - `FilePathBar` (new; nothing in `lib/src` draws a breadcrumb; its Up button is a `NamedIconButton`, its metrics come from `GroupedMetrics`): one segment (highest folder), three segments, a long segment elided in the middle, a long path showing its end with the start faded, the Up button enabled and disabled (wide only), Mac 28 pt targets, largest text (scrolls).
  - `FileRow` (on `GroupedMetrics` and the `GroupedSection` row look; not `GroupedRow`, which cuts the title to one line and has no inline glyph after it; on the Mac the screen wraps it in `QuickLookTarget` and `DragOut`): folder, text, code, image, PDF, archive, generic file, secret-looking file (lock and "May contain secrets"), a two-line name elided in the middle, selected (wide), focused (Mac), each with its screen-reader label.
  - `FilesBrowserView` (on `GroupedListView`, `GroupedSection`, `StateMessage` and `McpBanner` for the offline banner): list, nested, loading (still skeleton rows, reusing Server care's `LoadingSkeleton` when it has landed, and "Loading folder…"), empty, empty with hidden files, hidden files shown, long names, the 2,000-row footer, the server's folder note, unreachable, offline with a stale list, gone (Up; Try again at the top), no permission, fixed-folder server, workspace down, link outside, and the empty wide pane ("Select a file to preview it.").
  - The shared neutral note: use the one planned as `ActivityInfoNote` for "Working folder of the server" and "Showing the first 512 KB of 3.2 MB." (with Download full file). If it has not landed, build it once in `lib/src/widgets/` under that name, not inside `files/`.
  - `FilePreviewHeader` (new, on `NamedIconButton`; the Mac tile is the `DragOut` handle): name on one and two lines, with and without a size, iPad actions (Share, Save, …) and Mac actions (Quick Look, Save, …).
  - `FilePreviewView` with `TextPreview`, `CodePreview` (plain until 4.1, then the `--h-code-*` palette from a new `HermesCodeColors` theme extension), `MarkdownPreview` (rendered and source, on `gpt_markdown` as `skill_markdown_panel.dart` and the chat use it) and `ImagePreview` (on `image_viewer.dart`'s pinch and pan, checkerboard inside the picture only): text, code, Markdown both views, image, truncated text with its note, SVG as source.
  - `FileDetailsView` (new, laid out like `StateMessage` with `Button`s): PDF (Open), other file (Save with Share on phones and Open with… on Android and desktop; Save and Share on iPhone), too large (the note line, Save), saved (with the snack bar), cancelled (same as other file).
  - `FileDownloadProgress` (on `BusyBar`): with a length ("Downloading… 14 of 30 MB"), without ("Downloaded 12 MB", spinner), reduced motion.
  - File failures as `StateMessage`: not shared, gone, busy (Try again), not a file, couldn't open (Try again), incomplete (Try again).
  - The questions, as use cases of the existing helpers: the size question through `showAdaptiveSheet` (phone sheet, Download filled) and `showConfirmDialog` (iPad and Mac alert, Download the default); the secret question through `showConfirmDialog` (Cancel the default; Material with two text buttons, Cancel first).
- [ ] 2.3 Write failing `FilesController` tests with a fake repository: start folder from `cwd` or `default-cwd`; highest folder from `git-root`; Up disabled at the top; symlink-to-folder retry; late answers dropped by folder, file, profile and connection generation; the server-resolved highest folder (`/tmp` vs `/private/tmp`); the local-only symlink retry and the SSH 400 variant; the SSH empty-body and short-body failures; 413 offering Save; hidden toggle; secret question before any request; size question at 50 MB from headers and none when the length is unknown; cancel deletes the partial file; Reload restages; profile switch and dispose cancel everything. Then implement it.
- [ ] 2.4 Write failing widget tests for every user-visible string in the spec and the screen-reader labels, and make them pass.
- [ ] 2.5 Run `/simplify`, then format, analyze and test.

## 3. PR 3 — `feat(files): open Files from a chat`

- [ ] 3.1 Add `FilesAvailability` (connection-scoped, from the first `default-cwd`) and the single `openFiles(context, chat)`; provide them where `ChatScreen` can reach them.
- [ ] 3.2 Write failing tests, then wire the entry points: the "Files" row under "This session" in `BoundActivityPanel` (value: folder name), the chat header's menu item, and the Mac View > Show Files command in `menu_layout.dart` with the chord ⇧⌘F (chosen in the design pass; check it is still free) offered by `ChatScreen`'s `MacCommandScope`, including a conversation window's chat. None is shown on an old server.
- [ ] 3.3 (split into its own PR 3b if 3.1 to 3.6 pass about 500 lines; also file a `mac-quick-look` spec delta: the panel closes on App Lock) Build the page on `SettingsScaffold`: phone (list, preview pushed), iPad at 700 pt and desktop at 900 pt (list beside preview), Mac toolbar (back, Refresh, … menu with Show hidden files), the path bar in a strip under it, and keyboard navigation. Close it on profile switch, another chat, sign-out, server change and App Lock; close the Quick Look panel it opened on lock.
- [ ] 3.4 Add `share_plus` (pub.dev rule, iOS and Android) and reuse the existing actions: Save through `saveFile`, Open with…, Quick Look targets on rows and the preview file, `DragOut` of a staged file (`DragOutKind.file`), the image viewer for images.
- [ ] 3.5 Add a workflow test (`test/workflows/`) on phone and desktop, light and dark: open Files, enter a folder, preview text, image, other file, secret question, empty folder, error. Look at the screenshots (`workflow-screenshots` skill).
- [ ] 3.6 Add breadcrumbs `files.opened`, `files.preview.opened`, `files.saved`, `files.secret.warned`, `files.hidden.toggled` with tests that they carry no path or name.
- [ ] 3.7 Update `CLAUDE.md` (a "Server files" paragraph: the two route families and which the app uses, the highest folder, streaming through `MediaStore.stageDownload`, secrets), the `verify-in-app` skill (a throwaway folder with a `.env`, a symlink, a 60 MB file and an image), `design/web` if it mirrors the Activity panel, and `docs/architecture/chat.md` (the chat and media paragraphs) plus `gateway.md` if the transport is touched. Then format, analyze and test.

## 4. PR 4 — `feat(files): code colours and Markdown polish`

- [ ] 4.1 Compare the syntax highlighters (`re_highlight`, `flutter_highlight`, `highlight`, and `gpt_markdown`'s own code block) on the repo's pub.dev rule: recent releases, publisher, platform coverage, popularity, open issues, size, and light and dark themes that meet AA contrast. Record the choice and the reason in the PR; if none fits, ship plain monospace and say why.
- [ ] 4.2 Write failing tests, then add `CodePreview` using the server's `language` name, an unknown name falling back to plain text, and a size guard (no highlighting above the 512 KB the server sends; highlighting runs off the UI isolate when it exceeds a frame). Update the Widgetbook use cases.
- [ ] 4.3 Run `/simplify`, then format, analyze and test.

## Not verified on a device

These need a device or simulator and a running Hermes, and are listed after the code tasks.

- 5.1 `verify-in-app` on macOS against `scripts/dev-backend.sh`: browse a project folder, a `.env` asks, a symlinked folder opens, a 60 MB file asks and cancels leaving no partial file in the cache, Quick Look on Space, drag a file into Finder, Save, hidden files toggle.
- 5.2 iPhone and iPad simulator: list then preview push, list beside preview on iPad at 700 pt, Share sheet, PDF in Quick Look, App Lock closing the preview, largest text size and VoiceOver reading of rows.
- 5.3 Android emulator: Save dialog, Open with… for a PDF and an archive, back gesture from preview to list, TalkBack.
- 5.4 A profile whose terminal is an SSH workspace (a second container): the folder shown is the SSH machine's, the download shows an indeterminate progress, a `.env` there still asks before it is read, a symlinked folder lists as a folder, and an unreadable file fails instead of caching an empty file.
- 5.7 macOS with `/tmp` as the chat's folder (resolves to `/private/tmp`): entries are shown.
- 5.5 A server older than `/api/fs` (or a stub answering 404): no Files row, no menu item, no error.
- 5.6 A locked deployment (`HERMES_DASHBOARD_FILES_ROOT` set to a folder that excludes the chat's folder): the page shows "Hermes only shares files from a fixed folder on this server."
