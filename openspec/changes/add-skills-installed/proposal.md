## Why

Hermes skills are how the agent learns reusable procedures, and today the only way to see, switch off or edit one is the web dashboard or the CLI. The app shows a "N skills" count on each profile and nothing more. Users who run the agent from their phone cannot turn a misbehaving skill off or fix a `SKILL.md` without a laptop.

This is the first of two changes that bring the dashboard's skills page to the app. It covers what is already installed. `add-skills-hub` covers finding and installing new skills.

## What Changes

- Add a Skills page, opened from the chat sidebar next to Profiles and Bots, with two tabs. Only the Installed tab is built here; the Discover tab arrives with `add-skills-hub`, and until then the page shows no tab bar.
- Installed tab: skills grouped by category, a search field, filter chips (All, Enabled, Hub, Bundled, Agent), a source badge and usage count per row, and an on/off switch per row.
- Profile picker on the page. It starts on the profile the chat is using and changes only which profile the page reads and writes; it does not switch the chat's profile.
- Skill detail page: the rendered `SKILL.md`, the switch, and actions that depend on where the skill came from. Agent-authored skills get Edit. Bundled and hub skills get the switch only (hub uninstall comes with `add-skills-hub`).
- Editor for `SKILL.md` with an Edit / Preview toggle and a discard prompt, and the same editor for creating a new skill (name, optional category, content).
- "Ask agent to delete" on agent-authored skills. The server has no delete route, so the button returns to the chat with a new message drafted for the agent to send.
- Mockups for the whole feature (both changes) are in `design/mockups.html`.

**Non-goals**

- No hub search, install, update or uninstall (`add-skills-hub`).
- No editing of bundled or hub skills, so a phone edit cannot mark a bundled skill "user-modified" and stop it receiving updates.
- No deleting through the API; the server offers none.
- No editing of a skill's supporting files, only its `SKILL.md`.
- No per-skill settings, credentials or usage history beyond the count the server returns.

**Security and privacy impact**

None new. All calls use the existing bearer token through the generated client. `SKILL.md` text is user content shown and sent back to the same server; it is not logged or added to telemetry.

**Telemetry**

Through flutter_otel, when enabled: a span per Skills request (list, toggle, read content, save, create) named after the operation with attributes `hermes.skills.profile_scoped` (bool) and result (`ok` or `error`), and an `ok` or `error` log event for saves and creates. Skill names and `SKILL.md` content are never attached.

## Capabilities

### New Capabilities

- `skills`: Viewing installed skills per profile, switching them on and off, reading, editing and creating `SKILL.md`, and asking the agent to delete a skill. `add-skills-hub` extends this capability.

### Modified Capabilities

- `profiles-and-bots`: the chat sidebar gains a Skills entry beside Profiles and Bots.

## Impact

- New `lib/src/skills/` (repository, controller, page, detail, editor).
- `lib/src/chat/chat_screen.dart`: sidebar entry, and accepting a drafted message from the Skills page.
- Generated client routes already exist (`/api/skills`, `/toggle`, `/content`); no spec or client regeneration. All three read routes return untyped JSON, so the repository parses rows leniently.
- Contract test additions in `test/real_backend_contract_test.dart` for the list, content and toggle shapes.
- No native, entitlement or dependency changes. Markdown is rendered with `gpt_markdown`, which the chat already uses.
