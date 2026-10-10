# Proposal

## Why

Long-pressing an app icon is the quickest way into an app's common tasks, and on Android it also lets a shortcut be pinned to the launcher. Hermes offers nothing there. Starting a chat, dictating one, and getting back to the last conversations are the three things people open Hermes for most.

## What Changes

- Long-pressing the Hermes icon on iOS and Android shows:
  - **New Chat**: opens a new chat in the app's current profile;
  - **Dictate**: opens a new chat and starts the microphone;
  - up to **two recent chats** (newest first, across profiles), titled with the chat's title, opening that chat in its profile.
- The recent chats come from the surface snapshot and are refreshed whenever the app writes one, so they follow chat list loads, finished replies and profile switches.
- Signed out, the menu is empty (iOS still shows its own items).
- iOS shows at most four quick actions, so both platforms list New Chat, Dictate and the two newest chats.
- While App Lock is on, the recent chats are removed; New Chat and Dictate stay.

Non-goals:

- No shortcuts on macOS, Windows or Linux (the dock menu is the macOS gaps change's).
- No pinned Android shortcuts created by the app, no conversation shortcuts for Android's sharing or bubbles.
- No per-profile New Chat items, no Kanban or Schedules items.
- No item before the first launch: the items are set by the app, not declared in Info.plist.

Security and privacy impact: the recent chats' titles appear in the long-press menu of the Home Screen, which needs an unlocked device, and in the Android launcher, where a pinned shortcut stays visible until removed. Titles only; no snippet, no token, no server address. Signing out and turning App Lock on clear them. Telemetry carries the kind of item, never a title or id.

Observability:

- Log event `quick_action.used` with `kind` (`new_chat`, `dictate`, `recent`) through `AppEventLogger`: a usage count that tells whether the feature is worth keeping and which item is used.
- Log event `quick_actions.update_failed` with `error.type` when the platform refuses the items, so a broken plugin shows up.
- Breadcrumb `quick_action.opened` with `kind` and `cold_start`, so a crash right after a launch from the icon is explained.
- No span: setting the items is a quick local call.

## Capabilities

### New Capabilities

- `quick-actions`: the app icon's long-press items on iOS and Android, what each opens, how the recent chats follow the snapshot, and the signed-out state.

### Modified Capabilities

None.

## Impact

- Depends on `deep-links` (each item is a `hermes://` URL handled like any other link) and `surface-snapshot` (recent chats and the signed-in flag, and its write listener). With App Lock on the snapshot has no titles, which removes the recent items.
- Dependency: `quick_actions` ^1.1.1 (flutter.dev, iOS and Android; its iOS part supports the UIScene lifecycle since 1.2.4).
- Dart: a new `lib/src/quick_actions/` module started from `main.dart`.
- iOS: three template images (New Chat, Dictate, chat) in `ios/Runner/Assets.xcassets`. Android: three vector drawables in `android/app/src/main/res/drawable`. No Info.plist, manifest or entitlement change.
- Backend: none.
