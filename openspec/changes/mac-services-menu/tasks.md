# Tasks

One PR, `feat(macos): add an Ask Hermes entry to the Services menu`, roughly 300 lines. No API routes change, so no OpenAPI regeneration.

## 1. Dart: the quote item

- [x] 1.1 Write failing tests in `test/macos_share_inbox_test.dart` that an entry `{type: text, text, intent: ask}` becomes a `SharedQuote`, that an unknown intent or an empty text stays `SharedText` or is skipped, and that a `{type: dropped}` entry yields no item; add `SharedQuote` to `lib/src/share/shared_item.dart` and parse it in `MacosShareInbox`; verify the tests pass.
- [x] 1.2 Write a failing test that `ShareController` holds a quote through setup and login like other items and that the latest of several quotes wins; add `ShareController.discardQuotes()` and call it on sign-out, with a failing test first; verify.

## 2. Chat screen

- [x] 2.1 Write failing widget tests (`FakeChatTransport`, in `test/chat_screen_quote_test.dart`) that a quote starts a new thread, fills the composer as a block quote with an empty line and the cursor at the end, focuses it, sends nothing, keeps an existing draft above the quote, and ends a long quote with the shortened line; implement in `ChatScreen._absorbShared` through `_newThread`; verify.
- [x] 2.2 Write a failing test that a quote held while the shell was covered by app lock is in the composer after unlock, and that a conversation window's chat is untouched (nothing in Dart touches a conversation window; the quote goes to the main window's `ChatScreen` only, so only the lock case has a test); verify.

## 3. Native macOS

- [x] 3.1 Write a failing Swift test in `macos/RunnerTests/RunnerTests.swift` for the provider: text from a pasteboard is queued once with `intent: ask`, whitespace-only or non-text input is dropped with an error and a `dropped` entry, text over 20,000 characters is cut and flagged, and `takeQueued()` clears the queue.
- [x] 3.2 Add `macos/Runner/AskHermesService.swift` (selector `askHermes(_:userData:error:)`, in-memory queue, window show closure), add it to the Runner target in `project.pbxproj`, add `NSServices` to `macos/Runner/Info.plist`, set `NSApp.servicesProvider` in `applicationWillFinishLaunching` with `NSUpdateDynamicServices()`, and merge `takeQueued()` into the `take` handler and send `shared` in `AppDelegate`; verify the Swift test passes and `flutter build macos` succeeds. Restore the tracked Xcode files the build rewrites except `project.pbxproj` for this change.
- [ ] 3.3 Bring the main window forward in each state (hidden, closed with a conversation window open, minimized); verify with the manual check in 5.2.

## 4. Telemetry

- [x] 4.1 Write failing tests with a recording `Breadcrumbs` trail that `service.ask.received` (`launched`, `truncated`), `service.ask.dropped` (`reason`) and `chat.share.quote` (`held`) are recorded and that no crumb contains the text or its length; add them in `MacosShareInbox` and `ChatScreen`; verify.

## 5. Docs, skills and verification

- [x] 5.1 Update CLAUDE.md (the Sharing paragraph in Architecture and "Native pieces": the Services provider and `SharedQuote`) and `openspec/specs` is synced on archive, not here.
- [x] 5.2 Add a section to `.claude/skills/verify-in-app/SKILL.md` for the service: refresh the list with `/System/Library/CoreServices/pbs -update`, invoke it without clicking through apps by putting text on a pasteboard and calling `NSPerformService("Ask Hermes", pboard)` from a short script, check cold start, signed out, locked, main window closed and a conversation window key, and note the dev/release duplicate entry. Use the isolated backend only.
- [ ] 5.3 Run `openspec validate mac-services-menu --strict`, `dart format .`, `flutter analyze`, `flutter test`; run the verify-in-app check on macOS for each spec scenario and confirm no file in the App Group container holds the selection.
