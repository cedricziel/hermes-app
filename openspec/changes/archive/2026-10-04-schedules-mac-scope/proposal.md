## Why

The Mac native concept gives Schedules a Mac window layout: the unified toolbar with the profile scope in it, a job list column beside the selected job, and a denser detail. Today the Mac app shows the phone-style app bar and filter chips, and below 900 points of content (a large window with the sidebar open) it pushes the detail over the list. The scope the user picks is also forgotten on every launch.

## What Changes

- The "All profiles" choice is kept across launches on every platform. Widening the list to show a job just saved in another profile is not kept.
- On macOS, Schedules uses the shared Mac toolbar: title, "N jobs", a "This profile | All profiles" segmented control, Refresh and New Schedule. The filter bar keeps only Failing and Paused.
- On macOS, the list and the detail sit side by side from 560 points of content width, with a 340 point list (250 below 760 points). Jobs are rounded outlined rows 8 points apart; the selected one has a heavier border; a right click opens a job's actions.
- On macOS, the detail is a centred column of at most 560 points: header with Edit and Run now, a failure card when the last run failed or could not be delivered, a key/value grid, and the recent runs as a card of 36 point rows. Pause/Resume, Mute Notifications and Delete move into a "…" menu.
- On macOS, an empty "This profile" list says "No schedules in this profile".
- iOS, iPadOS, Android, Windows and Linux keep their layout.

## Capabilities

### Modified Capabilities

- `scheduled-tasks`: the profile scope is remembered, and a Mac window gets its own layout.

## Impact

- `lib/src/schedules/` (controller, screen, list, detail, new `widgets/` for the Mac toolbar, list and detail), one line in `lib/src/shell/app_shell.dart` to hand the controller its preferences.
- No API change.
