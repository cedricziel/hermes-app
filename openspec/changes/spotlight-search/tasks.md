# Tasks

One PR, `feat(ios): index recent chats in Spotlight`. Lands after `deep-links` and `surface-snapshot`. No API routes change, so no OpenAPI regeneration.

## 1. Index interface and native channel

- [ ] 1.1 Add `lib/src/spotlight/spotlight_index.dart` (`SpotlightItem`, `SpotlightIndex`, `ChannelSpotlightIndex` with every call caught, no-op off iOS) and `test/support/fake_spotlight_index.dart`. Write failing channel tests (method names and arguments for `replace`, `deleteDomain`, `deleteAll`, `take`; an `opened` call reaches the stream; a `PlatformException` is swallowed); implement; verify.
- [ ] 1.2 Add `ios/Runner/Spotlight.swift` (named index `hermes` with `.complete` protection, `replace`/`deleteDomain`/`deleteAll`, `receive` for `CSSearchableItemActionType` with the `hermes` scheme check, `take`, `opened`), add it to the Runner target and link `CoreSpotlight`; install it in `AppDelegate` and call it from `SceneDelegate` next to `ChatHandoff`. Verify `flutter build ios --simulator -d <udid>`.

## 2. Setting and indexer (TDD)

- [ ] 2.1 Write failing tests for `SpotlightSettings`: default off, persisted, a change during `load()` wins, `offered` only on iOS. Implement; verify.
- [ ] 2.2 Write failing tests for `ChatSpotlightIndexer`: on + signed in replaces the `chat` domain from `recentChats` (title, snippet, URL); an unchanged snapshot makes no call; off, signed-out snapshot, App Lock turned on (the snapshot then carries no titles), `AuthController.signedOut` and server change each call `deleteAll`; turning App Lock off re-indexes on the next snapshot; a failed delete sets the dirty flag and is retried on the next start; calls run one at a time. Implement; verify.
- [ ] 2.3 Write failing tests that an `opened` URL and a cold-start `take` URL reach the `deep-links` entry as an `OpenChat` target, and a non-`hermes` identifier is ignored. Implement; verify.

## 3. Settings UI

- [ ] 3.1 Add Widgetbook use cases for `SpotlightSettingsView` (on, off), both themes, phone and desktop width; verify `flutter test test/widgetbook_test.dart`.
- [ ] 3.2 Add `showSpotlightDialog`, the iOS-only "Spotlight" item in the sidebar account menu and the "Spotlight" row in the Settings dialog, with widget tests that both open the dialog on iOS and are absent on Android and macOS; wire `SpotlightSettings` and the indexer in `main.dart`; verify.

## 4. Observability

- [ ] 4.1 Write failing tests with a recording `AppEventLogger` and `Breadcrumbs` trail: a failed call logs `spotlight.index_failed` (`operation`, `spotlight.domain`, `error.type`); an opened result logs `spotlight.opened` (`spotlight.domain`); toggling adds `spotlight.toggled` (`enabled`); no title, snippet, URL or id appears in any attribute. Implement; verify.

## 5. Docs, skills and verify

- [ ] 5.1 Add Spotlight to CLAUDE.md's Architecture (opt-in, snapshot-fed, domain API, Handoff stays out of search) and a Spotlight check to the `verify-in-app` skill (search in the iOS simulator, lock to confirm protection).
- [ ] 5.2 Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze` and `flutter test`; all pass. In the iOS simulator against `scripts/dev-backend.sh`: turn the switch on, search a chat title in Spotlight, open it with the app running and terminated, rename a chat and see the result change, lock the device and see no result, sign out and turn off and see the results gone. Restore the `ios/`/`macos/` Xcode files the build rewrites, staging files by name.
