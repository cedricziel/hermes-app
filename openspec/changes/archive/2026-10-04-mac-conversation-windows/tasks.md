## 1. Token hand-off

- [x] 1.1 Failing tests: `AuthController.windowAuthHeaders` returns the current bearer, refreshes once for concurrent callers that name the current token, returns the current token without refreshing for a stale one, and hands out the page token on an ungated server
- [x] 1.2 Failing tests: `WindowAuthInterceptor` applies the main window's headers, retries a 401 once with the headers asked for again, never calls a token route
- [x] 1.3 Implement both

## 2. Registry and restoration

- [x] 2.1 Failing tests for `ConversationWindows`: open, focus instead of a duplicate, removal on close, key window, title updates, persistence, restore for the current server only, close-all on sign-out
- [x] 2.2 Implement the registry, the store and the desktop_multi_window host

## 3. Conversation view (catalog first)

- [x] 3.1 `ConversationWindowToolbar` with Widgetbook use cases (pinned, unpinned, long title, no model), both themes
- [x] 3.2 Pull `ChatThreadView` out of `chat_screen.dart`
- [x] 3.3 `ChatController.refreshThread`, with tests
- [x] 3.4 `ConversationWindowScreen` with a widget test against the fake server

## 4. Native and wiring

- [x] 4.1 Swift: main window survives close, sub-window chrome, per-window channel, selective plugins, Dock reopen
- [x] 4.2 Sub-window entry point in `main.dart`
- [x] 4.3 Sidebar double-click and "Open in New Window", main window refresh on focus, restore on sign-in
- [x] 4.4 Menu bar hooks: `mac_commands.dart` had not landed; noted in the PR for whichever lands second

## 5. Verify and docs

- [x] 5.1 Verify in the macOS app: two profiles side by side, one message, relaunch restores
- [x] 5.2 CLAUDE.md architecture note; sync the delta spec and archive the change
