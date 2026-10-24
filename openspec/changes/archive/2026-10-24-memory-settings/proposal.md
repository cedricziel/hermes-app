# Proposal

## Why

Whether Hermes remembers anything, whether it asks before saving, how often it reviews a chat and how it reports memory updates are per-profile config keys that the app cannot change today; the user has to edit `config.yaml` on the server. The memory provider in use, and the way to start over with an empty memory, are equally out of reach.

## What Changes

- The Memory screen gets a **Learning** section:
  - switches "Remember things about me" (`memory.user_profile_enabled`), "Keep agent notes" (`memory.memory_enabled`) and "Ask before saving" (`memory.write_approval`);
  - value rows "Review chats" (`memory.nudge_interval`: Off, Every 5, 10 or 20 messages) and "Memory updates in chat" (`display.memory_notifications`: Off, Short note, With details);
  - the caption "Ask before saving applies right away, the rest from the next chat".
- A switch or value changes at once and goes back, with an error, when the server refuses it. Only the changed key is sent.
- A **Storage** section with a Memory provider row from `GET /api/memory`: "Built-in · MEMORY.md and USER.md", or the active provider's name; an error banner when the configured provider is missing on the server. The row opens Plugins › Providers for this profile.
- **Reset memory…** asks with an alert: Reset agent notes, Reset about you, Reset both, Cancel, and the footnote "Erases the files on the server. Open chats keep what they started with. This can't be undone." It always names the profile.

Non-goals:

- Choosing or configuring a memory provider on this screen; the Plugins screen's Providers tab does that.
- Character limits as settings (`memory.*_char_limit`). They are shown read-only by `memory-overview`.
- Skill settings, including `skills.write_approval`.
- Undo for a reset.
- Clearing pending proposals on reset; Hermes does not, and the app does not pretend to.

## Capabilities

### New Capabilities

- `memory-settings`: the Learning and Storage sections, how a setting is written and reverted, the provider row, and reset.

### Modified Capabilities

- `plugins`: the Plugins screen can open on its Providers tab when opened from Memory.

## Impact

- Code: `lib/src/memory/` (a settings repository on the generated config, memory status and reset calls; controller state for the sections), new widgets in `lib/src/memory/widgets/`, `lib/src/plugins/plugins_screen.dart` (initial tab), `widgetbook/memory_use_cases.dart`.
- Backend: no new route. `GET /api/config?profile=`, `PUT /api/config?profile=` (deep merge), `GET /api/memory?profile=`, `POST /api/memory/reset?profile=`, all in the generated client.
- Security and privacy: reset deletes the profile's memory files on the server. The alert names what goes and that it cannot be undone, and the request always carries an explicit profile so a multi-profile server never resets another one. No token or secret handling changes.
- Observability: spans `memory.settings.fetch`, `memory.settings.write` (`key` slug), `memory.status.fetch` and `memory.reset` (`target`), because each is a request whose failure explains what the user saw; log events `memory.setting_changed` (`key`, `outcome`) and `memory.reset_outcome` (`target`, `outcome`, `deleted` count) to count use and failures; breadcrumbs `memory.setting_toggled` (`key`) and `memory.reset_confirmed` (`target`) for the steps before a crash. No memory text, file names beyond the fixed targets, or profile names.
