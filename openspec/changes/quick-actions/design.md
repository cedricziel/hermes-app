# Design

## Context

See proposal.md for motivation and specs/quick-actions/spec.md for behavior.

`surface-snapshot` provides `SurfaceSnapshotStore`, which writes a `SurfaceSnapshot` (at most ten `recentChats`, newest first across profiles, each with `title`, `profile`, `id` and a `hermes://chat` `url`, plus `signedIn`) and lets listeners subscribe to writes. On sign-out it writes `signedIn: false` with empty lists. `deep-links` provides `parseDeepLink(Uri)` and `deepLinkUri(target)`, and the app-level entry that hands a `DeepLinkTarget` to `AppShell` (the same path a `NotificationTarget` takes), including a target that arrives before the shell is up.

`quick_actions` 1.1.1 (flutter.dev) wraps `UIApplicationShortcutItem` and Android dynamic shortcuts: `initialize(handler)` gets the type of the item that was picked, including the one that launched the app; `setShortcutItems` replaces all items. Its iOS implementation (`quick_actions_ios` 1.2.5) handles both `application(_:performActionFor:)` and the scene path (`connectionOptions.shortcutItem`, `windowScene(_:performActionFor:)`), which this app needs because it runs on `FlutterSceneDelegate`. Icons are `UIApplicationShortcutIcon(templateImageName:)` on iOS and drawable resource names on Android.

## Goals / Non-Goals

**Goals:** items that always match the last snapshot, one code path from tap to screen, and no duplicate of the deep-link logic.

**Non-Goals:** static Info.plist items, Android pinned shortcuts, macOS dock menu.

## Decisions

### The item type is the deep link

Each `ShortcutItem.type` is the item's `hermes://` URL string (`deepLinkUri(NewChat())`, `deepLinkUri(NewChat(dictate: true))`, or the chat's snapshot `url`). The handler parses it with `parseDeepLink` and hands the target to the deep-link entry, so New Chat, Dictate and a recent chat behave exactly as the same link from a widget would. An unknown type is ignored, which `deep-links` already records as `deeplink.ignored`. The URL is unique per chat (profile and id), which Android needs for shortcut ids.

Alternative: short fixed types (`new`, `dictate`, `recent:<n>`) mapped in Dart. Rejected: a second mapping to keep in step with `deep-links`, and recent items would need the snapshot at tap time.

### `QuickActionsController` follows the snapshot

`lib/src/quick_actions/quick_actions_controller.dart`, created in `main.dart` next to the other app-wide controllers on iOS and Android only:

- `start()` calls `initialize` first (so a launch item is not lost), then subscribes to `SurfaceSnapshotStore` writes and applies the current snapshot.
- `itemsFor(SurfaceSnapshot)` (pure): signed out → `[]`; otherwise New Chat, Dictate, then the first two `recentChats` whose title is not empty, titles trimmed to 40 characters. While App Lock is on, `surface-snapshot` writes every title empty, so no recent item is left and the menu holds only New Chat and Dictate; the controller needs no App Lock check of its own, and the next write after App Lock is turned off brings the recents back. On iOS the recent items carry the profile as `localizedSubtitle` when the snapshot holds more than one profile.
- Only a change in the computed list reaches the plugin (compared by type and title), since every snapshot write would otherwise re-set the same items.
- A `QuickActionsPort` interface wraps the plugin; tests use a fake. Every plugin call is wrapped so an error is logged and swallowed.

Order follows the settled decision (static first). iOS shows four, so its menu holds two recent chats; the list is not reordered per platform, so both platforms keep the same meaning for the top items.

### Icons

Template images `quick_new_chat` (square.and.pencil), `quick_dictate` (mic) and `quick_chat` (bubble.left) exported as PDF into `ios/Runner/Assets.xcassets`, and matching vector drawables in `android/app/src/main/res/drawable`. `quick_actions` cannot take SF Symbol names directly.

### Platforms and native changes

iOS, iPadOS and Android. Asset catalog entries and drawables only; no Info.plist, AndroidManifest, entitlement or Xcode target change. `AppDelegate.swift`/`SceneDelegate.swift` are untouched, since the plugin registers its own scene hooks; task 1.2 confirms that on a cold launch.

### Invariants touched

- Tokens: none involved; the items hold titles and `hermes://` URLs only.
- Telemetry: the log events and the breadcrumb hold the item kind, a flag and an error type, never a title, profile or id. Failures are swallowed.
- API layering, generated client: untouched; no REST call.
- Tests: the controller against a fake port and a real `SurfaceSnapshotStore` with an in-memory backing; the tap path against the `deep-links` entry.

### Signals

| Signal                            | Where                  | Attributes                              |
| --------------------------------- | ---------------------- | --------------------------------------- |
| log `quick_action.used`           | handler, after parsing | `kind`: `new_chat`, `dictate`, `recent` |
| breadcrumb `quick_action.opened`  | handler                | `kind`, `cold_start` (bool)             |
| log `quick_actions.update_failed` | `apply` catch          | `error.type`                            |

None holds user content.

### Dependencies

- `surface-snapshot`: recent chats, the signed-in flag, the write listener, and empty titles under App Lock.
- `deep-links`: `parseDeepLink`, `deepLinkUri` and the app-level entry.

## Risks / Trade-offs

- [iOS truncates to four items] → two recent chats on iOS; stated in the spec, so nobody files it as a bug.
- [A recent item points at a chat deleted since the last snapshot] → the deep-link path shows "Could not open that chat." and the next snapshot drops it.
- [Android launchers differ in how many shortcuts they show] → the list is ordered by importance, so a cut keeps New Chat and Dictate.
- [The plugin misses a cold-start item with the scene lifecycle] → task 1.2 checks it on a device or simulator; if it does, `SceneDelegate` forwards `connectionOptions.shortcutItem` to the plugin.

## Migration Plan

Additive. Rollback removes the controller; iOS keeps dynamic items until the next app launch clears them, so the rollback build calls `clearShortcutItems()` once.
