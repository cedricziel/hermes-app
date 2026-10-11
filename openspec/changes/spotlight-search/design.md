# Design

## Context

See proposal.md for motivation and specs/spotlight-search/spec.md for behavior.

`surface-snapshot` writes a `SurfaceSnapshot` after chat list loads, reply ends, request changes and app pause, and lets listeners subscribe to writes; `recentChats` holds at most ten chats across profiles with `title`, a snippet of at most 120 characters, `profile`, `id` and a `hermes://chat` `url`. On sign-out it writes `signedIn: false` with empty lists. `deep-links` hands a parsed `DeepLinkTarget` to `AppShell`, including a target that arrives before the shell is up.

`ChatHandoff` in `ios/Runner/AppDelegate.swift` is the pattern for a native activity bridge: a singleton installed in `didInitializeImplicitFlutterEngine` on a `FlutterMethodChannel`, a `receive(_ activity:)` that `SceneDelegate` calls from `scene(_:continue:)` and from `connectionOptions.userActivities` on a cold start, a pending value Dart fetches with `take`, and an `incoming` call to wake Dart. It publishes with `isEligibleForSearch = false`, which stays.

`AppLockController` and `NotificationSettings` show the settings pattern: a `ChangeNotifier` over `SharedPreferencesAsync` with a `load()`, and a `GroupedDialog` with a `GroupedSwitchRow` and a footer, opened from the sidebar account menu (`thread_sidebar.dart`) and the Settings dialog (`settings_dialog.dart`).

## Goals / Non-Goals

**Goals:** opt-in indexing that can never outlive the session or the switch, and an API another domain can reuse.

**Non-Goals:** paging the whole chat history into the index; macOS.

## Decisions

### A small method channel instead of a plugin

`flutter_core_spotlight` (1.0.4) was last published in July 2021, has no UIScene support and indexes through `NSUserActivity` continuation only. `system_search_index` (0.1.0, September 2026) has no track record yet (no likes, about 200 downloads a month, one release). Neither meets the project's maturity bar, and the native side is about 100 lines next to an existing pattern. `ios/Runner/Spotlight.swift`:

- `replace(domain, items)` (when what Spotlight holds is unknown, such as after a start): `deleteSearchableItems(withDomainIdentifiers: ["hermes.<domain>"])`, then `indexSearchableItems` with one `CSSearchableItem` per item. `update(domain, items, remove)` (every later change) indexes only the changed items, which replace their identifiers in place, and deletes the dropped identifiers, so the domain is never empty in between. Each item is: `uniqueIdentifier` = the item's deep link, `domainIdentifier` = `hermes.<domain>`, attribute set (`UTType.text`) with `title`, `contentDescription` = text, `displayName` = title.
- `deleteDomain(domain)`, `deleteAll()`, `isAvailable()` (`UIApplication.isProtectedDataAvailable`) and a `becameAvailable` call to Dart on `protectedDataDidBecomeAvailable` and `didBecomeActive`.
- `receive(_ activity:)` for `CSSearchableItemActionType`: reads `CSSearchableItemActivityIdentifier`, accepts it only with the `hermes` scheme, keeps it as pending and calls `opened` on the channel; `take` hands it to Dart once.
- The index is `CSSearchableIndex(name: "hermes", protectionClass: .complete)`, so items are unreadable while the device is locked. While the device is locked the indexer makes no call (so none fails or is logged) and catches up on `becameAvailable`. Whether `.complete` protection really hides the items while locked is still to be checked on a device (task 5.2).

The deep link is the identifier because Spotlight hands back only the identifier on a tap; the generic `id` keeps items distinct within a domain on the Dart side.

### Dart module `lib/src/spotlight/`

