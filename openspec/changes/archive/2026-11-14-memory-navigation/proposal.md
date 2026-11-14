# Proposal

## Why

Memory is per profile, like Skills, but the only way in is a row in the Settings dialog, among app-wide settings, opening on whatever profile the server reports as active. Users looking at a profile's skills, plugins or MCP servers do not find its memory there, and on the Mac Profiles page memory is mentioned only in the footnote.

## What Changes

- A "Memory" sidebar action directly after Skills wherever Skills is offered off the Mac: the phone drawer, the iPad sidebar and the desktop Material sidebar (Windows, Linux, wide Android). It opens the Memory screen for the chat's profile.
- On the Mac Profiles page, a Memory row directly after Skills in the selected profile's card, with the profile's entry count, opening the Memory screen for that profile.
- The Settings dialog's Memory row is removed.
- The design recreation in `design/web/` gets the same entries.
- The entry points can show a count of waiting proposals; the count itself arrives with change `memory-proposals`.

Non-goals:

- Changing the Memory screen's content (changes `memory-overview` and `memory-settings`).
- The proposal count ("N waiting"), which is specified in `memory-proposals`.
- A Memory destination in the Mac sidebar's top-level list or the shell's tabs; Memory stays a per-profile page like Skills.
- Deep links to Memory.

## Capabilities

### New Capabilities

- `memory-navigation`: where Memory is opened from and which profile it opens on.

### Modified Capabilities

- `profiles-and-bots`: the Mac Profiles page's card gains Memory after Skills, and the per-profile sidebar entries hidden on macOS include Memory.

## Impact

- Code: `lib/src/chat/chat_screen_layout.dart` (drawer action), `lib/src/chat/widgets/thread_sidebar.dart` (`onOpenMemory`, the More entries), `lib/src/profiles/widgets/mac_profiles_view.dart` and `lib/src/profiles/mac_profiles_page.dart` (`ProfileSection.memory`, its count and screen), `lib/src/memory/memory_destination.dart` (a profile to open on), `lib/src/settings/settings_dialog.dart` (row removed), Widgetbook use cases of the sidebar and the Profiles page, `design/web/src/components/ThreadSidebar` and `MacProfilesPage`.
- Backend: no new route. The Mac count reads `GET /api/learning/graph?profile=`, already used by the Memory screen.
- Security and privacy: none. The count is a number held in memory.
- Observability: a `nav.memory` breadcrumb (`from`: `sidebar` | `profiles_page`) records how the user reached Memory before a crash. The Mac count read reuses the `memory.fetch` span with `operation: count`. No profile names or counts of other users' data.
