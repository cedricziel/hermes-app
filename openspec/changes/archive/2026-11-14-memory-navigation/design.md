# Design

## Context

`MemoryDestination` today loads the profile list, opens on the active profile and offers a subtitle menu to pick another. It is pushed only from the Settings dialog (`lib/src/settings/settings_dialog.dart`). The per-profile pages (Skills, Messaging, Plugins, MCP servers, Helper models) are reached from the chat sidebar off the Mac and from the Mac Profiles page's card (`ProfileSection` in `lib/src/profiles/widgets/mac_profiles_view.dart`, screens and counts in `lib/src/profiles/mac_profiles_page.dart`). Off the Mac the drawer (`chat_screen_layout.dart`) lists them as `SidebarAction`s and the wide sidebar (`ThreadSidebar`) folds them into its More section.

`.design-sync/NOTES.md`: a Flutter UI change reaches Claude Design only when the matching component in `design/web/src/components/` changes (`ThreadSidebar`'s `DEFAULT_MORE_ENTRIES`, `MacProfilesPage`'s sections).

Platforms: iOS, iPadOS, Android, macOS, Windows, Linux. No native, entitlement, manifest or Xcode project change.

## Goals / Non-Goals

**Goals:**

- Memory sits next to Skills everywhere a profile's pages are listed, and opens on the profile the user is looking at.

**Non-Goals:**

- The waiting count (in `memory-proposals`), a top-level destination, deep links.

## Decisions

**Open on a given profile.** `MemoryDestination` takes a `profile`. From the chat sidebar it is the chat's profile (`ChatProfiles.current`, as Skills uses); from the Profiles page the selected profile. The subtitle menu stays for switching, with the existing leave confirmation and scope rules. When the given profile is no longer on the server the existing "This profile is no longer available." state shows.

**Entries.** Off the Mac: a `SidebarAction` "Memory" with `AppIcons.memory` directly after Skills in the drawer, and the same entry after Skills in `ThreadSidebar`'s More section (`onOpenMemory`). Shown under the same condition as Skills (a dashboard connection). On macOS the sidebar keeps no per-profile entries; the Profiles page gets `ProfileSection.memory` ("Memory", "What the agent remembers", `AppIcons.memory`) after `skills`.

**Mac count.** The number of memory entries in the selected profile, from `GET /api/learning/graph?profile=` through `MemoryRepository.load` when a profile is selected, like the other counts; a failed read shows no count. The count call is traced as `memory.fetch` with `operation: count`.

**Waiting count hook.** The entries take an optional `detail` text (drawer and More entries) and the section an optional value override, null in this change, so `memory-proposals` can fill them without touching layout again.

**Settings dialog.** `_Setting.memory` and its import are removed. App-wide settings stay; Memory is reached per profile.

**Design recreation.** `DEFAULT_MORE_ENTRIES` gains `{ icon: "memory", label: "Memory" }` after Skills; `MacProfilesPage` gains a Memory section after Skills with a sample count; the component JSDoc says what the entry opens. Built and checked as `.design-sync/NOTES.md` describes.

**Invariants touched.** None beyond reuse: the count goes through the existing generated-client call.

**Observability.**

- Breadcrumb `nav.memory` (`from`: `sidebar` | `profiles_page`), recorded where the entry is tapped.
- Span `memory.fetch` with `operation: count` for the Mac count, from `MemoryRepository`, with `hermes.*` attributes and `outcome`.

Neither carries a profile name, count of entries, or memory text.

## Risks / Trade-offs

- [Users who learned the Settings row] → the row is gone; the sidebar entry is where Skills already is. Accepted.
- [One more graph request per profile selection on the Mac] → the same order as the Skills count; accepted.

## Migration Plan

None.
