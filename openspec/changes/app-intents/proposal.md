# Proposal

## Why

On iPhone the fastest ways into an app are Siri, the Shortcuts app, the Action button and the Control Center / Lock Screen controls. Hermes offers none of them on the phone (the watch has its own two intents), so starting a chat or dictating always means finding the app, opening it and tapping through. The wave-1 changes give the app a `hermes://` deep link for every destination (`deep-links`) and a snapshot of recent chats in the App Group (`surface-snapshot`); App Intents only have to point at them.

## What Changes

- Three App Intents in the iPhone app, all of which open the app on a `hermes://` link (Contract 1) and do nothing else:
  - "Open Chat" with a Chat parameter, opens `hermes://chat?profile=…&id=…`;
  - "New Chat", opens `hermes://new?profile=…`;
  - "Dictate", opens `hermes://new?profile=…&dictate=1`.
- A Chat entity that Siri and Shortcuts can pick from: the recent chats in the surface snapshot (Contract 2), newest first, searchable by title. A chat a saved shortcut names that is no longer in the snapshot still opens.
- An optional Profile parameter on "New Chat" and "Dictate", offering the snapshot's `profiles`; without it the app's current profile (the snapshot's `profile`) is used.
- App Shortcuts with Siri phrases taken from the watch's own (`ios/HermesWatch/WatchShortcuts.swift`): "New Hermes chat", "Talk to Hermes", "Voice chat with Hermes", "Open <chat> in Hermes". Each intent can be put on the Action button through Shortcuts.
- Three Control Center / Lock Screen controls (iOS 18 `ControlWidget`): New Chat, Dictate, and Open Chat (configured with a chat). They live in the existing `HermesLiveActivity` widget extension.
- The app tells iOS to re-read the chat phrases whenever it writes a new snapshot.

Non-goals:

- No intent that answers without opening the app ("Ask Hermes", pending requests, answering an approval): those are the `ask-hermes-intent` and `request-intents` changes.
- No Spotlight indexing of chats through the entity (`IndexedEntity`). Spotlight is opt-in and belongs to `spotlight-search`.
- No intent donations or Siri suggestions learned from use.
- No macOS target in this rollout. The shared Swift compiles for macOS, but no macOS intent ships.
- No change to the watch's intents.
- No Android equivalent (App Actions / AppFunctions).

Security and privacy impact: the intents read only the surface snapshot, which holds no token, server address or user identity (Contract 2), and they never touch the network or secure storage. While App Lock is on the snapshot holds no titles, so chats are offered as "Chat". Otherwise chat titles become visible in the Shortcuts editor and the Siri chat picker, also on a locked device, in the same way notifications already show chat titles. Opening a chat still goes through the app, so App lock and sign-in apply as usual. Nothing new is sent to telemetry.

Observability: none in this change. The intents only open `hermes://` links, and the `deep-links` change already records `deeplink.opened` / `deeplink.ignored` breadcrumbs where the link is handled, which explains a later crash just as well. The Swift side runs outside Flutter's telemetry; a failed snapshot read leaves the chat picker empty, which a user can see and report.

## Capabilities

### New Capabilities

- `app-intents`: the iOS App Intents, Chat entity, profile parameter, Siri phrases and Control Center / Lock Screen controls that open Hermes on a deep link.

### Modified Capabilities

None.

## Impact

- Swift: extends the `ios/HermesSurfaceKit` package that `home-screen-widgets` creates (snapshot reader) with the deep-link builder, Chat and Profile entities and the three intents, compiled into the Runner and the `HermesLiveActivity` extension and tested with `swift test` on the Mac. An `AppShortcutsProvider` in the Runner only, and three controls added to the extension's `WidgetBundle`.
- Dart: one call after each snapshot write that asks iOS to refresh the shortcut parameters, on the existing `hermes_app/…` channel pattern.
- Xcode: file membership for the package in both targets; no new target, entitlement or Info.plist key.
- Depends on `home-screen-widgets` (creates `ios/HermesSurfaceKit` and its snapshot reader), `lock-screen-widgets` (adds the `DeepLink` builder), `surface-snapshot` (snapshot written, with `profiles`) and `deep-links` (URL scheme registered, links handled). `ask-hermes-intent` and `request-intents` build on the entities added here.
- Backend: none.
