## Context

`ChatController` owns the chat's profile and switches by `loadThreads(profile)`; `ProfilesScreen` switches with `setActive` and then calls back into the chat. The Mac sidebar is built by `ChatScreen` (`ThreadSidebar`) on the chat page and by `AppShell` (`ShellSidebar`) on the others, both from the `navigation` widget `AppShell` passes down.

## Decisions

- **`ChatProfiles`** holds the profile list and the chat's current profile. `AppShell` owns it (it builds the sidebar of every page); `ChatScreen` reports its profile with `showing` and attaches `loadThreads` as the switch handler. A switch goes `setActive` first, as `ProfilesScreen` does, so a refusal leaves the chat alone.
- **Switcher in `navigation`.** On macOS `AppShell` prepends the switcher to the destinations, so the chat sidebar and the other pages' sidebars show the same card without new parameters.
- **Profiles page as a destination** (macOS only, when the server has profiles), so it keeps its place behind the other pages like Kanban.
- **Counts** are read per selected profile in parallel and dropped when a read fails. Skills come from the profile row; MCP servers and helper models take a `profile` parameter; bots and plugins have no profile parameter in the app's routes, so they count only for the chat's profile. Opening a section pushes the existing screen: Skills with `chatProfile`, MCP with the new `profile` parameter, Helper models with `profile`, Bots and Plugins as they are.
- **Two-line menu items** come from `AdaptiveMenuItem.macHeight` rather than a menu of their own.
- **Settings…** is a small list of the existing dialogs, since the app has no settings screen.
- **The sidebar controller** is owned by `AppShell` and passed to `MacSidebarScope`, so picking a page from the switcher or the Profiles button closes the compact overlay.

## Risks / Trade-offs

- [Bots and plugins are not profile-scoped in the app] → their counts only show for the chat's profile, and their screens open as before.
- [Skills opened from the Profiles page cannot hand a delete draft to the composer] → the draft is dropped there; the chat sidebar flow on other platforms is unchanged.
