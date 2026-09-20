## Context

Profiles and Bots are pages pushed from the chat sidebar (`_openProfiles`, `_openBots` in `chat_screen.dart`), each with a small repository over the generated `DefaultApi` that parses untyped JSON leniently. Skills follows the same shape. See `proposal.md` for why and for the split from `add-skills-hub`.

The server side (`hermes_cli/web_routers/skills.py`, Hermes pinned in `real-backend-contract.yml`):

- `GET /api/skills?profile=` returns a list of rows `{name, description, category, enabled, usage, provenance}`. The route has no response schema in the spec, so the generated method returns `Object`.
- `PUT /api/skills/toggle` returns `{ok, name, enabled}`. `GET /api/skills/content` returns `{name, content, path}`.
- `PUT /api/skills/content` and `POST /api/skills` return `{success, ...}` and answer 400 with `detail` on a refusal (a name that already exists, a failed security scan of the new text), 404 when the skill is unknown.
- There is no delete route for any skill.

Platforms: iOS, Android, macOS, Windows, Linux. watchOS is not affected. No entitlement, manifest or Xcode project change.

## Goals / Non-Goals

**Goals:**

- A Skills page that behaves the same on every platform and works on wide screens (constrained content width, not a stretched list).
- Repository and controller that `add-skills-hub` can extend without rework: the page owns the selected profile, and the second tab plugs into the same page.

**Non-Goals:**

- No local cache or offline copy of skills; every open reads the server.
- No change to how the chat picks its profile.

## Decisions

**Follow the existing page pattern.** `lib/src/skills/` holds `hermes_skills_repository.dart` (rows in, rows out, lenient parsing), a `SkillsController` (`ChangeNotifier`, selected profile, list state, filters) and the pages. Alternatives: putting skills logic in `chat_screen.dart` (already large) or a new bottom tab. The sidebar page matches Profiles and Bots, avoids showing a tab bar to everyone, and keeps the chat file from growing.

**Profile is a parameter, not app state.** The controller takes the chat's profile as its start value and passes `profile` on every call. The chip is fed by the existing profiles repository. Alternative: switch the dashboard's active profile like the Profiles page does. That would change what the chat shows as a side effect of looking at skills, which the user chose to avoid.

**Filters run in memory.** The server returns the whole list in one call and has no search or paging on this route, so search and chips filter the loaded rows. One request per profile switch, none per keystroke.

**Optimistic toggle with rollback.** The switch flips first and returns to its old position if the call fails, with a snackbar. A skill toggled twice quickly is serialised per skill name so the last tap wins, in order.

**Provenance decides the actions, and unknown means bundled.** `provenance` maps to `hub`, `bundled` or `agent`; anything else is treated as bundled, the most restrictive case, so a server that adds a value never exposes an edit on something that should not be edited.

**One editor for edit and create.** A single screen with an Edit / Preview toggle (preview through `gpt_markdown`, so the rendering matches the chat), taking initial text, an optional name and category fields for create, and a save callback that returns an error string or null. The text lives in a `TextEditingController` owned by the screen, so a failed save never clears it. Dirty state is `text != initial`; closing asks through `PopScope`.

**Delete goes back to the chat as a draft.** Because there is no route, "Ask agent to delete" pops the Skills routes with a result. The chat appends the drafted text to the composer using the same path shared text takes today (`_absorbShared`), and does not send. The wording is fixed in one place: "Please delete the skill named `<name>`." Alternative: send it straight away. A draft lets the user see and change it, and sending a model request is a cost the user should choose.

**No new dependency.** `gpt_markdown` is already used by the chat. A monospaced text field and a small row of insert buttons (headings, bold, list, code, undo, redo) are built with Flutter widgets; a rich-text editing package was considered and rejected as more than a plain `SKILL.md` needs.

**Invariants touched.** Calls go through `authController.api!.raw`; there is no hand-written Dio. Tokens and the 401 refresh are untouched. Telemetry is wrapped with the existing `safely` helpers and never carries skill names or content.

## Risks / Trade-offs

- [Response shapes are untyped and may change] → lenient parsing, unknown provenance is bundled, and the contract test checks list, content and toggle shapes against the pinned Hermes.
- [A saved `SKILL.md` can fail the server's security scan] → show the server's `detail` and keep the text, as specified.
- [Long skill lists on slow servers] → one request, progress indicator, in-memory filtering; a list of a few hundred rows is fine for `ListView.builder`.
- [Editing on a phone is awkward] → wrap long lines, insert-buttons for the common markdown, and the preview toggle; large rewrites remain better done with the agent in chat, which the delete draft pattern also enables later.
- [An older Hermes without these routes] → 404 becomes a "not supported" message instead of an error with Retry.
