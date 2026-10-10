# Design

## Context

See proposal.md for motivation and specs/home-screen-widgets/spec.md for behavior.

`surface-snapshot` writes one JSON string under `hermes.surface.v1` in `UserDefaults(suiteName: $(CUSTOM_GROUP_ID))` through `home_widget` (`saveWidgetData`), and `SurfaceSnapshotStore` reloads WidgetKit timelines after each write. `home_widget` 0.10.0 reloads by kind only (`updateWidget(iOSName:)` calls `WidgetCenter.reloadTimelines(ofKind:)`; there is no reload-all), so the store needs the kinds to reload. `deep-links` builds every `hermes://` URL; the snapshot already carries a `url` per chat, request and failed job.

`ios/HermesLiveActivity` is a widget extension (`com.apple.widgetkit-extension`) with `@main struct HermesLiveActivityBundle: WidgetBundle`, the App Group entitlement, an `AppGroupId` Info.plist key, bundle ID `com.cedricziel.hermesApp.LiveActivity` in every configuration, iOS 26, and its own fastlane match entry. The Xcode project has no synchronized folders: each new Swift file needs a `PBXBuildFile`, `PBXFileReference`, group child and Sources entry. `ios/HermesWatch` shows how Swift logic is tested without a simulator: a `Package.swift` over a `Core/` folder the target also compiles, run by CI's "Test watch core" job.

## Goals / Non-Goals

**Goals:** widgets that render the snapshot faithfully, never leak titles on a locked device, and cost no signing or provisioning work.

**Non-Goals:** widget configuration, interactivity, background data fetching in the extension.

## Decisions

### Join the existing widget extension instead of adding a target

The widgets go into `HermesLiveActivityBundle` beside `HermesReplyActivity`. One WidgetKit extension may hold any number of widgets and Live Activities. A new target would need a new bundle ID, a new App ID with the App Group capability in the developer portal, a match profile, a `fastlane/Fastfile` entry in `TARGETS[:ios]` and an embed phase, which is the churn the Live Activity change paid once already. The cost is a misleading target name (`HermesLiveActivity`); the bundle ID and target name stay, because renaming them would orphan the provisioning profile and the activities already on devices. The shared extension's memory limit (about 30 MB) is far above what text-only views need. `app-intents` can put its Control widgets in the same bundle.

Alternative: a `HermesWidgets` target. Rejected for the signing churn above; nothing in the widgets needs a separate process.

### Decode in a tested Swift package, draw in SwiftUI

This change creates `ios/HermesSurfaceKit`, the one Swift package the system surfaces share (library `HermesSurfaceKit`, macOS 14 + iOS 17 for `swift test` on the Mac). Its sources are compiled into the `HermesLiveActivity` target. `app-intents` extends it with the deep-link builder and the Chat and Profile entities and compiles it into the Runner; no second package is added. Here it holds:

- `SurfaceSnapshot.swift`: `Decodable` mirror of Contract 2, lenient like the Dart repositories: unknown `version` or bad JSON yields `nil` (shown as signed out), a malformed row is skipped, a missing `kanban`/`schedules` is "unavailable".
- `profiles` is decoded too (empty when missing), so `app-intents` reads the same type.
- `WidgetModels.swift`: pure functions from a snapshot and a date to what each widget shows: rows per family (small 1, medium 3, large 6 chats; medium Needs you 3 chats), the oldest request's URL, whether the snapshot is stale (`updatedAt` older than 6 h), fallback URLs (`hermes://requests`, `hermes://kanban`, `hermes://schedules`).

The views (`RecentChatsWidget.swift`, `NeedsYouWidget.swift`, `BoardWidget.swift`, `SurfaceProvider.swift`) are only in the extension target. CI's watch job gets a second step (`working-directory: ios/HermesSurfaceKit`, `swift test`).

### One timeline provider, reloaded by the app

`SurfaceProvider: TimelineProvider` reads the snapshot once per timeline and returns a single entry with policy `.never`; the app reloads after each write. Ages use `Text(date, style: .relative)` so they tick without reloads. The Board widget adds a second entry at `nextRunAt`, so a passed run reads "Due" without the app. `placeholder` and the gallery snapshot use built-in sample data (no App Group read), which keeps real titles out of the widget gallery.

### Links and redaction

Rows are `Link(destination: row.url)`; the small families use `.widgetURL`. URLs come from the snapshot verbatim, so `deep-links` stays the only producer. Titles, snippets, profile names and job names get `.privacySensitive()`; counts, symbols and fixed labels do not.

With App Lock on, `surface-snapshot` writes empty titles and no snippets or job names. `WidgetModels` marks such a row `redacted`, and the view draws a fixed-width placeholder with `.redacted(reason: .placeholder)` (no "Untitled", which would read as a real title), keeping age, kind label, count and link. Nothing is drawn from the `pending` entries except kind and title (the snapshot holds no command or question).

### Dart side

`lib/src/surfaces/widget_kinds.dart` exports `kSurfaceWidgetKinds = ['HermesRecentChats', 'HermesNeedsYou', 'HermesBoard']`, which `SurfaceSnapshotStore` reloads after each write; `lock-screen-widgets` appends its kinds there. `WidgetUsageReporter` (same folder) calls `HomeWidget.getInstalledWidgets()` on app start at most once per 24 h (last report time in `SharedPreferencesAsync`, key `hermes.widgets.reported_at`) and logs `widgets.installed`.

### Platforms and native changes

iOS and iPadOS only. `project.pbxproj`: the new Swift files in the `HermesLiveActivity` target. No entitlement, Info.plist, bundle ID, fastlane or Android/macOS change. `.github/workflows/ci.yml`: one `swift test` step.

### Invariants touched

- Tokens: the extension reads only the snapshot, which has no token, server address or identity; it has no keychain access group.
- Telemetry: `widgets.installed` carries `{kind: family: count}` pairs and nothing else, `widgets.reload_failed` the error's runtime type; both swallow their own failures.
- API layering, generated client: untouched; no REST call.
- Tests: Dart parts against a fake `home_widget` channel; Swift logic with `swift test`.

### Signals

| Signal                      | Where                                   | Attributes                                                                 |
| --------------------------- | --------------------------------------- | -------------------------------------------------------------------------- |
| log `widgets.installed`     | `WidgetUsageReporter.report`, app start | `widgets.count`, `widgets.kinds` (e.g. `HermesRecentChats/systemMedium=1`) |
| log `widgets.reload_failed` | `SurfaceSnapshotStore` reload loop      | `widget.kind`, `error.type`                                                |

None holds user content.

### Dependencies

- `surface-snapshot`: the JSON (with App Lock redaction), the `home_widget` bridge and the store's reload after each write.
- `deep-links`: the `hermes://` URLs and their handling.

## Risks / Trade-offs

- [Widgets show what the app last wrote] → the stale note after six hours; `background-refresh` narrows the gap.
- [Snapshot schema drift between Dart and Swift] → `version` gate plus a Dart test that writes the fixture `test/fixtures/surface_snapshot_v1.json` the Swift tests also decode (copied into `ios/HermesSurfaceKit/Tests/Fixtures/`, checked equal by a Dart test).
- [The target name no longer matches its content] → a comment at the bundle; renaming is not worth re-provisioning.
- [Large widget with few chats looks empty] → fills with an "Open Hermes" row; accepted.

## Migration Plan

Additive. Rollback removes the widgets from the bundle; placed widgets disappear from the Home Screen on the next install.
