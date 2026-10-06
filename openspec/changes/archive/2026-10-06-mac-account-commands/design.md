## Decisions

- **Menu placement**: account items go in the app menu under Settings…, as macOS apps put account and sign-out entries there. No shortcut: ⇧⌘Q is the system's Log Out.
- **Registration** in `AppShell`, next to Settings, so the commands work whatever page or window size is in front, not only while the footer is built.
- **Confirmation** in one `confirmSignOut` helper shared by the footer and the menu.
- **Messaging scope**: `HermesMessagingRepository.forProfile(name)` returns a repository whose calls pass `profile` wherever the route takes one (list, update, Telegram apply). The Telegram start, status and cancel routes take none. The Messaging screen opened from the Profiles page uses it, so the count and the screen agree.
- **Plugins** stay chat-profile only: the plugin hub route has no profile parameter.