- `spotlight_index.dart`: `SpotlightItem {domain, id, title, text, url}`, interface `SpotlightIndex` (`replace`, `deleteDomain`, `deleteAll`, each answering whether it worked, `opened` stream, `takeLaunch`), `ChannelSpotlightIndex` on iOS, `NoSpotlightIndex` elsewhere (`SpotlightIndex.forPlatform`). Every call catches and logs. Only the item's url, title and text cross the channel; the `id` stays on the Dart side.
- `spotlight_settings.dart`: `SpotlightSettings` (`enabled`, key `hermes.spotlight`, default false, edit counter so a change during `load()` wins; `offered` is iOS only).
- `chat_spotlight_indexer.dart`: listens to snapshot writes, the setting, `AppLockController` and `AuthController.signedOut`. On, signed in, App Lock off: maps `recentChats` to `chat` items, leaving out chats with no title (App Lock) or the unnamed label (`kUnnamedChatLabel`, whose snippet could repeat the prompt) and calls `replace` only when the items changed since the last call. Otherwise (off, `signedIn: false`, signed out, App Lock on): `deleteAll` once. It waits until the setting and App Lock have loaded, so a start never clears and re-adds. A snapshot read from storage at start is indexed only once the connection (`session`, with `sessionChanges`) says signed in, and dropped when it says signed out, because the app may have been killed between a sign-out and the signed-out write; a snapshot this app writes is trusted at once, and what is indexed stays as it is while the connection is not known.
- Opened results: `linksWithSpotlight` (`spotlight_links.dart`) merges the `opened` and `takeLaunch` URLs into the stream `DeepLinks` listens to (with `AppLinks().uriLinkStream`), so a tap is parsed and opened like a `hermes://` link, a cold start included, and `spotlight.opened` is logged there.

### Settings UI

`SpotlightSettingsView` (plain model: `enabled`, `onChanged`; `widgets/spotlight_settings_view.dart`) inside `showSpotlightDialog`: a `GroupedDialog` titled "Spotlight" with the switch "Show chats in Spotlight" and the footer "Your recent chats' titles and latest messages become searchable on this device while it is unlocked. Turning this off removes them." Reached from the account menu's "Spotlight" item and a "Spotlight" row in the Settings dialog, both iOS only. Widgetbook use cases come first.

### Platforms and native changes

iOS and iPadOS. `ios/Runner/Spotlight.swift` (new file in the Runner target in `project.pbxproj`; `import CoreSpotlight` links the framework), installed in `AppDelegate.didInitializeImplicitFlutterEngine`, called from `SceneDelegate` next to `ChatHandoff`. No entitlement or Info.plist change. Android, macOS, Windows, Linux get the no-op.

### Invariants touched

- Tokens: none indexed; the deep link holds profile and chat id only.
- Telemetry: log events and the breadcrumb carry domain names, counts, flags and error types; failures are swallowed.
- API layering: no REST call; data comes from the snapshot.
- Tests: indexer and settings against a fake `SpotlightIndex` and an in-memory snapshot store; the dialog through Widgetbook and a widget test.

### Signals

| Signal                         | Where                             | Attributes                                                                               |
| ------------------------------ | --------------------------------- | ---------------------------------------------------------------------------------------- |
| log `spotlight.index_failed`   | `ChannelSpotlightIndex` catch     | `operation` (`replace`, `delete_domain`, `delete_all`), `spotlight.domain`, `error.type` |
| log `spotlight.opened`         | indexer, on `opened`/`takeLaunch` | `spotlight.domain`                                                                       |
| breadcrumb `spotlight.toggled` | `SpotlightSettings.setEnabled`    | `enabled`                                                                                |

None holds user content.

### App Lock

With App Lock on, `surface-snapshot` writes no titles or snippets, so the indexer treats such a snapshot like a signed-out one and calls `deleteAll`. When App Lock is turned off, the next snapshot re-indexes the chats. Nothing in Spotlight can show a chat title that the app itself would hide behind Face ID.

### Dependencies

- `surface-snapshot`: recent chats with snippets and URLs, the write listener, the signed-out snapshot, and empty titles under App Lock.
- `deep-links`: opening a result goes through the `hermes://` link path.

## Risks / Trade-offs

- [Only ten chats are searchable] → stated in the spec; a full index needs paging every profile's sessions and is left for later.
- [Delete and index race when snapshots come quickly] → calls are serialized in Dart (one at a time, latest wins).
- [A failed delete leaves items in Spotlight after sign-out or switching off] → `hermes.spotlight.dirty` is set before the first index call and cleared when a `deleteAll` worked; while it is set and nothing should be indexed, `deleteAll` is retried at the next start and with every later change.
- [The named, protected index behaves differently from the default one] → checked in the simulator (task 5.2); fallback is the default index with a shorter description in the footer.

## Migration Plan

Additive and off by default. Rollback ships a build whose start calls `deleteAll` once.
