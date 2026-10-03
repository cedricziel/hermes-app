## 1. Repository

- [ ] 1.1 Failing test in `test/hermes_chat_repository_test.dart` for `searchThreads` against the fake server (query parameters, row parsing, snippet markers, skipped rows)
- [ ] 1.2 Implement `ThreadSearchHit` and `HermesChatRepository.searchThreads`
- [ ] 1.3 Real-backend contract case in `test/real_backend_contract_test.dart` for the search row shape

## 2. Search state

- [ ] 2.1 Failing tests for `ThreadSearch`: debounce, stale replies dropped, failure, clear
- [ ] 2.2 Implement `ThreadSearch`, owned by `ChatController` and cleared on profile switch

## 3. Widgets (catalog first)

- [ ] 3.1 `ThreadSearchField` and `ThreadSearchResults` with Widgetbook use cases (results, loading, no match, failed), both themes, phone and desktop
- [ ] 3.2 Show the field in `ThreadSidebar` and the results in place of the list while the query is not blank
- [ ] 3.3 Failing widget test, then wire `ChatScreen`: typing searches, tapping a result outside the loaded pages opens it

## 4. Docs

- [ ] 4.1 Update CLAUDE.md's chat section; no telemetry to add; no skill goes stale

## 5. Verify

- [ ] 5.1 `dart format .`, `flutter analyze`, `flutter test`, workflow screenshots of the sidebar; no verify-in-app run (no backend started for this task)
