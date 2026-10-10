# Tasks

One PR, `feat(ios): add Recent chats, Needs you and Board widgets`. Lands after `deep-links` and `surface-snapshot`. No API routes change, so no OpenAPI regeneration. No Dart UI, so no Widgetbook use cases; the SwiftUI views are checked in the simulator.

## 1. Snapshot decoding (Swift, TDD)

- [ ] 1.1 Add the Swift package `ios/HermesSurfaceKit` (`Package.swift`, library `HermesSurfaceKit` in `Sources/HermesSurfaceKit/`, `Tests/HermesSurfaceKitTests/`), compiled into the widget extension and later extended by `app-intents`, mirroring `ios/HermesWatch/Package.swift`; copy `test/fixtures/surface_snapshot_v1.json` (from `surface-snapshot`; add it here from Contract 2 if that change has none) into `ios/HermesSurfaceKit/Tests/Fixtures/`. Verify `swift test` runs.
- [ ] 1.2 Write failing tests for `SurfaceSnapshot` decoding: the fixture, signed out, unknown version, bad JSON, a malformed row skipped, null `kanban`/`schedules`, `profiles` present and missing. Implement `ios/HermesSurfaceKit/Sources/HermesSurfaceKit/SurfaceSnapshot.swift`; verify.
- [ ] 1.3 Write failing tests for `ios/HermesSurfaceKit/Sources/HermesSurfaceKit/WidgetModels.swift`: rows per family (1/3/6), profile shown only with several profiles, oldest request first and its URL, fallback URLs, stale after six hours, "Due" after `nextRunAt`, empty states, rows without a title (App Lock) marked `redacted` with age, kind and URL kept. Implement; verify.
- [ ] 1.4 Add a Dart test that the fixture copy in `ios/HermesSurfaceKit/Tests/Fixtures/` equals `test/fixtures/surface_snapshot_v1.json`.

## 2. Widgets (SwiftUI)

- [ ] 2.1 Add `SurfaceProvider.swift` (one entry, `.never`; Board adds an entry at `nextRunAt`; placeholder and gallery use sample data) and add every new file and the `HermesSurfaceKit` sources to the `HermesLiveActivity` target in `project.pbxproj`. Verify `flutter build ios --simulator -d <udid>`.
- [ ] 2.2 Add `RecentChatsWidget.swift` (small, medium, large), `NeedsYouWidget.swift` (small, medium), `BoardWidget.swift` (small, medium) with `Link`/`widgetURL` from the snapshot, `.privacySensitive()` on titles, snippets, profiles and job names, redacted placeholders for rows without a title (App Lock), and the signed-out and stale states; register them in `HermesLiveActivityBundle`. Verify the build.

## 3. Dart wiring

- [ ] 3.1 Write a failing test that a snapshot write reloads `HermesRecentChats`, `HermesNeedsYou` and `HermesBoard` through the `home_widget` channel; add `lib/src/surfaces/widget_kinds.dart` and use it in `SurfaceSnapshotStore`; verify.

## 4. Observability

- [ ] 4.1 Write failing tests with a recording `AppEventLogger` and a fake `home_widget` channel: `widgets.installed` is logged on start with per-kind/family counts, not again within 24 hours, and not when the channel throws; `widgets.reload_failed` carries kind and error type and no text. Implement `WidgetUsageReporter` and the reload failure log; verify.

## 5. CI, docs and skills

- [ ] 5.1 Add a `swift test` step for `ios/HermesSurfaceKit` to the watch core job in `.github/workflows/ci.yml`.
- [ ] 5.2 Update CLAUDE.md (Native pieces: the extension now also holds the Home Screen widgets; `ios/HermesSurfaceKit` is the shared Swift package of the system surfaces) and the `verify-in-app` skill with adding a widget in the iOS simulator and checking redaction with the device locked.

## 6. Verify

- [ ] 6.1 Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test` and `swift test` in `ios/HermesSurfaceKit`; all pass.
- [ ] 6.2 In the iOS simulator against `scripts/dev-backend.sh`: add each widget in each size; see recent chats, an approval counted in Needs you, Kanban and schedule parts; tap a chat row, the Needs you count and a failed job and land on the right screen; lock the simulator and see titles redacted with counts visible; turn App Lock on, background the app and see redacted rows on the unlocked Home Screen; sign out and see "Open Hermes to sign in". Restore the `ios/`/`macos/` Xcode files the build rewrites, staging files by name.
