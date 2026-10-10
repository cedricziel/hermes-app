# Tasks

One PR, `feat(ios): open chats, new chats and dictation from Siri, Shortcuts and controls`. Needs `home-screen-widgets`, `surface-snapshot` and `deep-links` merged. No API routes change, so no OpenAPI regeneration.

## 1. Shared Swift package (TDD)

- [ ] 1.1 In `ios/HermesSurfaceKit` (created by `home-screen-widgets`), write a failing `swift test` that the reader decodes `profiles` (present, missing, malformed); extend the reader if it does not yet; verify `swift test` passes.
- [ ] 1.2 Reuse `DeepLink` from `lock-screen-widgets`. If a case the intents need (e.g. `hermes://chat` with a profile only) is missing from `Tests/Fixtures/deep_links.json`, add it to the Dart fixture writer first, watch the Swift test fail, then extend `DeepLink`; verify both pass.
- [ ] 1.3 Write failing Swift tests for `ChatEntity` and `ProfileEntity` queries: suggested order and limit, lookup by id across profiles, an unknown id answered as "Chat", title search ignoring case and diacritics, nothing while signed out, profile list from `profiles` with the current profile first, the fallback when `profiles` is empty, chats with empty titles (App Lock) shown as "Chat"; implement the entities and queries; verify.
- [ ] 1.4 Write failing Swift tests that each intent's URL is right for every parameter combination (profile given, defaulted, absent), then implement `OpenChatIntent`, `NewChatIntent`, `DictateIntent` (`supportedModes = .foreground`, `OpensIntent` with `OpenURLIntent`); verify.
- [ ] 1.5 Confirm the CI step `home-screen-widgets` added runs the new tests; verify the workflow passes on the PR.

## 2. App and extension wiring

- [ ] 2.1 Add the package's sources to the Runner and `HermesLiveActivity` targets in Xcode (file membership, like the watch core), and `ios/Runner/HermesAppShortcuts.swift` with the `AppShortcutsProvider` and the phrases from design.md, Runner only; verify `flutter build ios --simulator -d <udid>` succeeds.
- [ ] 2.2 Add `NewChatControl`, `DictateControl` and `OpenChatControl` to `HermesLiveActivityBundle`; verify the build and that the controls appear in the simulator's Control Center gallery.
- [ ] 2.3 Write a failing Dart test that a snapshot write calls `refreshShortcuts` on `hermes_app/intents` once on iOS, never on other platforms, and that a channel error is swallowed; implement the listener on the snapshot store's write stream and the Runner handler calling `updateAppShortcutParameters()`; verify.

## 3. Telemetry, docs and skills

- [ ] 3.1 No spans, log events or breadcrumbs are added (the `deep-links` change records the link handling); confirm in review that no Swift or Dart code here logs titles or ids.
- [ ] 3.2 Update CLAUDE.md (Native pieces: `HermesSurfaceKit`, the intents, the controls in `HermesLiveActivity`) and the `verify-in-app` skill with how to run an App Intent and a control in the iOS simulator (Shortcuts app, `xcrun simctl` for Siri is not available, so run the shortcut from the Shortcuts app).

## 4. Verify

- [ ] 4.1 Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test` and `swift test` in `ios/HermesSurfaceKit`; all pass.
- [ ] 4.2 In the iOS simulator against `scripts/dev-backend.sh`: load chats so the snapshot is written; in Shortcuts run New Chat (with and without a profile), Dictate and Open Chat (pick a chat); add each control to Control Center and tap it; kill the app and repeat Open Chat to check the cold start. Restore the `ios/`/`macos/` Xcode files the build rewrites, staging files by name.
