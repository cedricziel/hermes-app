# Tasks

One PR, `feat(app): add app icon quick actions`. Lands after `deep-links` and `surface-snapshot`. No API routes change, so no OpenAPI regeneration. No Flutter UI, so no Widgetbook use cases.

## 1. Dependency and port

- [ ] 1.1 Add `quick_actions: ^1.1.1`, run `flutter pub get`, add `lib/src/quick_actions/quick_actions_port.dart` (interface, plugin implementation with every call wrapped, no-op off iOS/Android) and `test/support/fake_quick_actions_port.dart`; verify `flutter analyze`.
- [ ] 1.2 Spike: in the iOS simulator, set one item from Dart and launch the app from it while terminated; confirm the plugin delivers it under `FlutterSceneDelegate`. If not, forward `connectionOptions.shortcutItem` from `SceneDelegate` and record the finding in design.md (Risks).

## 2. Controller (TDD)

- [ ] 2.1 Write failing tests in `test/quick_actions/quick_actions_items_test.dart` for `itemsFor`: signed out empty; New Chat and Dictate first with `hermes://new` and `hermes://new?dictate=1` types; two recents newest first (four items in all, the iOS limit) with their snapshot URL; untitled chats skipped; an App Lock snapshot (empty titles) gives only New Chat and Dictate; titles trimmed; iOS subtitle only with several profiles. Implement; verify.
- [ ] 2.2 Write failing tests in `test/quick_actions/quick_actions_controller_test.dart`: `initialize` before the first `setShortcutItems`; a snapshot write updates the items; an identical write does not call the plugin again; sign-out clears them; turning App Lock on removes the recents and turning it off brings them back on the next write; a plugin error is swallowed. Implement `quick_actions_controller.dart`; verify.
- [ ] 2.3 Write failing tests that a picked type reaches the `deep-links` entry as the parsed target (New Chat, Dictate, a recent chat, a cold-start type delivered before the shell is ready) and an unknown type is ignored. Implement the handler; verify.

## 3. Wiring and assets

- [ ] 3.1 Start the controller from `main.dart` on iOS and Android with the app's `SurfaceSnapshotStore`; add a test that it is not created on macOS. Verify.
- [ ] 3.2 Add the `quick_new_chat`, `quick_dictate` and `quick_chat` template images to `ios/Runner/Assets.xcassets` and vector drawables to `android/app/src/main/res/drawable`; verify `flutter build ios --simulator -d <udid>` and `flutter build apk --debug`.

## 4. Observability

- [ ] 4.1 Write failing tests with a recording `AppEventLogger` and `Breadcrumbs` trail: a pick logs `quick_action.used` (`kind`) and adds `quick_action.opened` (`kind`, `cold_start`); a plugin failure logs `quick_actions.update_failed` (`error.type`); no title, profile or URL appears in any attribute. Implement; verify.

## 5. Docs and skills

- [ ] 5.1 Add quick actions to CLAUDE.md's Architecture (where the items come from, the four-item iOS limit) and a short section to the `verify-in-app` skill on testing them in the iOS simulator and an Android emulator.

## 6. Verify

- [ ] 6.1 Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze` and `flutter test`; all pass.
- [ ] 6.2 Against `scripts/dev-backend.sh`, in the iOS simulator and an Android emulator: long-press the icon and see New Chat, Dictate and recent chats; pick each with the app running and terminated; send a reply in a new chat and see it move to the top; turn App Lock on and see only New Chat and Dictate; sign out and see the items gone. Restore the `ios/`/`macos/` Xcode files the build rewrites, staging files by name.
