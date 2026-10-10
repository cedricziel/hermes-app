# Tasks

One PR, `feat(ios): add Lock Screen and StandBy widgets`. Lands after `home-screen-widgets`. No API routes change, so no OpenAPI regeneration. No Dart UI, so no Widgetbook use cases; the SwiftUI views are checked in the simulator.

## 1. Models (Swift, TDD)

- [ ] 1.1 Write failing tests in `HermesSurfaceKitTests` for the accessory models: circular count, rectangular kind label of the oldest request, inline text ("N waiting in Hermes", "Nothing waiting"), tap URL (oldest request or `hermes://requests`), "Sign in" when signed out, and the redacted title when App Lock left it out. Implement in `ios/HermesSurfaceKit/Sources/HermesSurfaceKit/WidgetModels.swift`; verify with `swift test`.
- [ ] 1.2 Add a Dart test that writes `ios/HermesSurfaceKit/Tests/Fixtures/deep_links.json` from the `deep-links` change's `deepLinkUri` for a fixed input set (plain, spaces, `&`, `/`, `%`, non-ASCII profile and thread ids; chat, new, new with dictate) and fails when the file is out of date. Write a failing Swift test that `DeepLink` (`ios/HermesSurfaceKit/Sources/HermesSurfaceKit/DeepLink.swift`, the package's only URL builder, which `app-intents` reuses) matches every case. Implement it; verify both pass.

## 2. Widgets (SwiftUI)

- [ ] 2.1 Add the accessory families to `NeedsYouWidget` (`accessoryCircular`, `accessoryRectangular`, `accessoryInline`) with `widgetAccentable()`, `AccessoryWidgetBackground()`, `.privacySensitive()` on the chat title and `widgetURL`. Verify `flutter build ios --simulator -d <udid>`.
- [ ] 2.2 Add `QuickLaunchWidgets.swift`: `HermesNewChat` and `HermesDictate` (`accessoryCircular`, `systemSmall`) and `HermesQuickLaunch` (`systemMedium`, two `Link`s), with the signed-out label; add the file to the `HermesLiveActivity` target in `project.pbxproj` and register the widgets in `HermesLiveActivityBundle`. Verify the build.

## 3. Dart wiring

- [ ] 3.1 Extend the failing reload test from `home-screen-widgets` to expect `HermesNewChat`, `HermesDictate` and `HermesQuickLaunch`; add them to `kSurfaceWidgetKinds`; verify.

## 4. Observability

- [ ] 4.1 No new signal. Extend the `WidgetUsageReporter` test so a placed `HermesNewChat/accessoryCircular` is counted in `widgets.installed`; verify.

## 5. Docs and skills

- [ ] 5.1 Update the `verify-in-app` skill's widget section with adding Lock Screen widgets and entering StandBy in the iOS simulator, and CLAUDE.md's Native pieces line for the extension.

## 6. Verify

- [ ] 6.1 Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test` and `swift test` in `ios/HermesSurfaceKit`; all pass.
- [ ] 6.2 In the iOS simulator against `scripts/dev-backend.sh`: add the Needs you circular, rectangular and inline widgets and New Chat and Dictate to the Lock Screen; raise an approval and see the count (title hidden while locked); tap each and land on the request's chat, a new chat, and a new chat with the microphone; add Quick launch medium and check both buttons; sign out and see "Sign in". Restore the `ios/`/`macos/` Xcode files the build rewrites, staging files by name.
