# Tasks

Two PRs, each under about 500 changed lines.

## 1. PR 1 - `feat(chat): fetch a session export`

- [ ] 1.1 Record fixtures against `scripts/dev-backend.sh` (rules of `verify-in-app`; never the real `~/.hermes`) on Hermes `d923a5eb`: a short chat, a chat with tool calls and reasoning, a rewound or compacted chat (rows with `active` 0 and `compacted` 1), a prefix id, an unknown id (404 `Session not found`), an unknown profile (404) and a bad one (400); keep the response headers (expect no `Content-Length`, no `Content-Disposition`). Add them to `test/real_backend_contract_test.dart` (skips without `HERMES_DEV_URL`) and as JSON under `test/fixtures/`, with the revision noted.
- [ ] 1.2 Write failing tests against `FakeHermesServer`, then add `HermesApiClient.fetchSessionExport(id, {profile})` on `_getBytes` (id percent-encoded; `profile` always sent when given).
- [ ] 1.3 Write failing tests, then implement `SessionExportController` (one run at a time): complete body decodes (root object, string `id`, list `messages`; isolate above 1 MB), truncated body and dropped connection are `incomplete`, 404 `Session not found` is `gone`, 404 `Profile '...` is `profile`, 400 is `profile` (invalid name), any other 404 or 405 is `unsupported`, a decode `FormatException` is caught and becomes `incomplete` with no message or body passed on (test: a body with a marker string never reaches the crash reporter, log or error text), 503 `unreadable`, timeout is `lost` (nothing resent), offline, cancel, profile or server change, sign-out and App Lock drop the bytes. The saved bytes equal the received bytes. No request carries a missing profile.
- [ ] 1.4 Write failing tests that the span `session_export.fetch`, the event `session_export.failed` and the breadcrumbs carry only fixed names, outcomes and buckets (no title, id, profile, name, path or content), then add them.
- [ ] 1.5 Run `/simplify`, then `dart format --output=none --set-exit-if-changed .`, `flutter analyze` and `flutter test`.

## 2. PR 2 - `feat(chat): Export chat as JSON`

- [ ] 2.1 Claude Design pass from the proposal's "Design pass" list, before the widgets.
- [ ] 2.2 Build plain-model widgets in `lib/src/chat/widgets/` (confirmation, progress, failure message), with Widgetbook use cases in `widgetbook/` before any screen uses them (`component-catalog` skill): both themes, phone and desktop width, largest text, every failure of 1.3, Cancel the default button. `flutter test test/widgetbook_test.dart` passes.
- [ ] 2.3 Add every string to `lib/l10n/arb/app_en.arb` and `app_de.arb` under `@@x-area-chat`, run `flutter gen-l10n`, read with `context.l10n`.
- [ ] 2.4 Write failing tests, then add `ThreadAction.exportJson` to `runThreadAction`, the menus (`ThreadActionsButton`, `macThreadMenuItems`, `mac_chat_toolbar.dart`, `conversation_windows_menu.dart`), `MacCommand.exportThread` in `menu_layout.dart` and the handler in `chat_screen_navigation.dart`; hidden for local chats and chats without a profile; saved through `MediaActions.save` with the `.json` name rules; snack bar on save, silence on cancel.
- [ ] 2.5 Add a workflow test (`test/workflows/`) on phone and desktop, light and dark: menu, confirmation, progress, saved, one failure. Look at the screenshots (`workflow-screenshots` skill).
- [ ] 2.6 Check with `verify-in-app` on macOS against a throwaway backend: the save panel opens with the name, the file equals the response.
- [ ] 2.7 Update `docs/architecture/chat.md` (the export action, the byte fetch, the one-session limit) and `docs/architecture/macos.md` (the menu command), and the `verify-in-app` skill if it lists the save check. Then format, analyze and test.

- [ ] 2.8 Because `fetchSessionExport` is hand-written, update `CLAUDE.md` "Two API layers" (the hand-written list gains the session export download, with the reason: the generated method decodes the body as JSON) and `docs/architecture/chat.md` (or the API doc it points to). Not edited by this proposal.

## Not verified

The real response headers and body; very large exports (memory in the app); image parts in `content`; the 404 text of older servers; `saveFile` with bytes on a physical iPhone, on Android and in the macOS sandbox; whether every listed chat has a profile.
