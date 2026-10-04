## Context

The concept was drawn before the Apple platform work, so it shows Material icons and menus. Only its layout, sizes and behaviour are taken; the Mac app keeps AppIcons' Cupertino glyphs and the adaptive menu.

## Decisions

- **Scope persistence lives in `SchedulesController`.** It reads `hermes.schedules_all_profiles` from `SharedPreferencesAsync` before its first list request; a scope the user picks before that read lands wins. It writes the value when the user picks a scope. `jobSaved` widening the list to every profile does not persist, because the user did not choose it. Preferences are optional so tests and the catalog can leave them out.
- **Plain-model widgets.** `SchedulesMacToolbar`, `MacJobList` and `MacScheduleDetail` take models and callbacks. `ScheduleDetail` keeps its state (runs, paging, reload) and hands it to `MacScheduleDetail` on macOS, so the two layouts cannot drift in behaviour.
- **Split from 560 points on macOS.** The 900 point breakpoint is for iPad and phone layouts; a Mac window with its sidebar open has about 880 points of content at the design's large size, and the design keeps the detail beside the list at compact size too.
- **Rows.** The design asks for 8 point gaps, which the single inset grouped section from #385 cannot have. Each job is its own rounded row, outlined so the profile and delivery chips stay visible.
- **Run status.** A run row has no outcome of its own from the server. The newest run is drawn as failed when the job's last run failed; other ended runs are drawn as done, unended ones as unfinished.
- **⌘N.** The menu bar command registry (#392) is not on main yet, so the toolbar names ⌘N in its tooltip but does not bind it.
