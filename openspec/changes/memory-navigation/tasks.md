# Tasks

One PR, `feat(navigation): open Memory from the sidebar and the Profiles page`, about 300 changed lines with tests. Can land in parallel with `memory-settings` and `memory-tool-calls`, after `memory-overview`.

## 1. Memory on a given profile

- [ ] 1.1 Write a failing `MemoryDestination` test: opened with profile "work" it loads "work" without asking the server for the active profile; an unknown profile shows "This profile is no longer available."; the subtitle menu still switches. Then add the `profile` parameter.

## 2. Widgets

- [ ] 2.1 Extend the Widgetbook use cases of the drawer, `ThreadSidebar`'s More section and `MacProfilesView` with the Memory entry after Skills (with and without a count on the Mac, with an optional detail text off the Mac), in both themes at phone and desktop width.
- [ ] 2.2 Write failing widget tests: Memory directly follows Skills in the drawer and the More section, is hidden when Skills is, and `ProfileSection.memory` follows `skills` with its count or none. Then add `onOpenMemory`, the drawer action and the section.

## 3. Wiring

- [ ] 3.1 Write failing tests: the drawer and More entries open Memory for the chat's profile; the Profiles page row opens it for the selected profile and reads its count through `GET /api/learning/graph?profile=`, showing none on failure; the Settings dialog no longer lists Memory. Then wire them and remove `_Setting.memory`.
- [ ] 3.2 Write a failing test that a tap records `nav.memory` with only `from`, and the Mac count read a `memory.fetch` span with `operation: count`. Then add them.
- [ ] 3.3 Update `design/web/src/components/ThreadSidebar` (`DEFAULT_MORE_ENTRIES`) and `MacProfilesPage` (sections) with Memory after Skills, build `design/web` and check the cards as `.design-sync/NOTES.md` describes.
- [ ] 3.4 Update `CLAUDE.md` (Profile scope on macOS, the per-profile entries) and the `workflow-screenshots` or `verify-in-app` skill if they mention reaching Memory from Settings.

## 4. Verify

- [ ] 4.1 Run `/simplify` on the diff.
- [ ] 4.2 Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze` and `flutter test`, all passing; look at the workflow screenshots of the sidebar and the Profiles page.
- [ ] 4.3 Use `verify-in-app` on macOS with two profiles: the Profiles page shows Memory after Skills with a count and opens the selected profile's memory; Settings… has no Memory row. Check the phone drawer in a workflow test or simulator.
